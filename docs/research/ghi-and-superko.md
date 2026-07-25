# GHI (Graph History Interaction) and superko implementation

Why superko complicates a transposition table, and how we handle it
(`decisions/0004`).

## The problem

A transposition table assumes **value is a pure function of the position**
(same board + side ⇒ same value, regardless of path). Transpositions merge
many parents into one node; the TT is that merge.

**Superko breaks the assumption**: whether a move is legal depends on which
positions already occurred on *this path*. Merging two paths into one node
discards exactly the history that decides legality. Minimal example — two
paths reach the same position S, and from S a move `m` would recreate an
earlier position X:

```
   root
   /   \
  X     Y
   \   /
    S      m recreates X
```

- via X: X already occurred → `m` illegal.
- via Y: X never occurred → `m` legal.

Same node S, different legal moves → possibly different value. One TT entry
can't hold both. This is **Graph–History Interaction**. In Go it *is* the ko
fight: "can I retake the ko now?" depends on the ko-threat/response history.

GHI is separate from scoring, and only bites in branches containing a live
ko/repetition — most of the 5×5 tree is GHI-free.

## Implementation plan

### Detection (transient, on the search stack)

- Keep a **path-set of Zobrist hashes** of ancestor positions (reuse
  `zobrist.zig`); push on descend, pop on ascend.
- A move is superko-illegal iff its resulting board hash is already in the set.
- PSK ⇒ hash the **board only**. (SSK ⇒ hash (board, side); one extra bit.)
- The set is empty until the first capture (no repetition possible before
  then), and can be **pruned at irreversible moves**: once a stone is
  unconditionally alive (Benson), every prior position lacking it can never
  recur, so drop those hashes. ⇒ active history ≈ "positions since the last
  irreversible change", bounded and small.

### Caching (persistent TT) — the "null-history" model

- Each position has **at most one unconditional value** (the value when no ko
  constraint bears on its subtree). Many histories reach a position but almost
  all impose no relevant ban, so they share this one value.
- **Cache only unconditional values.** If a node's subtree invoked a superko
  ban referencing an ancestor *above* it, mark it **tainted** and don't cache
  it (recompute on re-encounter). Conservative taint = "any ban fired in the
  subtree" — over-recomputes slightly, correct, simple.
- Do **not** store position sequences in the TT — only a value + a clean/tainted
  flag. (Kishimoto–Müller: cache tainted values tagged with the minimal
  ancestor dependency set — deferred optimization.)

## PSK vs SSK cost

Nearly identical. SSK just includes side in the ko hash and happens to align
with the (board,side)-keyed TT; the hard part (the clean/tainted flag) is the
same either way. Project uses PSK.

## Empirical: superko really happens on 5x5 (2026-07-15)

Confirmed with `src/ko_probe.zig`, a self-contained walker over legal 5x5 lines
that classifies each repetition ban by cycle length
`dist = history.len - matched_ply` (`dist == 2` = simple ko, `dist >= 3` =
genuine superko only the whole-history rule catches). A depth-capped 40M-node
sample from the empty board hit **13,908 simple-ko** and **414 genuine superko**
bans (cycles of 3–5 plies). Superko events are a normal feature of legal play,
not an edge case, so a simple-ko rule would NOT guarantee termination on 5x5 —
PSK is necessary, not just tidy. Twelve replay-verified example games (6 superko
+ 6 simple) are in `docs/research/ko-examples.md`.

The *exact* frequency and cycle length depend on the move distribution: an
earlier eye-pruned minimax traversal saw far more superko bans and cycles up to
25 plies. The qualitative fact (superko occurs, abundantly) is robust; the
precise counts are not a fixed property. (Three *independent* simultaneous kos —
classic triple ko — is a separate, much tighter geometric question; not
observed.)
