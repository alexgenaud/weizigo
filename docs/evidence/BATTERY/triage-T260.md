# T260 — fleet failure triage

```
Author: unknown/T260 · 2026-08-02
Source: docs/evidence/BATTERY/fleet.md (T258, V-13)
```

8 FAIL + 6 ERR across 60 cells. Analysis only — no code or artifacts changed.

Written by Orcha from `findings/T260-fleet-triage.json` — the worker put its
analysis there and never produced this declared deliverable.

| # | finding | verdict |
|---|---|---|
| T260-F1 | I7 — DTT uniformly 255 at 2×2/3×2/3×3/4×3 | **ARTIFACT DEFECT (confirmed)** |
| T260-F2 | I2 — colour inversion FAIL at 4×4 basicko | **ARTIFACT DEFECT (confirmed)** |
| T260-F3 | I9 — anchor FAIL at 2×2, FAIL on 4×4 checkpoints, PASS at 3×2/3×3 | **CHECKER DEFECT (confirmed)** |
| T260-F4 | I6 — UNDEF census FAIL on parallel checkpoint | **ARTIFACT DEFECT (confirmed)** |
| T260-F5 | I4 Bellman residual ERR at 4×4 (3 artifacts) | **BATTERY SCOPE LIMITATION (confirmed)** |
| T260-F6 | I5 SCC containment ERR at 4×4 (3 artifacts) | **BATTERY SCOPE LIMITATION (confirmed)** |
| T260-F7 | I7 DTT sanity ERR at 4×4 (3 artifacts) | **BATTERY SCOPE LIMITATION (confirmed)** |
| T260-F8 | I1 pin census — 4×4 basic-ko artifact has legal side asymmetry | **COLLATERAL OBSERVATION (not a fleet FAIL, but worth noting)** |


## T260-F1 — I7 — DTT uniformly 255 at 2×2/3×2/3×3/4×3

**ARTIFACT DEFECT (confirmed)** (settled)

- vb_fixpoint.zig:302-316 — checkI7At iterates legal slots, classifies terminals via isTerminal(K, pos, side, KoNone), flags any terminal with DTT≠0 as bad. All PSK artifacts have DTT uniformly 255 (DTT_FAR).
- Python spot-check of oracle-4x4-basicko-tie-area.wzo db column: first 10K unique={255}, last 10K unique={255}. The retrograde engine initialises DTT with @memset(dtt, DTT_FAR) and never computes it for PSK artifacts.
- Contrast: data/reuse-baseline/oracle-4x4.wzo (also WZO1 format, different build) has 31 distinct DTT values including 0 — DTT was populated there.
- vb_fixpoint.zig:340-342 test 'I7 DTT sanity on 4x4 basicko-tie artifact (must fail)' — the battery itself asserts this artifact MUST fail I7. The test says: 'A4: the v1 4×4 artifact must fail I7 (DTT uniformly 255 including terminals).'

**Ruling.** The DTT column was never computed for WZO1 artifacts produced by the PSK retrograde engine. The checker correctly detects terminals with DTT=255 as violations. NOT a checker defect.

## T260-F2 — I2 — colour inversion FAIL at 4×4 basicko

**ARTIFACT DEFECT (confirmed)** (settled)

- vb_table.zig:335-379 — checkI2 implements independent colex bijection and colour inversion: V(-pos,-side) == -V(pos,side). Re-implemented from scratch per R8 (does not import src/).
- Python independent verification: 11,658,047 deduplicated violations on data/oracle-4x4-basicko-tie-area.wzo. First 5 violation examples: colex(6)=(16,-1), colex(11)=(16,16), colex(14)=(16,6), colex(20)=(3,-16), colex(24)=(-16,-16). All are near the empty board (low colex indices = few stones).
- Checkpoint and parallel checkpoint artifacts pass I2 (0 violations). Only the basic-ko artifact fails.
- Magnitude: ~11.7M violations out of ~24.3M legal positions ≈ 48% of the artifact is colour-inversion-inconsistent.

**Ruling.** The vb/vw columns of the basic-ko artifact contain massive colour-inversion violations. The checker independently re-implements the colex bijection (R8) and correctly identifies them. NOT a checker defect.

## T260-F3 — I9 — anchor FAIL at 2×2, FAIL on 4×4 checkpoints, PASS at 3×2/3×3

**CHECKER DEFECT (confirmed)** (settled)

- vb_fixpoint.zig:315-350 — checkI9 uses a hardcoded anchor table keyed only on goban size. It does NOT inspect the artifact's rules_id field (available from dec.header.rules_id = bytes[9]).
- The committed anchors are basic-ko values: 2×2=0, 3×2=0, 3×3=+9, 4×4=+1 (from spec §4 I9).
- 2×2 artifact is PSK (rules_id=1). The PSK empty-board value differs from 0 (basic-ko anchor). The checker applies the basic-ko anchor without checking ruleset.
- 3×2 artifact is PSK but root=0 matches the basic-ko anchor — so I9 passes at 3×2 by coincidence, not by correctness.
- 3×3 artifact is PSK but root=+9 matches the basic-ko anchor — again coincidental.
- 4×4 checkpoint/parallel are PSK (rules_id=1) with root values ≠ +1 (the basic-ko anchor).
- 4×4 basicko is basic-ko (rules_id=2) with root=+1 — passes.
- vb_fixpoint.zig:380-384 — test 'I9 anchors on 2x2 artifact' acknowledges: 'PSK artifact (rules_id=1): root value may differ from basic-ko anchor. Anchor mismatch is expected for non-basic-ko artifacts.' — but the production checkI9 reports it as FAIL rather than not-applicable.

**Ruling.** The checker applies basic-ko anchors to PSK artifacts without ruleset discrimination. A correct checker would either: (a) use ruleset-specific anchors, or (b) report not-applicable for non-matching rulesets. The 3×2 and 3×3 PASSes are coincidental (same root values under both rulesets). The 2×2 and 4×4 checkpoint FAILs are checker defects.

## T260-F4 — I6 — UNDEF census FAIL on parallel checkpoint

**ARTIFACT DEFECT (confirmed)** (settled)

- vb_table.zig:430-465 — checkI6 computes legal_positions_total = legal_both_sides + legal_one_side_only, compares to header.legal_count.
- Python independent verification of data/oracle-4x4-parallel.checkpoint.wzo: header legal_count=24,318,165. Columns: b_legal=24,273,746, w_legal=24,273,746, both_legal=24,234,638, one_side=78,216. Computed total=24,234,638+78,216=24,312,854. DIFF: +83,527 (header over-reports).
- Contrast: checkpoint artifact has both_legal=24,318,165, one_side=0 — exact match. basicko artifact has both_legal+one_side=24,318,165 — exact match.
- The parallel checkpoint was produced by a different build of the retrograde engine. The mismatch means the artifact's column data disagrees with its own header.

**Ruling.** The artifact's internal data is inconsistent. The checker correctly computes legal positions from the stored columns and finds they don't match the header. NOT a checker defect.

## T260-F5 — I4 Bellman residual ERR at 4×4 (3 artifacts)

**BATTERY SCOPE LIMITATION (confirmed)** (settled)

- vb_fixpoint.zig:229-240 — checkI4 dispatches on goban size via switch. 4×4 falls to else branch returning I4Result{.status=.err, .err_msg='unsupported goban'}.
- The withBasicKo helper (vb_fixpoint.zig:167-181) only handles 2×2, 3×2, 3×3, 4×3. 4×4 would hit @compileError.
- Stderr from all three 4×4 fleet runs shows no I4-related messages beyond the generic battery-bad exit.
- This is documented as unbuilt scope in fleet.md T258-F3.

**Ruling.** vb_fixpoint.zig does not implement BasicKo(4,4). The ERR is a genuine unbuilt feature, not a disguised failure.

## T260-F6 — I5 SCC containment ERR at 4×4 (3 artifacts)

**BATTERY SCOPE LIMITATION (confirmed)** (settled)

- vb_graph.zig — I5 BFS internally detects that 4×4 linear space (1,463,588,514) exceeds hash-map limit (50,000,000) and errors.
- Stderr: '[I5] WARNING: goban 4x4 linear space 1463588514 exceeds hash-map limit 50000000. [I5] Full bitset BFS (i5-feasibility.md phase 1–3) not yet implemented in this module.'
- Documented in fleet.md T258-F4 as a known gap requiring rank-support bitset approach (~1.2 GB RSS).

**Ruling.** Bitset BFS is genuinely not implemented for 4×4. The ERR is a documented scope limitation.

## T260-F7 — I7 DTT sanity ERR at 4×4 (3 artifacts)

**BATTERY SCOPE LIMITATION (confirmed)** (settled)

- vb_fixpoint.zig:294-307 — checkI7 dispatches identically to checkI4: 4×4 falls to else returning .err with 'unsupported goban'.
- Same root cause as I4: vb_fixpoint.zig does not implement BasicKo(4,4).
- Note: even if the check ran, the v1 basicko artifact WOULD fail I7 (uniform 255 DTT — see T260-F1). The ERR means the battery can't detect the known defect (T258-F3: A4 sensitivity failure).

**Ruling.** Same scope limitation as I4. The ERR is genuine unbuilt scope, but this specific gap is BLOCKING per T258-F3 because the v1 DTT defect (A4) is undetectable with the current battery.

## T260-F8 — I1 pin census — 4×4 basic-ko artifact has legal side asymmetry

**COLLATERAL OBSERVATION (not a fleet FAIL, but worth noting)** (noted)

- Python analysis: basicko artifact b_legal=24,252,631, w_legal=24,252,631, both_legal=24,187,097, one_side=131,068.
- This means 65,534 positions are legal for Black but NOT White, and another 65,534 are legal for White but NOT Black.
- The checkpoint artifact has zero one-side-only positions. The parallel checkpoint has 78,216 one-side-only.
- checkI1 in vb_table.zig scans both sides but doesn't differentiate — it only checks KO_SENSITIVE bit, so the asymmetry is invisible to I1.

**Ruling.** The basicko artifact has asymmetric legality (positions legal for one side but not the other). This is a property of basic-ko (ko_point asymmetry) but the magnitude is not cross-checked against the ko model. Not a fleet failure, but material for I11 (move-set consistency).
