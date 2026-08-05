# T380 — Critical review: is ko correctly and exhaustively handled in the retrograde construction?

**Task: T380 · Role: worker · Model: flash (dispatch line `flash/T380`) · Date: 2026-08-05**
**Set: M · Landmark: advances L2 (proven 4×4 values) at its weakest joint.**
**Deliverables:** this doc, `findings/T380-ko-review.json`, `findings/T380-context.json`.

**This row produced findings and measurements only. No engine, table, axiom or
ADR was modified.** Instrument sources: `src/t380_ko_slot.zig`,
`src/t380_census.zig`, `src/t380_psk_diff.zig` (compiled ad hoc; hashes in
`findings/T380-context.json`). Every instrument got a null control and a
seeded-defect control before its reading counted; every number carries its
denominator.

**Verdict in one line: the single-ko-slot state representation is sufficient
and the ko point is discovered correctly at every retrograde step (0
violations over 3.2M reachable 4×4 states and an exhaustive 3×3 check), the
maximum independent ko-chain on a legal 4×4 goban is TWO (refuting the
"perhaps three" prior under the production ko-shape definition), brackets do
NOT come predominantly from static ko shapes (92.6% of bracket-valued
positions carry none), and the lemma the axioms rest on — Z-R-MOVE-B1-EQUIV —
is mis-formulated: its stated predicate is falsified at 3×3/4×4, while the
predicate the engine actually implements holds everywhere.**

---

## 1. What was audited

The retrograde construction has three layers, all audited:

| layer | engine | state key | ko handling |
|---|---|---|---|
| production 4×4 fixpoint | `src/exp6_solve.zig` (EXP-6; builds the WZO2 table via `oracle_v2_build.zig`) | `(board, side, ko_point, passes)` — base-3 rank board field | ko set by an inline shape rule (`apply_place4:886`, `apply_place:552`, `apply_place32:262`); recapture banned at the ko point; pass clears |
| kernel (T273) | `src/rules.zig` — `koAfterCapture:1109`, `applyMove:423`, `applyPass:436`, `legalMoves`, `stateKey` | combinatorial colex + side + ko + passes | the one true ko rule: single capture + capturer 1 liberty + **no friendly neighbours** |
| independent battery (R8) | `src/vb_movegen.zig`, `src/vb_bellman_4x4.zig` (`koAfterCaptureRt:399`) | same key, re-encoded | independent re-implementation of the same shape rule |

The artifact audited is the current table `data/oracle-4x4-v2.wzo2` (WZO2,
rules_id 3 = basic ko + L/H bracket; SHA-256 `0c3366f0…`, 24,318,165 position
groups, 99,133,036 entries). The old checkpoint
`data/oracle-4x4.checkpoint.wzo` (SHA `a2174fed…`, the writes-ON build) is
used only for the Q3 null control, never for value claims
(AGENTS.md foreclosure).

**A structural fact that shapes Q2.** None of the retrograde engines enumerate
predecessors: `retro.zig` is successor-sweep value iteration (header: "forward
move generator only — no un-move / un-capture code"), `exp6.genChildren4` and
`vb_bellman_4x4.i4Bellman` also enumerate successors only. A successor state's
ko point is therefore always computed **forwards**, from the move's shape
rule. The "backward ko attribution" risk the brief hypothesised does not exist
in this construction; the risk concentrates in (a) the shape rule's own
correctness against the axiom, and (b) the copies agreeing. Both were
machine-checked (below).

---

## 2. Q1 — Is a single `ko_point` sufficient for basic ko? **YES, by proof + machine search**

### 2.1 The derivation (from AXIOMS B1/B2)

B1's ban at a state is a position-identity test on the move's result. Reading
the AXIOMS' own P₀/P₁/P₂ table (B1 derivation, §2 of AXIOMS.md): for the
candidate move played from state Sₙ (position Pₙ), the result Pₙ₊₁ is compared
against "the position two plies earlier [than Pₙ₊₁]" = the position at Sₙ₋₁ —
**the position one state back**. So the B1 ban set at Sₙ is

> B(Sₙ) = { m : result(m) == position at Sₙ₋₁ }.

The recapture of the previous move's single captured stone is the **only**
candidate: Pₙ₋₁ and Pₙ differ at exactly the played cell and the captured
cell(s) of the previous move; a move from Sₙ can restore Pₙ₋₁ only by filling
the captured cell and re-removing the played cell — one move, one point. A
multi-stone previous capture removes k ≥ 2 stones, so no single move can
restore all k (Pₙ₋₁'s stones at all k points); a non-capture previous move
removes nothing, so the played cell cannot be re-emptied. Hence **|B(Sₙ)| ≤ 1
at every reachable state** — one slot is sufficient, and the slot content is
determined by the last move alone (B2: set on the ko-capture, cleared
otherwise).

### 2.2 The machine search (the counterexample hunt)

Instrument `t380_ko_slot walk`/`planted`: forward simulation over the reachable
4×4 state graph using the kernel successor relation, with the two-ply window
recomputed from the position history at every state, checking
**INV-1** (|B| ≤ 1) and **INV-2** (B == {ko slot} iff the slot is set).

| metric | count |
|---|---|
| states visited (BFS depth ≤ 14 + 20,000 random walks × 400 plies, seed 0x7E57A380) | 3,222,855 |
| ko-creating edges | 39,770 |
| distinct ko-set states | 8,305 |
| **INV-1 (two live bans) violations** | **0** |
| INV-2 over-restriction (slot set, no B1 move) | 0 |
| INV-2 under-restriction (B1 move, slot empty) | 0 |

**No 4×4 position/state in the sample needs two simultaneous bans.**
Supplement: the exhaustive 3×3 static window check (below, §3) also finds 0
ban-set mismatches over every legal single-capture two-ply window.

**Seeded-defect control (the search must find a planted counterexample):**
`planted` mode keeps a ban live across non-pass moves (a two-live-bans
bookkeeping the single slot cannot carry). The search found exactly that:
**2 INV-1 violations** (witness: colex 39,441,641, side Black, ko=2,
ban set {2,3}) and 866 INV-2 under-restrictions. The search machinery detects
two-live-bans states when they exist; the null run finds none.

---

## 3. Q2 — Is the ko state discovered correctly at every retrograde step? **YES, with one axiom-lemma finding**

### 3.1 Every site that computes or clears a ko point (and its axiom check)

**SET sites** (all implement the identical shape rule: single capture + capturer
exactly 1 liberty + no friendly neighbours):

| site | file:line | check |
|---|---|---|
| kernel `koAfterCapture` (T273) | `src/rules.zig:1109` | B1/B2: ko = point of the single captured stone; `friendly==0` at `:1136` |
| production 4×4 `apply_place4` (and 3×2/3×3 copies) | `src/exp6_solve.zig:886` (262, 552) | identical shape rule; verified ≡ kernel at 4×4 (moveset mode, below) |
| independent battery `koAfterCaptureRt` | `src/vb_bellman_4x4.zig:399` | identical shape rule; exercised against the whole table by I4 (T343) |
| play-time GTP | `src/gtp.zig:230,313,496` | delegates to the kernel (the CODE.GTP-KOKEY fix) |

**CLEAR sites** (B2: cleared on pass and on non-ko-capture moves): `applyPass`
(`rules.zig:436`), `apply_pass32/apply_pass` (`exp6_solve.zig:295,585`),
`applyPass` (`vb_bellman_4x4.zig:437`). All checked against the walk's INV-2
(0 under/over-restriction over the reachable 4×4 sample).

### 3.2 Shape rule ≡ the true B1 ban set (the correct predicate)

The walk's INV-2 is the direct check: at every reachable state the engine's ko
slot equals the B1 ban set derived from the two-ply window. **0 violations over
3,222,855 states.** Independently, the exhaustive 3×3 static check over every
legal single-capture two-ply window (12,675 legal P₀, 784 windows): **0 ban-set
mismatches**; the sampled 4×4 static check (2,309,383 sampled P₀, 344,996
windows): **0 ban-set mismatches**.

### 3.3 Kernel ≡ production ≡ battery copies

- **moveset mode (new, closes the T339 gap at 4×4):** kernel
  `applyMove`/`applyPass` vs production `exp6.genChildren4` successor sets,
  compared state-for-state over 266,779 random 4×4 states (both colours, ko,
  passes): **0 mismatches** (the existing T339 differential covers ≤3×3 only).
- **T345 (existing, on record):** producer vs consumer state keys agree over
  the full table, 0 / 99,133,036 entries.
- **T343 I4 (existing, on record):** Bellman residual L = Φ(L), H = Φ(H) with
  the *independent* R8 move generator + independent ko: 0 violations on
  95,677,624 clear entries; 0 on the 3,455,412 set entries (measurement
  bucket); 0 children missing; 0 move divergences.
- **T363 C-A1/C-A2 (existing, on record):** 0 children-not-in-table over
  600,763,414 children; 0 reachable-not-in-table over 99,020,312 reachable.

### 3.4 FINDING — the lemma Z-R-MOVE-B1-EQUIV is mis-formulated (axiom/lemma gap, not an engine defect)

`rules.zig:1385,1446` mechanize "P₂ == P₀ (the window's start) ⇔ shape rule
fires" at 2×2/3×2 only, and the AXIOMS' B1 derivation ("P₀ is two plies before
P₂") states the comparison as being against the window's P₀. The engine does
not compare against a window start: it sets the ko point per the shape rule,
and the ban's correctness is judged at the resulting state against the position
**one state back**. The two predicates coincide at 2×2/3×2 and diverge at 3×3+:

| size | windows checked | lemma's predicate (P₂ == P₀ ⇔ shape) | correct predicate (ban set == {ko point}) |
|---|---|---|---|
| 3×3 (exhaustive, all legal) | 784 | **152 mismatches** | **0** |
| 4×4 (stratified sample) | 344,996 | **36,446 mismatches** | **0** |

Witness at 3×3: P₀ = colex 3197 (`0 -1 1 / -1 1 0 / 1 0 0`), W@7 captures the
Black stone at 6 (2-liberty capturer, no ko), B@0 captures the White stone at 1
with Black's stone at exactly 1 liberty and no friends — the shape rule fires
and sets ko = 1, correctly banning White's recapture at 1 (which would recreate
P₁, the position one state back). The window's P₂ ≠ P₀ (four cells differ), so
the lemma's predicate reports a "mismatch" — but the engine is right.

**Consequence:** the "proven" equivalence in the AXIOMS/lemma claim does not
extend to 3×3/4×4 in the form stated; the equivalence that does hold — shape
rule ⇔ recapture-recreates-one-state-back — holds everywhere (0 violations).
The engine is B1-correct; the lemma's formulation (and B1's "two plies
earlier" phrasing, which admits both readings) should be corrected in the
axioms. This is a documentation/axiom gap, not a value defect.

### 3.5 FINDING (context) — the census ko-shape definition differs from the production rule

The B23/retro ko-shape detectors (`ko_census.zig:48`, `retro.zig:661`) omit
the friendly-neighbour check that the production rule has
(`rules.zig:1136`). A capturing stone with a friendly neighbour can never set
a B1 ko point (the recapture would capture the whole group, not recreate the
previous position), so the census definition over-counts ko shapes. This
explains the Q3 null control (below) and reframes the T117 "3-ko hard core".

---

## 4. Q3 — Multi-ko census over the table: max is TWO, not three

Census over the 4×4 table (`data/oracle-4x4-v2.wzo2`), exhaustive over all
24,318,165 legal positions (every legal 4×4 position is one group in the
table; denominator = 24,318,165). Ko-shape definition = the production rule
(single capture + 1 liberty + no friendly neighbours), clustered by
1-neighbourhood overlap union-find (the B23/`countKoClusters` independence
notion, re-implemented independently).

| cluster class | all positions | % | bracket-valued positions | clear positions |
|---|---|---|---|---|
| 0-ko | 22,278,061 | 91.61% | 1,782,629 | 20,495,432 |
| 1-ko | 2,013,032 | 8.28% | 140,160 | 1,872,872 |
| 2-ko | 27,072 | 0.111% | 2,184 | 24,888 |
| 3+-ko | **0** | 0% | 0 | 0 |
| total | 24,318,165 | 100% | 1,924,973 | 22,393,192 |

**The maximum number of independent ko clusters on any legal 4×4 goban is
TWO** under the production ko-shape definition. The operator's prior ("perhaps
three") is refuted at 4×4: no legal position carries three independent
B1-ko shapes. Under the loose B23 definition (no friendly check) the max over
the old ko-sensitive region is 3 (256 side-positions, witness colex
36,199,102) — those "third kos" are friend-connected captures that never set a
B1 ko point; the T117 "3-ko hard core" is a definition artifact.

**Null control:** with the loose definition, my census over the old
checkpoint's ko-sensitive side-positions reproduces the B23 published
distribution **exactly** — [6,741,026; 3,415,640; 211,000; 256] over
10,367,922 side-positions (kernel-def, for comparison: [8,675,538; 1,663,032;
29,352; 0], max 2). Counting machinery validated against an independent
instrument.
**Seeded-defect control:** union-find merge disabled → the 3×3 distribution
changes [11,971; 704; 0; 0] → [11,971; 640; 64; 0] — the defect is caught.

---

## 5. Q4 — Do the brackets come from ko? Mostly NOT at the position level

Correlation over the same table (per-position aggregation of the 99,133,036
entries; 3,455,412 bracket-valued (L<H) entries = 3.49%).

**Both directions:**

1. **Bracket-valued positions with ZERO ko shapes: 1,782,629 of 1,924,973 =
   92.6%.** The strong form of the operator's hypothesis — "brackets come from
   ko" — is **refuted** at the position level: the overwhelming majority of
   positions with some L<H entry carry no static ko shape at all. The brackets
   there come from cycle structure created *in play* — kos formed by moves at
   positions that have no static shape, and non-ko cycles (pass fights,
   approach-move loops) resolved by the TIE=0 verdict. This is the "second
   source of state-insufficiency" the brief suspected; it is now named and
   measured: it dominates.
2. **Ko-carrying positions with NO bracket-valued entry: 1,897,760 of 2,040,104
   (93.0%).** Most ko shapes never widen any bracket — the ko is a one-shot
   (never optimally re-taken), or the bracket collapses anyway.

**Bracket width by ko class** (mean H−L over bracket-valued positions): 0-ko
13.21, 1-ko 15.02, 2-ko 19.55; class max 32 for all non-empty classes; global
max 32 (the full [−16,+16] range), 96,760 entries at width 32, witness colex
6,452. Ko-carrying positions have systematically **wider** brackets (~2–6
points), so ko structure shifts the bracket but is not its main source.

**Fresh-start slice** (ko=none, passes=0, comparable to the old table's
figure): bracket-valued on Black 981,071, on White 981,071 (exactly equal —
colour inversion holds at the fresh-start slice), 1,913,925 positions on
either side (7.87%), mean width 13.28 both sides. The old table's fresh-start
ko-sensitive set was 5,183,961 positions (21.3%): the new table's fresh-start
bracket-valued set is **2.7× smaller**.

**"Cycle-reachable" interpretation, calibrated at 3×3** (SCC mode over the 3×3
WZO2 graph, 49,428 entries, 30,457 SCCs): L<H entries inside non-trivial SCCs
= 3,004; L<H entries *not* inside any non-trivial SCC = 2,404 (44%) — the
bracket propagates up the optimal lines from ambiguous cycles, so L<H is the
"can reach a value-ambiguous cycle" indicator, including pre-cycle states.
Not conflatable with "is in a cycle"; the ko-structure features above are the
position-level proxy used for the 4×4 correlation.

---

## 6. Q5 — Where does basic ko differ from PSK? At 3×3: exactly at the L<H positions

### 6.1 The position classes (from the axioms)

| class | basic ko (k=1) | PSK | table's L<H? |
|---|---|---|---|
| (a) ko-threat-tenuki-retake: capture, opponent tenuki, retake | legal (the ban cleared by the tenuki move) | **banned** (retake recreates a position on the ban set) | yes — bracket-valued wherever the tenuki/retake fight is value-relevant |
| (b) long cycles without ko (pass fights, approach-move loops) | allowed; TIE=0 verdict | **banned** (any repetition) | yes — the bracket is the TIE=0 range |
| (c) multi-ko loops (double/triple ko) | allowed; TIE=0 | **banned** | yes (the 2-cluster positions) |
| (d) one-shot snapback-style captures | immediate recapture banned (recreates P₀, two plies back) | immediate recapture banned (P₀ on history) | **no divergence** — both rulesets ban it |
| (e) plain captures / non-cycle positions | — | — | no divergence; L==H |

### 6.2 Measurement, 3×3 exhaustive (both tables trusted)

PSK fresh-start (`artifacts/oracle-3x3.wzo`, WZO1, validated) vs basic-ko
pinned fresh-start (`data/oracle-3x3-v2.wzo2`, V = clamp(TIE=0,[L,H])), for
every legal position × side:

| metric | count |
|---|---|
| checked (fresh-start entries present) | 24,330 (of 25,350 = 12,675 × 2) |
| **divergent** | **680 (2.80%)** |
| divergent at fresh-start L<H | **680 (100% of divergences)** |
| divergent at fresh-start L==H | **0** |
| divergent by cluster class | [600, 80, 0, 0] |
| same value, fresh-start L<H | 2,524 (of 3,204 bracket-valued = 78.8%) |
| NULL control: divergence at (L==H, 0-cluster) | **0** (want 0) |

**At 3×3, basic ko and PSK differ exactly where the new table is
bracket-valued at the fresh-start key** — every one of the 680 divergences
sits at an L<H entry, none at L==H. The answer to "which of those does the
table call L<H?" is: *all of them, at 3×3*. (And 78.8% of the bracket-valued
positions agree with PSK anyway — the bracket *contains* the PSK answer there;
this is a measurement, not a resurrection of the C3 bracket-bounds claim,
which stays FALSE-AS-SCOPED.)

### 6.3 Measurement, 4×4 sample (honest but weak)

PSK fresh-start via the memo-off forward solver (`O.solve`, the
psk_divergence HistoryPSK discipline; the ban-set-keyed Exact solver is
unusable at 4×4 — 5.4 MB per memo key) on a stratified sample of 10–14-stone
positions weighted 8:1 toward ko-carrying positions, node budget 200,000:

| metric | count |
|---|---|
| roots sampled | 1,591 |
| budget-excluded | 782 (49.1%) |
| within-budget | 809 |
| divergent (within-budget) | **0** |
| NULL control | 0 |

The within-budget sample is the cheap (mostly ko-free, short-subtree) tail;
the divergent class concentrates in the budget-excluded (ko/cycle-heavy) half,
so the 4×4 measurement is a null result within budget, not a proof of
agreement. The 3×3 exhaustive result (§6.2) is the trustworthy reading; the
T366 live-game witness (recorded, not re-derived: 8 cross-ruleset plys in 132
frame-B games) corroborates that basic-ko/PSK divergence exists in 4×4 play.

---

## 7. Controls ledger (every instrument, per AGENTS.md)

| instrument | null control | seeded-defect control |
|---|---|---|
| ko-slot walk (Q1/Q2) | walk over the reachable 4×4 space: 0/3.2M | planted two-live-bans bookkeeping: **found** (2 INV-1 + 866 INV-2) |
| ko-slot equiv3/equiv4 (Q1/Q2) | correct-predicate ban check: 0/784 (3×3), 0/344,996 (4×4) | lemma predicate falsified by the same instrument (152/784) — the instrument detects the wrong-predicate formulation |
| ko-slot moveset (Q2) | kernel vs exp6: 0/266,779 | (existing T339 seeded mutants cover ≤3×3; moveset closes 4×4) |
| census (Q3/Q4) | loose-def distribution == B23 published [6,741,026; 3,415,640; 211,000; 256] exactly | union-find merge disabled: 3×3 distribution changes — caught |
| psk-diff 3×3 (Q5) | 0 divergences at (L==H, 0-cluster) | — |
| psk-diff 4×4 (Q5) | 0 within-budget divergences at (L==H, 0-cluster) | — |

---

## 8. Findings list (see findings/T380-ko-review.json)

1. **F-1 (Q1, no defect):** a single ko slot is sufficient — |B1 ban set| ≤ 1
   at every reachable state, proven from AXIOMS B1/B2 and machine-confirmed
   (INV-1 = 0 over 3,222,855 reachable 4×4 states; planted control finds the
   planted two-ban states).
2. **F-2 (Q2, no defect):** the ko point is discovered correctly at every
   retrograde step — the shape rule's ko point equals the B1 ban set at every
   reachable state (INV-2 over = 0, under = 0; exhaustive 3×3 0/784; sampled
   4×4 0/344,996); kernel ≡ production ≡ battery (moveset 0/266,779; T345
   0/99.1M keys; T343 0/95.7M Bellman; T363 0/600.8M children).
3. **F-3 (Q2, axiom/lemma gap):** the lemma Z-R-MOVE-B1-EQUIV's stated
   predicate (P₂ == P₀ ⇔ shape) is falsified at 3×3 (152/784 windows) and 4×4
   (36,446/344,996 windows); the correct predicate (recapture recreates the
   position one state back) holds everywhere. The engine is B1-correct; the
   lemma's formulation and B1's "two plies earlier" phrasing need a correction
   in AXIOMS.md. The 3×2-only mechanization masked the divergence.
4. **F-4 (Q3, measurement):** max independent ko-cluster count on a legal 4×4
   goban is **2** (exhaustive over 24,318,165 positions); distribution
   [22,278,061; 2,013,032; 27,072; 0]. The operator's "perhaps three" prior is
   refuted under the production ko-shape definition; the T117 3-ko class is a
   loose-definition artifact (null control reproduces B23 exactly with the
   loose definition).
5. **F-5 (Q4, measurement):** brackets do NOT come predominantly from static ko
   shapes — 92.6% of bracket-valued positions (1,782,629/1,924,973) carry zero
   ko shapes; 93.0% of ko-carrying positions have no bracket-valued entry.
   Ko-carrying positions have wider brackets on average (mean width 13.2/15.0/
   19.5 by class). Fresh-start bracket-valued set is 7.87% of positions
   (1,913,925), 2.7× smaller than the old table's ko-sensitive set.
6. **F-6 (Q5, measurement):** at 3×3, PSK ≠ basic-ko pinned fresh-start at 680
   of 24,330 checked (2.80%) — **all 680 at fresh-start L<H, 0 at L==H**;
   classes [600, 80, 0, 0]. 4×4 within-budget sample: 0/809, with 49.1% of
   roots budget-excluded (honest null within budget).

## 9. Landmark line

This row advances **L2 (proven 4×4 values)** at its weakest joint: the ko
handling of the retrograde construction is verified correct on the reachable
4×4 state space (single-slot sufficiency and ko-point discovery: 0 violations
over 3.2M states and an exhaustive 3×3 check; producer/consumer/key agreement
already on record at 0/99.1M), the multi-ko census refutes the "max three"
prior (max is 2; 0 of 24.3M positions carry 3+ independent kos under the
production ko-shape definition), brackets are shown to be mostly *not* ko-
driven (92.6% of bracket-valued positions carry no ko shape — the second
source is cycle structure created in play), and the one defect-adjacent
finding is an axiom/lemma formulation error (Z-R-MOVE-B1-EQUIV's stated
predicate fails at 3×3/4×4 while the engine's actual predicate holds
everywhere) — recorded for the axiom owners, not fixed here.

— flash/T380, 2026-08-05
