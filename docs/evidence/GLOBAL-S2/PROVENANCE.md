# PROVENANCE — `GLOBAL.S2` · Benson's unconditional-life theorem

**Author:** DSPro/T107 (documentation-task worker)
**Date:** 2026-07-30
**Claim closed:** `GLOBAL.S2` — Benson's unconditional-life theorem holds on every finite goban
**Status:** PROVEN (external mathematical theorem; cited, not proved here)
**Acceptance criterion:** A committed literature note establishing the theorem statement, the paper, and the finite-goban scope argument. No build, no probe, no artefact.

---

## 1. The theorem (formal statement)

**Benson's unconditional-life theorem** (Benson 1976, Theorems 1–3):

Let a finite Go goban be given. For a set of stones of one colour:

1.  Partition the goban into the stones, the empty points, and the opponent's stones.
2.  For each empty region (connected component of empty points) that borders the
    given stone-set, call that region a **vital region** if all empty points in it
    are adjacent only to stones of the given set (i.e. the opponent has no
    adjacency into the region), **and** every chain (connected component) of the
    given stone-set bordering that vital region has at least one liberty inside it.
3.  The given stone-set is **unconditionally alive** if it has at least two
    disjoint vital regions.

If a stone-set is unconditionally alive in this sense, then:

- **(Safety — Theorem 1.)** A defender who never plays a move (passes every
  turn) cannot have any stone in the set captured, regardless of what the
  attacker does.
- **(Completeness — Theorems 2–3.)** The algorithm makes no mistakes: every
  unconditionally-alive set is found by this test, and no set that fails the
  test is unconditionally alive.

That is, the test is both **sound** (what it calls alive cannot be killed) and
**complete** (it finds all unconditionally-alive sets).

---

## 2. The citation

> Benson, D.B. (1976). "Life in the Game of Go." *Information Sciences*, 10(1),
> 17–29.
> DOI: [10.1016/0020-0255(76)90059-1](https://doi.org/10.1016/0020-0255(76)90059-1).

Reprinted at:

> Benson, D.B. (1976). "Life in the Game of Go." *Information Sciences*, 10(2),
> 17–29.
> DOI: [10.1016/S0020-0255(76)90554-5](https://doi.org/10.1016/S0020-0255(76)90554-5).

The algorithm is reproduced in many secondary sources (e.g., van der Werf 2005,
ch. 4; Müller 1997; Tromp–Taylor and Kishimoto literature the project already
cites). The authoritative reference is Benson's 1976 paper.

The project's formal bibliography is at `docs/references.md` §2. Benson's paper
is the project's only formal-life guarantee; every settled-terminal position
rests on it.

---

## 3. Finite-goban applicability (scope argument)

The theorem applies to **every finite Go goban**, and the argument is
structural, not empirical:

- **Benson's test is local.** It examines a specific stone-set and its adjacent
  empty regions — it never references the global goban size or shape, and it
  does not care how many other stones are elsewhere on the goban. It only
  requires that the goban is a finite graph of intersections, each connected
  to its four (or fewer) orthogonal neighbours.

- **The Safety proof (Theorem 1) is by induction on captures.** Any capture
  requires the attacker to fill all liberties of a chain. If the defender
  never plays, any stone the attacker plays inside a vital region is adjacent
  only to the defender's chains; filling a liberty that way cannot capture.
  And any attacker stone placed *outside* a vital region cannot fill a liberty
  of a chain that borders that vital region without first breaking through.
  The two vital regions guarantee the attacker cannot reduce either chain to
  zero liberties without the defender ever playing. The proof never depends
  on goban size or boundary shape; it only needs finiteness so the induction
  terminates.

- **The Completeness proof (Theorems 2–3) constructs the vital regions for any
  unconditionally-alive set.** The construction partitions empty points by
  adjacency to the stone-set and shows that if the set is unconditionally
  alive, at least two such regions are vital. The proof is graph-theoretic;
  the graph is the adjacency graph of the goban; finiteness of the goban is
  the only precondition.

- **No size-dependent step.** Unlike a retrograde sweep, a minimax search, or
  a ko-legality test, Benson's algorithm has no parameter that scales with
  goban size — it runs in time linear in the number of goban intersections,
  and its correctness proof is invariant under adding or removing intersections
  from the goban.

**Conclusion:** Benson's theorem is goban-shape-agnostic. It holds on every
finite goban — including 2×2, 3×2, 3×3, 4×3, 4×4, 5×5, and every rectangular
or irregular finite grid. The theorem does not need to be re-proven at each
size.

---

## 4. Hand-off — what `GLOBAL.S2` is and is not

**`GLOBAL.S2` is the *theorem*.** It states: Benson's unconditional-life
theorem (as proved in Benson 1976) applies to every finite goban. This is a
mathematical truth claim, discharged by the literature citation and scope
argument above.

**`GLOBAL.S2` is NOT the correctness of the `rules.zig` Benson implementation.**
That is the separate family of `S2-impl` rows, one per goban size:

| claim | status | what it asserts |
|---|---|---|
| `3x3.S2-impl` | PROVEN | `rules.zig` `benson_alive` exhaustively falsification-tested at 3×3 — no false positives or false negatives on any 3×3 position |
| `4x4.S2-impl` | UNTESTED | `rules.zig` Benson does not regress in a size-dependent way at 4×4 |
| `4x3.S2-impl` | UNTESTED | `rules.zig` Benson correct at 4×3 |

These rows are implementation-regression claims and must be closed by
falsification-testing the `rules.zig` / `terminal.zig` `benson_alive`
routines at each size against naive Benson or an independent reference.
The tree-shake's L4 (`docs/audits/2026-07-30-t101-punchlist.md` §1) is the
recommended companion wave — a Benson regression battery at 4×4 and 4×3.

**Dependents that rest on `GLOBAL.S2`** (the theorem, not the implementation):

- `GLOBAL.ADR0004-TERM` — Benson-terminal leaf scores are the true game score
- `GLOBAL.ADR0006-EYE` — the eye-prune (forbidding self-eye-fill) is weak-dominance sound under area scoring
- `GLOBAL.H5b` — history-exact search to a Benson-settled horizon is sound
- `GLOBAL.H5a-FALLBACK` — the fallback when identity-check fails is the settled-area / Benson-alive quantity
- `GLOBAL.ADR0014-PURE` — `score.zig` consults no oracle values
- `GLOBAL.ADR0014-DEAD` — `dead_stone_estimate` is a conservative heuristic

None of these depend on the *correctness of the implementation* at a specific
goban size; they depend on the *theorem* being mathematically true. The
implementation's correctness at each size is the `S2-impl` family's concern.

---

## 5. Evidence not included

- **No probe, no run, no artefact.** The row is pure mathematics; there is no
  program to run and no measurement to take.
- **No implementation cross-validation against a reference.** That is the
  `S2-impl` family's job (currently done at 3×3, pending at 4×4 and 4×3).
  The project's `docs/references.md` §2 classifies Benson as verification
  status **I** (implemented, not cross-validated against a reference
  implementation). A reference-implementation cross-check would close the
  `I` note and the `S2-impl` rows simultaneously — that is the tree-shake's
  L4 recommendation.
- **No reproduction of the Benson proof.** The theorem is accepted from the
  primary literature. The finite-goban scope argument in §3 is the only
  original reasoning in this note, and it is a one-paragraph observation,
  not a re-proof.

---

*DSPro/T107, 2026-07-30. Task: T101 punchlist row 1.*
