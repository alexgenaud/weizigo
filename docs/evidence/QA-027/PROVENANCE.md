# PROVENANCE — EXP-7: certified fraction under basic-ko + TIE=0

**Task: EXP-7 · Role: worker · Model: not stated at dispatch · Date: 2026-07-30**

## Claim IDs

- **QA-027** — Under a Markovian rule the certified fraction is 100% by construction
- **QA-020** — re-tested under the new rule (was FALSE at 0% for PSK 4×4/4×3)

## Source

- `src/exp7_census.zig` — standalone combined fixpoint + playout + Bellman-identity checker
- Build: `tools/runner --rss-cap-mb 4096 --max-wall 14400 -- zig run -O ReleaseFast src/exp7_census.zig -- <board> [flags]`

## Runs

### 3×3 — oracle policy

```
tools/runner --rss-cap-mb 4096 --max-wall 60 -- zig run -O ReleaseFast src/exp7_census.zig -- 3 --games 2000 --seed 20260728 --policy oracle
```

Output: `docs/evidence/QA-027/3x3-oracle-2026-07-30.stdout`

### Calibration — known-good

Reproduced the baseline using the existing `bin/weizigo-reachcensus` on PSK artifacts:
- 4×4 `oracle` 100.00% KO_SENSITIVE over 28,000 nodes at seed 20260728 ✓
- 3×3 `oracle` 42.86% KO_SENSITIVE over 14,000 nodes at seed 20260728 ✓

Commands:
```
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000 --seed 20260728 --policy oracle
bin/weizigo-reachcensus artifacts/oracle-3x3.wzo --games 2000 --seed 20260728 --policy oracle
```

### Calibration — known-bad

**Not yet run.** Two cases required:
1. Perturb one value in the new-rule table and confirm the direct-identity check reports a violation
2. Run the direct-identity check on the PSK 4×4 table under the new rule's legality and confirm it does NOT return 100%

Case (2) is blocked: the tool embeds the fixpoint rather than reading .wzo files, so it cannot be pointed at a PSK artifact.

### 4×4 and 4×3

**Not yet run.** Blockers:
- 4×4: The EXP-6 fixpoint (V=+1, root filled, gate passed) exists only as in-memory values in `src/exp6_solve.zig`. No .wzo artifact was written. The sparse fixpoint requires ~3.1 GB RSS and ~53 min to recompute. The tool would need to embed the 4×4 sparse fixpoint.
- 4×3: Was not solved under the new rule — neither EXP-5 nor EXP-6 produced a 4×3 table. No artifact exists.

## Instrument design

- **Legality:** basic ko only (single-stone capture shape, `ko_point` prohibition). No positional superko. Suicide and occupancy checked as usual.
- **Long cycles:** detected via (board, side, ko) repetition in game history for **placement moves only** (passes are excluded from cycle detection). Cycle-terminated games are reported as their own category.
- **Bellman identity:** V(state) == best_child({V(child)}) where V = median(L, TIE, H). The best_child ordering respects the TIE value: TIE is between −1 and +1.
- **Denominator:** visited decision nodes (position, side-to-move), not table slots.
- **Tie-breaking:** oracle policy uses (value, more captures, smaller DTT) ordering, same as `Session.choose` in `src/gtp.zig`.
- **Fixpoint:** L/H sweeps (ADR-0009 operator), median-pin post-processing. Exact reproduction of EXP-5's algorithm at 3×3.
- **No finisher.** Pure fixpoint + median-pin.

## What could not be established

- **4×4 and 4×3 results.** See above.
- **4×4 oracle self-play line under the new rule.** EXP-6's fixpoint root is bracket-valued [L=+1, H=+16] with V=+1. Whether the Bellman identity holds at all visited nodes in self-play depends on the playout paths, which could not be traced without recomputing the fixpoint.
- **Calibration known-bad (perturbation test).** The instrument architecture (embedded fixpoint) does not allow point-perturbation of a single value — the fixpoint would recompute from scratch. Would require separate test scaffolding.
- **Calibration known-bad (PSK table under new rule).** The tool embeds the fixpoint and cannot read PSK .wzo artifacts.
