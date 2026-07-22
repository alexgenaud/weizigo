# 0007 — Goal: build a compressed perfect oracle (not just the value)

Date: 2026-07-16 · Status: **accepted**

Resolves the top open fork in `docs/research/strategy-open-questions.md`
("The goal fork — decide first, everything follows").

## Decision

The project aims for **goal (b): a compressed perfect oracle** — the
game-theoretic value of **every reachable (position, side-to-move)** — **not**
goal (a) (proving just the single number, e.g. 5×5 = B+25).

Coverage IS the deliverable: handicaps, either side to move, midgame entry,
teaching. This is the artifact van der Werf did *not* produce, so it is the
project's genuine niche.

Terminology fixed to avoid confusion: the oracle is over **positions** (DAG
nodes), not over **paths/games** (astronomically more numerous — never
enumerated).

## Consequences (what follows from choosing (b))

### Engine: NO value-based pruning
- **Alpha-beta / proof-number search is out of scope.** It returns the root
  value plus only *bounds* for most nodes and prunes whole subtrees unvisited —
  it cannot populate an oracle. This **scraps the former TODO #6** (alpha-beta +
  move ordering), which was a goal-(a) tool.
- The oracle engine is either:
  - **Retrograde / layered fixpoint** (efficient target): propagate values up
    from true terminals. Note captures create **back-edges** (k stones → k−3),
    so this is a **fixpoint iteration, not a single topological sweep**.
  - **Exhaustive forward minimax + exact-value TT** (current `solve.zig`):
    a valid but inefficient oracle-builder; keep as the reference / cross-check
    until retrograde is built and validated.

### Eye-prune (ADR-0006) is now in tension — OPEN
`solve.is_own_eye` is a forward-search device that omits *legal* eye-filled
positions. A literal "value of every position" oracle would need those too.
Resolution deferred: decide whether the oracle is scoped to
"positions reachable under non-dominated play" (prune stays) or truly every
legal position (retrograde evaluates them regardless of the forward prune).
Flag before persisting values.

### Persistence is now first-class → port `persist.zig`
The oracle must checkpoint value tables to disk. `persist.zig` (delta+varint
codec) is therefore **worth keeping** — this resolves the open #2 sub-decision
in favour of **porting `persist` to `solve.Table`** (swap `mm.seq_score` →
`solve.SeqScore`, `mm.collision_size` → `solve.block_size`; add a round-trip
test), rather than quarantining it with the rest of the old path.

### Data model (the potential innovation)
Combinatorial ranking / minimal perfect hash: ~1 byte per canonical
(position, side); the index IS the key. Storage ~tens of GB canonical for 5×5;
disk is not the constraint. Regenerate + verify; keep the blob out of git.

### Structure vs values
Enumerating positions + legal moves ("structure") is cheap, correct, and
persistable **now**. Correct **values** require propagation from *true*
terminals + fixpoint over capture back-edges. "Start in the midgame" works for
structure, not for values.

## Correctness prerequisites before persisting any VALUES (recap)
1. `is_settled` terminal bug — **fixed** (b18e49d, terminal-territory-bug.md).
2. Superko / GHI clean-vs-tainted caching — `ko_ref` framework in `solve` (ADR-0005).
3. Chinese/area terminal score is history-independent — OK (Japanese would need
   capture tracking, later).

## Board-size frontier
5×5 (B+25) first, then 6×6 (B+4), aim at 7×7 (aspirational). 8×8 out of reach.

## Disk / git policy (unchanged)
Computed data (DB, checkpoints) = build artifacts → gitignore. Commit the
generator + a manifest/hash of expected output, not the blob.
