# ADR-0013: Sound residue finisher — the `ko_ref >= d` bug and the dependency-guarded memo

Status: accepted (bug proven; fix staged)
Date: 2026-07-23
Supersedes the finisher memo discipline assumed in ADR-0010.

## Context

The retrograde engine certifies the history-free core (`L == H`) exactly
(ADR-0009). The remaining KO_SENSITIVE residue (`L < H`) is resolved by the
bracket-guided finisher (ADR-0010), which solves each residue slot as a
fresh-start root with a per-root, journal-reverted memo and MTD null-window
probes.

The #2 self-consistency auditor (`RETRO_CONSIST`, docs/research/
consistency-audit.md) **proved** the committed finisher generation is buggy:
on 3×2 it violates the minimax identity at 45 of 378 residue slots. Turning
the cross-branch memo writes off (`memo_writes = false`) yields zero
violations. The empty board is among the 45 (Black value −2 recorded, but its
own best child says 0 — the published value).

## The bug (exact site)

`src/oracle.zig:208` and `src/retro.zig:468`, the memo-write guard:

    if (hashable and ctx.memo_writes and ko_ref >= d) { ... write global memo ... }

- `d = hist.len - 1` — the depth of the node P being solved in the current
  search path.
- `ko_ref` — the shallowest history index that any positional-superko
  repetition anywhere in P's subtree pointed at (`KO_CLEAN` if none).

The guard writes V(P) to the shared table when every repetition in P's subtree
pointed at depth `>= d` (a ko "self-contained" within P's own subtree). The
claim was that such a value is history-free.

**It is not.** `ko_ref >= d` proves only that *this* arrival's subtree
referenced no ancestor above P. It says nothing about a *different* arrival:
when P recurs at another depth d′ under a different ancestor set, a descendant
of P may now repeat one of P′s new ancestors (a ban at depth `< d′` that did
not exist when we memoized), changing P's legal continuations and hence its
value. The entry, written as history-free, is then reused where history
matters — the classic graph-history interaction (GHI) failure. This affects
both the exact-value writes and the fail-soft bounds memo (same guard).

## Decision

Two tracks, deliberately separated by scale.

### Track A — correctness now (through 4×4): writes off

`soundish` (`memo_writes = false`) is self-consistent and its correctness rests
only on invariants the battery already checks: `[L,H]` brackets every arrival
value, the eye-prune is sound, and certified seeds are history-free. With
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

### Track B — speed at 5×N: Kishimoto–Müller dependency-guarded memo

Restore sound cross-branch reuse. Each residue memo entry records the set of
history positions its value depended on for repetition detection (the
Kishimoto–Müller GHI solution). An entry is reusable at a new arrival iff every
position in that dependency set has the same in-path / not-in-path membership
as when the entry was written — i.e. the new path cannot introduce or remove a
repetition the stored value relied on. Sound by construction; the
`ko_ref >= d` scalar is replaced by a membership test against the recorded set.

Open implementation question (defer to 5×N work, profile first): the
dependency set is variable-size per residue slot. The truly-clean subset
(`ko_ref == KO_CLEAN`, no repetition anywhere in the subtree) is already sound
to memoize globally and is the cheap floor; the value of KM is precisely the
residue entries between that floor and the flawed `ko_ref >= d` ceiling.

## Acceptance test (both tracks)

The #2 auditor is the standing gate: **zero minimax-identity violations** on
3×2 exhaustive and on the deepest-N 4×4 sample, for the shipped configuration.
Necessary, not sufficient — combined with bracket containment, symmetry,
anchors, and Exact agreement on reachable slots.

## Consequences

- Committed residue values (`data/oracle-4x4.wzo`, 2×2/3×2/3×3) are NOT
  trustworthy until Track A regenerates them. The certified `L==H` core is
  unaffected and remains correct.
- The history-perfect genmove (GTP player) shares this machinery; it inherits
  the fix automatically once the finisher config is corrected.
