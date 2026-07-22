# Data model efficiency and plan-A measurements

## Is `blind` + `u16 seq` a good model up to 16 stones?

Clever through ~8–10 stones; increasingly over-provisioned toward 16.

- `(blind, seq)` is a *re-encoding* of the ternary board, not inherently
  smaller: `Σ_blind 2^popcount(blind) = 3^25` exactly. Its power is sparsity +
  per-blind block sizing, not key width.
- `3^25 = 847_288_609_443 ≈ 2^39.6` counts all ternary boards. `C(25,k)·2^k`
  peaks at **k ≈ 16.3**, so "≤16 stones" is *roughly half* of 3^25 —
  restricting to 16 stones saves ~2×, not orders of magnitude.
- Legal 5×5 positions (all k) = **414_295_148_741 ≈ 2^38.6** (Tromp). After
  ~16× symmetry ≈ **2.7×10^10 ≈ 2^34.7** canonical ⇒ **~35 bits** of true
  information per canonical legal position.
- The key spends 25 (blind) + up to 16 (seq) = up to 41 bits, real content
  ~21 (`log2 C(25,16)`) + ≤15 ⇒ ~5–6 bits slack, plus the dense 2^25 blind
  array is ~15/16 empty. Toward 16 stones `collision_size` → 2^(n-1)=32768
  slots/blind with long linear scans = "strange complexity".
- **Tight model (plan C):** combinatorial ranking — rank the k-subset
  (`log C(25,k)` bits) × rank the legal colour pattern ⇒ dense ~35-bit
  minimal perfect hash, no 2^25 waste, no linear scans. The lossless form of
  "compression" compatible with a perfect solve.
- Frequency / move-distance entropy coding helps **game histories** and the
  **score column** (skewed), not the position **key** of a perfect DB (keys are
  ~uniform once symmetry-reduced).

## Plan-A measurements (5×5, iterative deepening, ReleaseFast)

`zig run -O ReleaseFast src/measure.zig`. Clean through depth 6 (depth ≥7
blocked by the bug — see `transposition-bug-root-cause.md`).

| depth | ms | recursions | children | tt_hits | stored | inv% | mir% |
|--:|--:|--:|--:|--:|--:|--:|--:|
| 1 | 0.0 | 8 | 25 | 18 | 8 | 87.5 | 0.0 |
| 2 | 0.1 | 57 | 169 | 113 | 57 | 22.8 | 24.6 |
| 3 | 0.4 | 773 | 1,296 | 524 | 773 | 63.0 | 1.8 |
| 4 | 4.8 | 5,659 | 17,060 | 11,402 | 5,659 | 48.7 | 2.2 |
| 5 | 40 | 53,497 | 119,600 | 66,104 | 53,497 | 60.8 | 0.2 |
| 6 | 277 | 279,186 | 1,074,097 | 794,912 | 279,186 | 53.6 | 0.2 |

Redundancy readout:
- **74% of generated children were cache hits** at depth 6 (transposition +
  symmetry).
- **children → stored collapse ≈ 3.85×** at depth 6.
- **~54% of stored positions folded by black/white inversion** (inv%) —
  the biggest symmetry contributor. Reflection alone (mir%) ≈ 0.2% (rotations
  are already folded into the blind).
- Per-ply growth ≈ 5–9×; wall-clock ≈ 8.5×/ply near the end.

## Known issues surfaced

- **index-0 sentinel**: `seq_next_empty_index` starts at 0; the first stored
  block lands at index 0 which also means "unset" → orphaned/recomputed.
  Reserve index 0.
- `collision_size(9..16)` are 2^(n-1) worst-case placeholders; measure real
  values (and size `seq_table_size`) before deep runs.
