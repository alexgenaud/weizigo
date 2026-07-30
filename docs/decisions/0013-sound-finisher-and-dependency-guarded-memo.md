# ADR-0013: Sound ko-sensitive finisher — the `ko_ref >= d` bug and the dependency-guarded memo

Status: accepted (bug proven; fix staged)
Date: 2026-07-23
Supersedes the finisher memo discipline assumed in ADR-0010.

## Context

The retrograde engine certifies the history-free core (`L == H`) exactly
(ADR-0009). The remaining KO_SENSITIVE ko-sensitive region (`L < H`) is resolved by the
bracket-guided finisher (ADR-0010), which solves each ko-sensitive slot as a
fresh-start root with a per-root, journal-reverted memo and MTD null-window
probes.

The #2 self-consistency auditor (`RETRO_CONSIST`, docs/research/
consistency-audit.md) **proved** the committed finisher generation is buggy:
on 3×2 it violates the minimax identity at 45 of 378 ko-sensitive slots. Turning
the cross-branch memo writes off (`memo_writes = false`) yields zero
violations. The empty goban is among the 45 (Black score −2 recorded, but its
own best child says 0 — the published score).

## The bug (exact site)

`src/oracle.zig:208` and `src/retro.zig:468`, the memo-write guard:

    if (hashable and ctx.memo_writes and ko_ref >= d) { ... write global memo ... }

- `d = hist.len - 1` — the depth of the node P being solved in the current
  search path.
- `ko_ref` — the shallowest history index that any positional-superko
  repetition anywhere in P's subtree pointed at (`KO_CLEAN` if none).

The guard writes V(P) to the shared table when every repetition in P's subtree
pointed at depth `>= d` (a ko "self-contained" within P's own subtree). The
claim was that such a score is history-free.

**It is not.** `ko_ref >= d` proves only that *this* arrival's subtree
referenced no ancestor above P. It says nothing about a *different* arrival:
when P recurs at another depth d′ under a different ancestor set, a descendant
of P may now repeat one of P′s new ancestors (a ban at depth `< d′` that did
not exist when we memoized), changing P's legal continuations and hence its
score. The entry, written as history-free, is then reused where history
matters — the classic graph-history interaction (GHI) failure. This affects
both the exact-score writes and the fail-soft bounds memo (same guard).

## Decision

Two tracks, deliberately separated by scale.

### Track A — correctness now (through 4×4): writes off

`soundish` (`memo_writes = false`) is self-consistent and its correctness rests
only on invariants the battery already checks: `[L,H]` brackets every arrival
score, the eye-prune is sound, and certified seeds are history-free. With
writes off the only memo entries are certified seeds (read as sound cutoffs);
the search is otherwise plain bracket-guided alpha-beta over the real
positional-superko history along the path — the Exact solver minus its
ban-set-keyed memo. **Regenerate every artifact (2×2..4×4) with writes off,**
re-hash, update `research/retrograde-4x4.md`, and re-run the auditor + battery
+ arena. Gate: zero auditor violations, bracket containment, exhaustive
symmetry, published-anchor agreement, zero arena leaks.

Cost: writes off forfeits the within-search bounds reuse that made MTD probes
incremental. Tractability at 4×4 is being measured; if a full writes-off 4×4
finish is impractical, Track B becomes blocking rather than a follow-up.

### Track B — sound cross-branch reuse via dependency fingerprints (IMPLEMENTED)

Restore sound reuse. The Kishimoto–Müller idea: a memo entry is reusable at a
new arrival only when the new search path cannot introduce or remove a
repetition the stored score relied on. Concretely, an entry's score depends on
the set of goban positions its subtree touched (call it D); reuse is safe iff
none of the current search-path ancestors is in D (a disjoint ancestor set
cannot create a new superko ban inside the subtree, so the score is unchanged).

**Realization (`deps` mode, retro.zig ab_solve):** storing the full set D per
entry is memory-prohibitive, so D is summarized as a **Bloom fingerprint** — a
`64 * FP_WORDS`-bit word with a few hash-selected bits per position. Each node
returns its subtree fingerprint (self OR children OR ban-targets); every memo
write (exact score AND fail-soft bounds) records it, journal-reverted per root.
On read, the entry is honoured only when `fpDisjoint(entry_fp, anc_or)`, where
`anc_or` is the OR of the ancestors' fingerprints threaded down the recursion.
Equal positions hash identically, so a shared set bit is the ONLY way an
ancestor can be in D; bit-disjointness therefore *proves* safety. False
positives (bit collisions) only forgo reuse — never correctness. The unsound
`ko_ref >= d` unconditional reuse is replaced by this guarded reuse.

**Validated (3×2/3×3/4×3):** `RETRO_CONSIST` → deps 0 auditor violations
(self-consistent); `RETRO_DEPSVAL` → deps scores byte-**identical** to
writes-off (correct, not merely consistent). Sound and correct.

**Measured tradeoff (`RETRO_CMP`):** reuse recovery grows with fingerprint
width because a too-narrow fingerprint *saturates* (ko-sensitive subtrees touch far
more than 64 positions, so every entry's bits fill and always collide):

| width | 3×3 nodes (sound=315k, unsound=79k) | 4×3 nodes (sound=183M, unsound=11M) |
|---|---|---|
| 64 bit | 315k (≈0 reuse) | 183M (≈0 reuse) |
| 256 bit | 304k (~4%) | 181M (~1%) |
| 4096 bit | 139k (~75% of gap), ~2× faster | 105M (~45%), ~1.7× faster than sound |

So Track B is **sound, correct, and faster than writes-off** — but the reuse it
recovers is bought with fingerprint memory (`8 * FP_WORDS` bytes per slot per
side), and even at 4096 bits it recovers under half the unsound path's reuse at
4×3 (the unsound path is faster only because its unsafe reuses *happen* to be
correct most of the time). **This memory-for-reuse tradeoff is the central 5×N
obstacle:** at 5×5's ~tens of billions of entries, even a 256-bit fingerprint
is terabytes. Exact dependency sets would be precise but larger still.

Open directions (5×N): out-of-core / streamed dependency storage; shrinking D
to only ancestor-*candidate* positions (those reachable as future ancestors);
per-bound (not shared) fingerprints with replace-not-OR to cut saturation; or
accepting partial reuse. The truly-clean subset (`ko_ref == KO_CLEAN`) is a
sound cheap floor but, on its own, does not make a re-encounter safe (a later
arrival can still collide with the subtree) — so it is not a shortcut.

## Acceptance test (both tracks)

The #2 auditor is the standing gate: **zero minimax-identity violations** on
3×2 exhaustive and on the deepest-N 4×4 sample, for the shipped configuration.
Necessary, not sufficient — combined with bracket containment, symmetry,
anchors, and Exact agreement on reachable slots.

## Consequences

- Committed ko-sensitive scores (`data/oracle-4x4.wzo`, 2×2/3×2/3×3) are NOT
  trustworthy until Track A regenerates them. The certified `L==H` core is
  unaffected and remains correct.
- The history-perfect genmove (GTP player) shares this machinery; it inherits
  the fix automatically once the finisher config is corrected.
