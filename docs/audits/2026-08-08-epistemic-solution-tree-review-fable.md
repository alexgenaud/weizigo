# Review: the claims register, the epistemic trees, and the solution tree — gaps, and the path to provably perfect Go

**Author:** claude-fable-5, at the operator's request, 2026-08-08. **Read after** the week-close
audit (`docs/audits/2026-08-08-week-close-audit.md`).
**Sources reviewed:** `docs/epistemic/CLAIMS.md` (226 rows, C9 lockstep, claimlint calibration
PASS at review time), `docs/epistemic/boards/{2x2,3x2,3x3,4x3,4x4}/EPISTEMIC.md` +
`CONCEPTS.md`, `docs/epistemic/SOLUTION-TREE.md` (T415), `docs/epistemic/knowledge-ladder.md`,
`docs/epistemic/PROGRESS.md`, `docs/audits/2026-08-02-grand-audit/DIRECTION.md`,
`docs/decisions/ADR-0020` + `ADR-0022`, `docs/epistemic/is-real-game-markovian.md`.
Scale estimates in §5 are **computed in this review** (arithmetic from committed figures +
OEIS A094777) and labelled as such — they are not measurements.

---

## Outline

1. What the three artifacts are, and whether they cohere
2. The gaps — substantive (construction), epistemic (register), and meta (the trees themselves)
3. Is there a path to provably perfect Go at 3×3? (yes — shortest circuit, list given)
4. Is there a path at 4×4? (yes, finite, but two gates are harder than they look — one of them
   blocks even "Black wins")
5. Is there hope for 5×5? (yes — but not by scaling this method; the honest shape is different)
6. Suggestions, ordered

---

## 1. The three artifacts, and whether they cohere

The project keeps three distinct trees, and the distinction is sound:

- **`CLAIMS.md`** — *what is true about the game*, 226 rows with statuses
  (PROVEN / CLAIMED / MEASUREMENT / UNTESTED / FALSE-AS-SCOPED) and dependency edges, so a
  falsification's consequences are computable rather than remembered.
- **`boards/*/EPISTEMIC.md`** — the same knowledge cut per goban size, with per-goban
  independence enforced (inherited-not-reproven facts carry an explicit `⬜ᴵᴺᴴ` flag).
- **`SOLUTION-TREE.md`** (new, T415) — *what the construction of each table rests on*: 45
  sub-steps across 5 sizes, each graded PROVED / CLAIMED / KNOWN-WRONG against committed
  evidence only, with the brief's rule applied strictly ("passed every test" is CLAIMED, not
  PROVED).

**They cohere.** Register↔mapping lockstep is mechanized (claimlint C9 = 0 at review time);
the solution tree cites register rows rather than re-adjudicating them; the per-board trees
carry the falsifications (C2 at 3×2, C3 at 3×3) that the solution tree's weakest-link sections
correctly inherit. I found no contradiction between the three during this review. The one
place the *story* diverges from the *ledger* is `PROGRESS.md` (§2, meta-gap M1).

The solution tree's headline is the right one and deserves restating: **18 of 45 construction
steps are PROVED (40%), and the PROVED fraction falls monotonically with size — 5/9 at 2×2
down to 1/9 at 4×4. The table the project ships is the one whose construction is least
proved.** The proved rungs are the size-generic ones (colex enumeration, the rules kernel,
Benson's theorem, area scoring); the claimed rungs are exactly the per-size instantiations.
That is not an accident — it is what per-goban independence costs — but it means the path to
"provably perfect" is mostly a list of per-size re-verifications, which is good news: the list
is finite and already written (SOLUTION-TREE §8).

---

## 2. The gaps

### 2a. Substantive gaps — the construction itself

Ranked by how much of the deliverable each one taints.

**G1 — The 4×4 KO_SENSITIVE column is distrusted, and the root's bracket lives in it.**
3,455,412 entries (3.49% of the table) are checked *around*, never *on* — and per the solution
tree this includes the root bracket [+1, +16]. `4x4.D3` (Track A: the writes-off regeneration
plus the #2 auditor) is UNTESTED and is the single gate. Until it runs, even the headline
"Black wins 4×4" rests on a distrusted column, because the win is inferred from L=+1 > 0.
The 3×2 precedent is why the distrust is not paranoia: there the same writes-ON mechanism
produced **45/378 measured minimax violations in the committed artifact** (`3x2.F1` PROVEN).

**G2 — The bracket region has no exact value under the project's own rules.** ADR-0020 fixes
the game (basic ko, TIE=0 on repetition); under that game every position has a *unique*
game-theoretic value, but the table stores only the [L, H] fixpoint bracket, and at 4×4 the
root itself is bracketed (L=+1, H=+16). "Provably perfect 4×4 play" in the strong sense —
exact value and optimal move everywhere — is therefore **not yet even fully specified as
achieved at the root**, independent of G1. ADR-0022 correctly demoted every resolver tried so
far (capture budget, truncation, median-pin, finisher, PSK graft) as "a different game, not an
approximation of ours." See §4 for a candidate exit that is a proof obligation rather than a
plugin.

**G3 — Two rungs of the 4×4 spine are inherited, not verified.** `4x4.S2-impl` (the Benson
implementation at 4×4) and `4x4.S4` (area scoring at 4×4) are UNTESTED — terminal detection
and scoring rest on "same code as 3×3". Both are cheap to close (rerun the 3×3 falsification
sweep and the independent Python scorer at 4×4). Until then, a size-dependent regression in
exactly the two functions that turn positions into scores would be invisible to every
committed check.

**G4 — The move generator's only exhaustive 4×4 evidence is indirect.** I11 (move-set
consistency) sampled 50,000 of 99,133,036 states — 0.05%, the one non-exhaustive G3b
condition. The compensating evidence is strong (key agreement 0/99,133,036; closure
0/600,763,414 children) but those checks would not catch every generator defect class, and the
T178/T193/T265 producer/consumer family — the project's most expensive bug class, three
separate incidents — **still has no battery invariant** (`GLOBAL.BATTERY-GAPS` G1/G3).

**G5 — Known-falsified test predicates are still mechanized and passing.** `rules.zig:1385,1446`
test the *old* recapture-identity predicate, falsified at 152/784 (3×3) and 36,446/344,996
(4×4) by T380 F-3; the corrected lemma (`GLOBAL.Z-R-MOVE-B1-EQUIV`) is CLAIMED, never
re-derived. A green test asserting a known-wrong predicate is worse than no test — it is
exactly the "silent wrong answer" failure mode the week's tooling lessons named.

**G6 — Lost primary evidence, and more possibly pending.** `2x2.B1`/`3x2.B1`/`3x3.B1` (the
least-fixpoint instances) were downgraded PROVEN→CLAIMED when `untracked/T02-minimax.md` was
deleted; the T07 audit basis behind the 4×4 tree rewrite is gone; T13's probe source — the
falsification the strategy rests on — is gone. And T421 (in flight) will report which claims
the **43 already-dead `/tmp` citations** supported; until it closes, the PROVEN floor itself
has unquantified exposure.

**G7 — Mutation adequacy gates every promotion and is unreconciled.** DIRECTION Amendment 2
edge 5: exhaustive *measurement* is not mutation *adequacy* — the A2/A5/A8 exhaustive sweeps
(0/99,133,036 each) are held at CLAIMED for exactly this reason. But the kill matrix itself is
in a disputed state (`mutants.md` vs `vb_mutants.zig` vs T363's "7/7" disagree — T388 D8), so
the gate that everything must pass through is not currently in a runnable condition.

**G8 — Smaller but real:** `4x4.FP1-C1/C2` (seed provenance −N/+N and final zero-change
sweeps) UNTESTED though readable post-hoc from T104's output; the 4×3 root [+4,+12]
single-instrument and never audited; the 4×3 legal count self-derived (no OEIS entry for
non-square gobans); no persisted current-rule artifact below 3×3; dead battery stubs
(checkI8/checkI11) that report nothing.

### 2b. Epistemic gaps — what the register says we cannot say

- **Fresh-start ≠ real-game, and this is falsified, not just unproven.** C2 is FALSE-AS-SCOPED
  at 3×2 (154/508 reachable single-score slots differ from the history-exact value); C3 at 3×3
  (the bracket does not bound the real-game score — a 12-point leak). Any "perfect Go" claim
  that omits "fresh-start, under the stated rule" is a category error the register already
  guards against. This is a *scope boundary*, not a gap to close — PSK solving is abandoned
  (intractable, and not what the artifacts compute).
- **`3x3.C1` has no exhaustive ground truth.** 2×2 has an exhaustive history-aware exact-solver
  cross-check (`2x2.C1` PROVEN); 3×3 does not (the finisher-era spot-check completed 105/400
  roots). The +9 root matches the MIGOS II anchor and the differentials are exhaustive, but
  "fresh-start correct at 3×3, slot for slot, against an independent solve" is unwritten. This
  is the single most closable gap in the whole review (§3).
- **The strongest regularity is unexplained.** Life ⟹ L==H over 99,133,036 entries, zero
  exceptions, no proof. Not load-bearing for the tables, but it is the best theorem candidate
  and would be the first *structural* (size-transferring) result the project owns — relevant
  to 5×5 (§5).

### 2c. Meta-gaps — the review artifacts themselves

- **M1: `PROGRESS.md` is stale on the headline.** Last refreshed 2026-07-31, it still calls
  the basic-ko build "the intended near-term deliverable" — but `data/oracle-4x4-v2.wzo2`
  exists, is battery-discharged (G3b), and is playable in Sabaki. The narrative hub, the one
  file a newcomer is told to read, describes the project as it was eight days ago. The T414–
  T420 wave (loop question answered, ply cap measured, max-strength falsification survived) is
  absent entirely.
- **M2: the knowledge ladder is still PROPOSED, unadjudicated, since 2026-07-29.** Its two
  columns (rung × rule) are precisely the guard against the project's characteristic failure —
  a high-confidence value quoted for the wrong game (`4x4.ANCHOR` was the miniature). Today
  that error class is invisible to claimlint because rule-fidelity lives in prose. Ten days of
  new claims have accumulated without the column.
- **M3: the solution tree has no owner or refresh trigger.** It is dated 2026-08-08 and
  correct today; nothing forces it to track future promotions (e.g. when Track A lands,
  eighteen cells change). A one-line claimlint check — "solution-tree basis cites a register
  row whose status still matches" — would keep it honest the way C6 keeps PROGRESS.md honest.
- **M4: the 4×4 EPISTEMIC.md rewrite cites a lost basis** (T07, recorded debt since
  2026-07-29). The rewrite is probably fine; the point is that the debt is recorded in the file
  itself and has now outlived three audit cycles without a disposition.

---

## 3. The path to provably perfect Go at 3×3 — yes, and it is the shortest circuit

State the claim at the right rung first (knowledge-ladder terms): the target is
**K0 — certified**: exact values under an explicitly stated rule (ADR-0020: area scoring,
komi 0, basic ko, TIE=0), evidence committed, **independently reproduced by a different
implementation**. Not "perfect Go" unqualified — C3's falsification at 3×3 means the
real-game reading must stay a non-claim forever at this size.

3×3 is the right pilot because it is the only size that is simultaneously (a) single-valued at
the root (+9, matching the MIGOS II external anchor under aligned rules — the project's only
cited-and-reproduced external anchor family), (b) small enough for exhaustive everything
(49,428 entries), and (c) already 4-PROVED / 4-CLAIMED on the spine. The circuit:

1. **An independent exhaustive re-solve of 3×3** — a second implementation (per DIRECTION,
   the epic-01 kernel-as-oracle is the chartered vehicle; the standing doctrine "duplication
   is the oracle" and the ladder's own observation — *independent re-implementation is the
   only thing that has ever moved a claim up* — both point here), compared slot-for-slot
   against `data/oracle-3x3-v2.wzo2`. This closes `3x3.C1` the way `2x2.C1` was closed, and
   converts step 5 (L/H fixpoint) from CLAIMED to PROVED at this size. Cost: small — the
   fixpoint at 3×3 is 16 sweeps over 49,428 entries.
2. **Re-derive the FP1 instance** (seed provenance from −N/+N, final zero-change sweep,
   recorded — replacing the lost T02 evidence). Mostly archaeology plus one instrumented
   rebuild.
3. **Mutation adequacy for the 3×3 acceptance sweeps** (reconcile the kill matrix first — G7).
4. **Fix G5** (re-mechanize the corrected recapture-identity tests) — 3×3 is where the old
   predicate has 152/784 counterexamples to assert against.

That is the whole list. Nothing at 3×3 waits on Track A (the WZO2 3×3 construction has no
finisher — T380 F-8). **Verdict: provably perfect fresh-start 3×3 under ADR-0020 is
achievable with existing methods and instruments; it is discipline work, not research work,
and it would be the project's first full K0.** Its value is only partly the result — it is
also the dress rehearsal for the same circuit at 4×4 scale.

---

## 4. The path at 4×4 — yes, finite, but two gates are genuinely hard

Everything in §3's circuit recurs at 4×4 scale (independent re-solve, FP1 provenance, mutation
adequacy, S2-impl/S4 re-verification, exhaustive I11 at 600M children — expensive but
demonstrated feasible by the C-A1 closure run at exactly that scale). Two things do not recur;
they are new and harder:

**Gate 1 — Track A (`4x4.D3`).** Until the writes-off regeneration runs and the #2 auditor
passes, the KO_SENSITIVE column — 3.49% of the table *including the root* — is distrusted,
and every headline (root bracket, "Black wins", T381/T420's claimed-won corpus) carries the
taint. This is scheduled work, not research: the writes-off checkpoints already exist in
`untracked/` (uncommitted, unhashed, unaudited). It should run before any promotion push.

**Gate 2 — the bracket must become a value (G2).** Under ADR-0020 the game is fully defined,
so every state *has* an exact value V with L ≤ V ≤ H; the table just doesn't store it where
L<H. The resolver attempts so far failed because they changed the game (ADR-0022's lesson).
But there is a candidate that is a **proof obligation rather than a plugin**, and I did not
find it in the register or the ADRs: the tie-game value is exactly computable by **threshold
decomposition** — for each integer threshold t in [−16, +16], "can Black force outcome ≥ t?"
is a reachability/safety condition (reach a terminal scoring ≥ t, or, when t ≤ 0, alternatively
hold the game in a loop forever), and such games are positionally determined and solvable by
standard attractor fixpoints — this is classical backward induction extended to loopy games
(the same family as Zermelo/Büchi-style threshold games), not an invention. V(s) is then the
largest t Black can force. Thirty-three threshold sweeps over the 99,133,036-entry graph is
well within demonstrated scale (the closure checks already traverse 600M children). If this is
right, the L<H region stops being a bracket and becomes exact values with a per-threshold
certificate; if it disagrees with [L,H] containment anywhere, that itself would be a
register-grade finding about the fixpoint semantics. **Suggestion §6.3 registers this as a
hypothesis with a proof obligation and a small-goban pilot (2×2/3×2 have exhaustive ground
truths to check against), test-first per the standing tooling rule.**

With both gates passed plus the §3 circuit at scale, the honest 4×4 claim reaches:
*exact fresh-start values for all 99,133,036 entries under ADR-0020, independently
re-implemented, externally anchored at the root (+1 = MIGOS basic-ko), with committed
evidence* — K0, and "provably perfect play" follows for the whole table since a table-optimal
policy is then provably value-preserving everywhere. T420's result (no third-party engine at
maximum strength beats the table from claimed-won positions, 0/68 per engine) is the right
kind of falsification instrument to keep running alongside, but it is corroboration, never the
proof.

**What 4×4 can never claim:** the real game. C2/C3 falsifications stand; the PSK gap is
measured-and-abandoned, not open. The knowledge ladder's framing should be quoted verbatim in
any external statement: optimal under the stated rule, with the divergence from superko
characterized — not "4×4 Go is solved" bare.

---

## 5. Is there hope for 5×5? Yes — but it is a different project shape, not a bigger run

**The current method does not scale to 5×5, by arithmetic, not pessimism.** (Estimates
computed in this review from committed figures; labelled per-line.)

| quantity | 4×4 (measured) | 5×5 (computed estimate) |
|---|---|---|
| legal positions (OEIS A094777) | 24,318,165 | 414,295,148,741 — **×17,037** |
| table entries (4×4 factor ≈ 4.08 applied) | 99,133,036 | ≳ 1.7 × 10¹² (ko-point factor grows with board, so this is a floor) |
| artifact at WZO2 density (5.23 B/entry measured) | 518 MB | ≳ 9 TB |
| in-memory sweep arrays (I5 ledger: ~3.7 GB at 4×4, already 2.3–3.4× forecast) | ~3.7 GB | ~60+ TB |

Four orders of magnitude past the current hardware on memory alone; out-of-core sweeps
(ADR-0012's old roadmap) buy one, maybe one and a half. Symmetry folding (T359, an unworked
backlog row) buys at most ×16 (D4 × colour). Reachability prunes almost nothing (C-A2: 99.9%
of entries are reachable). And the roadmap's warning stands: `canForceLife` is **not** a sound
pruning oracle — 85.3% of its would-be prune class is decisive.

**The hope is real and has prior art — but the deliverable changes.** Van der Werf's MIGOS
solved 5×5 in 2002 (B+25, the whole board — `docs/evidence/van-der-werf-sources/ssgo.pdf`)
by **forward alpha-beta proof search from the root**, not a full-table solve. The honest 5×5
target for this project is the same shape: **a certified root value with a machine-checkable
proof tree / strategy certificate**, not a value for every legal position. What transfers from
the current project is exactly its strongest material:

- the size-generic PROVED rungs (rules kernel, colex, Benson's theorem, area scoring) — the
  certified components a proof search must be built from;
- the validation doctrine (register, per-goban independence, null + seeded-defect controls,
  differentials that demonstrably fire, prediction-before-measurement);
- the loop semantics. This is the deep one: a forward search under superko-like rules hits the
  graph-history-interaction problem the project has already paid for once (ADR-0004, the GHI
  scars); a forward search under **ADR-0020's tie rule** needs exactly the loop-value
  machinery of Gate 2 in §4. **A method that cannot pin the 4×4 root exactly cannot pin 5×5
  at all** — Gate 2 is a prerequisite for 5×5, not just for 4×4 polish.

**The sequencing the landmarks already impose is correct:** L7 (the 5×5 decision, with a price
tag) comes only after L6 (the theorem). Two additions to that: (a) **5×4 is the natural
intermediate rung** — ~1.8 × 10⁹ legal positions (computed estimate: 3²⁰ × ~52% legal
fraction interpolated from measured 4×4/5×5 fractions), giving a ~39 GB artifact and
~280 GB sweep footprint: out-of-core territory, but plausibly one machine — it would exercise
the out-of-core build, the self-derived-count problem (no OEIS for non-square), and the
threshold-value machinery at 75× current scale before anything is bet on 5×5. (b) The cost
axis (roadmap §4: "what does anything cost? nothing measures this today") must exist before a
5×5 price tag can be written at all.

**Verdict: hope, yes — conditional on (1) Gate 2 solved at 4×4, (2) a method pivot to
root-certification by proof search for anything beyond 5×4, and (3) the cost axis existing.
A full 5×5 table is not a realistic target on any near hardware; a certified 5×5 root value
in the MIGOS tradition, with this project's evidence discipline, is.**

---

## 6. Suggestions, ordered

1. **Ratify the knowledge ladder and mechanize it** (M2). Add the rung and rule columns to
   `CLAIMS.md`; teach claimlint to flag a claim whose stated rule differs from its evidence's
   rule. One adjudication, then mechanical forever; it prevents the project's characteristic
   failure class at the linter level.
2. **Run the 3×3 K0 circuit** (§3) as the pilot proof — independent exhaustive re-solve via
   the epic-01 kernel-as-oracle, FP1 provenance, mutation adequacy, G5 test fix. First full
   "provably perfect" deliverable, and the dress rehearsal for 4×4.
3. **Register the threshold-decomposition value computation** (§4 Gate 2) as a hypothesis with
   a proof obligation: spec first, pilot at 2×2/3×2 against the exhaustive ground truths,
   prediction recorded before measurement, then 3×3/4×4. If it survives, the bracket region
   becomes exact values and ADR-0022's resolver problem closes with a proof instead of a
   plugin. Name it after the prior art (threshold/attractor games, classical backward
   induction on loopy games), not a coinage.
4. **Schedule Track A** (`4x4.D3`). It gates the root bracket, "Black wins 4×4", every
   ko-sensitive citation, and (via the shared taint) the old artifacts at four other sizes.
   The writes-off checkpoints in `untracked/` should be committed, hashed, and audited or
   regenerated — they are currently in exactly the volatile-storage state T421 exists to end.
5. **Close the cheap UNTESTED rungs at 4×4**: S2-impl, S4, FP1-C1/C2 (one instrumented
   rebuild + two rerun sweeps), and add the producer/consumer key-agreement battery cell (G4)
   so the project's most expensive bug class finally has standing coverage.
6. **Fix G5 immediately** (the mechanized falsified predicate at `rules.zig:1385,1446`) — it
   is small, known, and every day it stays green it erodes the meaning of green.
7. **Refresh `PROGRESS.md`** (M1) to absorb ADR-0020/WZO2/G3b and the T414–T420 wave, and give
   `SOLUTION-TREE.md` a refresh trigger (M3) so promotions propagate.
8. **Audit the 4×3 root and finish T421** — both are register-integrity items whose absence
   quietly gates other claims (the roadmap already lists the first; the second is in flight).
9. **Hold 5×5 behind L6, add 5×4 as the scale rehearsal, and build the cost axis first**
   (§5) — and record the 5×4/5×5 predictions before the first measurement, the discipline
   that made T394's falsified 4×3 prediction worth having.

---

**One-line close:** the ledger is honest and internally coherent; the gaps are known, named,
and finite; 3×3 is one short circuit away from the project's first certified "provably
perfect" result; 4×4 needs Track A plus a real solution to the bracket-to-value problem —
which is also the admission ticket to any 5×5 ambition, where the realistic prize is a
certified root value in the MIGOS tradition, not a table.

*claude-fable-5, 2026-08-08.*
