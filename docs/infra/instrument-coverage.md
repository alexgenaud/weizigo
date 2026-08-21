# Instrument coverage — which instrument runs which check at which size

```
Task:     T388 (one instrument, every size: make "the same test at every rung" actually true)
Set:      J
Identifier: deepseek-v4-flash/T388
Date:     2026-08-06
Landmark: L0 (the table and the instruments exist)
Scope:    map · name divergences · propose (no rewrites) · demonstrate one differential
Inputs:   docs/evidence/BATTERY/baselines.json · docs/evidence/BATTERY/fleet.md ·
          src/verify_battery.zig + src/vb_*.zig · findings/T343,T344,T345,T346,T363,T258 ·
          docs/epics/E1-markovian/sprints/verify-battery/pass1/spec.md + mutants.md
Acceptance: test -s docs/infra/instrument-coverage.md
```

The operator doctrine (2026-08-06): *"anything on any goban size is a hypothesis to be
determined for each size… we should be able to run the same tests on all board sizes."*
Today we cannot: three of the ladder's most load-bearing checks (I4 Bellman, I5 SCC,
I7 DTT) are performed by **different code at 4×4 than at every smaller rung** — the
battery returns `battery-bad: unsupported goban` for those cells at 4×4
(`baselines.json` comparison_rule: *"4×4 I4/I5/I7: unsupported goban"*), and the 4×4
readings come from separate purpose-built instruments (`vb_bellman_4x4.zig`,
`vb_scc_4x4.zig`, `oracle_v2_accept.zig` A-series) that are not the battery that runs
the smaller rungs. **This document maps the coverage, names the divergences that
matter, proposes (does not perform) the unification, and demonstrates the one test
that would have caught this class — a cross-size differential that FAILS today on the
I5 pair at 3×2.**

Formats: **WZO1** = pinned-v/single-value artifacts (`artifacts/oracle-2x2/3x2/3x3/4x3.wzo`,
`data/oracle-4x4-*.wzo`). **WZO2** = bracket L/H artifacts (`untracked/oracle-v2/oracle-3x3-v2.wzo2`,
`oracle-4x4-v2.wzo2`). Only 3×3 and 4×4 WZO2 artifacts exist in the repo.

---

## 1. The coverage map

### 1.1 I1–I12 via the general battery (`verify-battery`) — one cell per (check, size)

Every cell names the file that implements the check at that size today, and today's
status on the in-scope artifact(s) (worst case; `baselines.json`, T292-ratified; the
4×4 WZO1 row uses `data/oracle-4x4-basicko-tie-area.wzo`). `vb_*` = `src/vb_*.zig`.

| check | 2×2 | 3×2 | 3×3 | 4×3 | 4×4 (WZO1) |
|---|---|---|---|---|---|
| **I1** pin census | `vb_table.checkI1` (:61) — pass | same — pass | same — pass | same — pass | same — pass |
| **I2** colour inversion | `vb_table.checkI2` — pass | same — pass | same — pass | same — pass | same — **fail** (basicko; checkpoints pass) |
| **I3** L ≤ H | n/a (WZO1; `vb_common.notApplicableOnWZO1` :138) | n/a | n/a | n/a | n/a |
| **I4** Bellman residual | `vb_fixpoint.checkI4` (:265) — pass | same — pass | same — pass | same — pass | **error** — `"unsupported goban"` (:271–282) |
| **I5** SCC containment | `vb_graph.checkI5` (:448) — pass | same — pass | same — pass | same — pass | **error** — `"4×4 requires bitset-based BFS (not yet implemented)"` (:468) |
| **I6** UNDEF census | `vb_table.checkI6` (:531) — pass | same — pass | same — pass | same — pass | same — pass (parallel checkpoint **fail**) |
| **I7** DTT sanity | `vb_fixpoint.checkI7` (:359) — fail (uniform 255) | same — fail | same — fail | same — fail | **error** — `"unsupported goban"` (:363–372) |
| **I8** truncation-gap | external fixture, **not in battery**: `vb_fixpoint.checkI8` (:390) is a stub; real check is `docs/evidence/QA-026/calibration-2x2-mismatch.py` | n/a | n/a | n/a | n/a |
| **I9** anchors | `vb_fixpoint.checkI9` (:415) — fail (PSK root ≠ 0) | same — pass (0) | same — pass (+9) | same — n/a (no anchor) | same — pass (basicko +1) / fail (checkpoints) |
| **I10** TIE median | n/a (WZO1) | n/a | n/a | n/a | n/a |
| **I11** move-set consistency | **stub** `vb_fixpoint.checkI11` (:473) — not-applicable (GAP-5) | stub — n/a | stub — n/a | stub — n/a | stub — n/a |
| **I12** score range | `vb_table.checkI12` — pass | same — pass | same — pass | same — pass | same — pass |

Dispatch: `verify_battery.zig:463–528` (table invariants via `vb_table`, fixpoint via
`vb_fixpoint`, graph via `vb_graph`); declared modes from `vb_common.modeForCell`
(:128–136); I8 gated to 2×2 at `verify_battery.zig:480–490`.

**The 4×4 columns are not implemented by this table.** I4/I5/I7 error with
`battery-bad`; I11 never runs (stub). The 4×4 readings for those properties come
from the size-specific instruments below — different code, different formats.

### 1.2 The size-specific instruments (g3b-battery sprint, set E)

| check | instrument | sizes it runs | artifact format | result at 4×4 |
|---|---|---|---|---|
| I4 Bellman | `vb_bellman_4x4.zig` (`i4Bellman`, `run4x4AndWrite` :1014) | 4×4 (exhaustive, all 99,133,036 entries); calibration 3×3 real WZO2 + 2×2 synthetic micro-artifact | WZO2 | pass: violations_clear=0, set=0, cycle_boundary=0 (T343) |
| I4 Bellman (A2) | `oracle_v2_accept.zig` `checkA2` (:729) — **kernel `rules.Rules` move engine** | 4×4 exhaustive (T309) and sampled; WZO2 artifacts at 3×3/4×4 | WZO2 | pass: 0/99,133,036 (A2_exhaustive, baselines.json) |
| I5 SCC | `vb_scc_4x4.zig` `checkI5Small` (:398) — 3×2/4×3 WZO1; `checkI5Wzo1Bitset` (:1378) — 4×3; `checkI5Wzo2` (:810) — 4×4 | 4×4 (99,133,036 entries); 3×2/4×3 as calibration rungs | WZO1 (3×2/4×3) + WZO2 (4×4) | pass: ko_not_cr **0 / 3,455,412** ko_sensitive (T344/T363; `docs/evidence/I5-DISAGREEMENT/adjudication-2026-08-06.md:177`) |
| I7 DTT (A8) | `oracle_v2_accept.zig` `checkA8` (:926) | WZO2 artifacts (3×3, 4×4) | WZO2 | pass (A8, baselines.json) |
| I11 move-set | `vb_i11.zig` `compareDirect` (:275) — 2×2/3×2/3×3/4×3 exhaustive; `compareSmd1` (:174) — 4×4 full SMD1 slice (48,636,330 records); `compareTableDirect` — 4×4 full table (99,133,036 entries) | 2×2–4×4 exhaustive (T473) | none (R8 vs kernel/SMD1) | pass: 0 / 48,636,330 slice + 0 / 99,133,036 table (T473; supersedes T346's 50k sample) |
| C-A1/C-A2 closure | `vb_closure.zig` `ca1ForwardClosure` (:438), `ca2BackwardClosure` (:702) | 3×3 exhaustive (tests); 4×4 full gated `WEIZIGO_CLOSURE_4X4_FULL=1` (T363) | WZO2 | **corrected-decode (kernel successor, T383):** C-A1 children-not-in-table **0 / 616,030,190**; C-A2 reachable-not-in-table **0 / 99,133,034** (2 structurally-impossible non-reachable entries; `findings/T383-ko-decode.json:48`). **Stale-decode (wrong kb>>1, T363):** C-A1 0/600,763,414 · C-A2 0/99,020,312 — superseded |
| key agreement | `differential.zig` T267 (:401) — engine vs builder, self-play/human games; T345 KEY-4×4 (:1244) — producer kernel vs R8 consumer, all 99,133,036 entries | T267: 2×2/3×2/3×3/4×4 (game-sampled); T345: 4×4 only (table-exhaustive); T363 added 4×3 retroactive rung (0/643,378) | WZO2 (4×4); live play (smaller) | pass: 0 mismatches (T345) |
| mutation assertions | `vb_mutants.zig` (M3 :94, M5 :132, M6 :162, M7 :190, M8 :269, M9 :228, M10 :319) | 2×2 WZO1 fixtures (in-memory corruption of `artifacts/oracle-2x2.wzo`); M8 also runs closure at 3×3 | WZO1 | — (no 4×4 WZO1 mutant; WZO2 mutants live in A6) |
| A6 calibration (WZO2) | `oracle_v2_accept.zig` `checkA6` (:1225) | 4×4 WZO2: 3 fixtures (perturbed value→SHA, dropped ko state→file-size, zeroed DTT→A8) | WZO2 | pass 3/3 (baselines.json) |
| battery health (M9) | `vb_health.zig` (T347) — compile-time-reflection runner registry | all sizes (meta, not per-size) | both | — |
| closure counter (C-A1) | `t380_ko_slot.zig` (:850) — correct-ko closure counter over the 4×4 WZO2 table | 4×4 | WZO2 | supplementary (T380 Q1/Q2 instrument) |

### 1.3 Where the size-specific implementation diverges from the general one — the file map

| property | general battery (≤4×3) | size-specific (4×4) | divergent since |
|---|---|---|---|
| I4 Φ operator | `vb_graph.BasicKo` engine, KO_SENSITIVE-set slots excluded, child ko ignored (WZO1 stores at ko=NONE) — `vb_fixpoint.checkI4At` :170 | R8 `vb_movegen.legalMoves` + independent place/capture/ko + areaScore terminals, KO_SENSITIVE = L≠H buckets — `vb_bellman_4x4` | T343 (2026-08-04) |
| I5 graph model | projected (colex,side,ko,passes) with pass as terminal cut-edge (Option A) — `vb_graph.zig:15–16,448` | full (colex,side,ko,passes), passes participate in cycles — `vb_scc_4x4.checkI5Small` :398 | T344 (2026-08-05) |
| I5 KO_SENSITIVE count | artifact-wide flag census (per stored (colex,side)) — `vb_graph.zig:847–869` | graph-restricted at 3×2/4×3 (flags on visited vertices) but artifact-wide L≠H at 4×4 — `vb_scc_4x4.zig:741–757` vs `:861–870` | T344 |
| I7 DTT semantics | terminals DTT=0, non-terminals ≠255 — `vb_fixpoint.checkI7At` :294 | non-constant + recurrence DTT > min(children) — `oracle_v2_accept.checkA8Inner` :955 | T257/T309 (A-series) |
| I11 | stub (never runs) — `vb_fixpoint.checkI11` :473 | full R8-vs-kernel/SMD1 — `vb_i11.zig` | T346 (2026-08-05) |
| I9 anchors | one parametric implementation, per-size anchors — `vb_fixpoint.checkI9` :415 | same function; 4×4 row exists but the battery never runs it on WZO2 | — (not divergent) |

---

## 2. Divergences that matter (could disagree without a test noticing)

### D1 — I4 Bellman: three implementations, disjoint formats, no overlap cell

- General: `vb_fixpoint.checkI4` (WZO1, ≤4×3) — `src/vb_fixpoint.zig:170,265`.
- 4×4 WZO2, battery-side: `vb_bellman_4x4` (R8 movegen + own transform) — `src/vb_bellman_4x4.zig:1014`.
- 4×4 WZO2, acceptance: `oracle_v2_accept.checkA2` (kernel `rules.Rules` move engine) — `src/oracle_v2_accept.zig:729,758`.

Three independent Φ operators (BasicKo engine / R8 / kernel), three verdict shapes
(WZO1: single violations count with KO_SENSITIVE excluded; vb_bellman_4x4: three
buckets clear/set/cycle-boundary; A2: L_violations/H_violations/missing_child). A rule
defect in one engine is invisible to the other two: there is **no size where two of
them run on the same artifact** (WZO1 I4 stops at 4×3; WZO2 I4 starts at 3×3, and the
3×3 WZO1/WZO2 artifacts are different builds). All three pass today — but nothing
verifies they measure the same property.

### D2 — I5 SCC: two implementations of the same check on the same artifact disagree on every count (DEMONSTRATED, §4)

> **SUPERSEDED by T391 (2026-08-06)** — adjudicated and fixed; the differential
> in §4 is now built (`src/i5_differential.zig`). The adjudication
> (`docs/evidence/I5-DISAGREEMENT/adjudication-2026-08-06.md`): same property,
> same artifact; the general instrument was **wrong** on E / maxSCC /
> cycle-reachable / SCC count (passes==2 non-terminal bug + triple-projected
> SCC sizes — now fixed to the register values), and the KO_SENSITIVE
> 378-vs-347 framing below is a scope confusion: 378 is the artifact-wide
> census, 347 is the checked graph-restricted domain, neither is an error.
> T391 additionally found and fixed a third defect: `vb_scc_4x4`'s 4×3
> all-legal CR propagation order fabricated the "24 natural violations"
> (T344/T363); the true reading is 0.

`vb_graph.checkI5` and `vb_scc_4x4.checkI5Small` both run on `artifacts/oracle-3x2.wzo`.
Readings differ: KO_SENSITIVE 378 vs 347 (raw artifact census is 378 — the general
instrument is right, the size-specific one undercounts by 31); cycle_reachable 2,523
vs 1,678; maxSCC 1,000 vs 1,676; edges 7,364 vs 5,510. The size-specific numbers
(1,678 / 1,676) reproduce the committed register spread (1,724 / 1,704 / **1,678**,
`spec.md` §3.3) and `vb_graph`'s own header calibration target (maxSCC=**1,676**,
`src/vb_graph.zig:34`) — which the general instrument today does **not** reproduce
(maxSCC=1,000). Both verdicts are pass, so the disagreement is invisible. This is the
exact failure class the task names: *"a green at 3×3 is not evidence that the 4×4
instrument is even measuring the same property."* T363 already recorded one symptom
(the 3×2 seeded-defect vacuity premise differed between the projected model and the
full graph model — `findings/T363-g3b-completion.json`).

### D3 — I5's own counting convention changes across its rungs

Inside the size-specific instrument: KO_SENSITIVE at 3×2/4×3 is the graph-restricted
flag count (`vb_scc_4x4.zig:741–757`, 347 at 3×2), while at 4×4 it is the artifact-wide
L≠H census (`:861–870`, 3,455,412). The 4×4 number is therefore not comparable to the
3×2 number in the same instrument's output — the ladder's own rungs measure the
property differently from each other, in addition to differing from the general
instrument.

### D4 — I7 DTT: pass conditions differ between formats

WZO1 I7 fails on terminals-with-DTT≠0 and non-terminals-with-255
(`vb_fixpoint.checkI7At` :294); WZO2 A8 demands DTT non-constant and the recurrence
DTT > min(children) (`oracle_v2_accept.checkA8Inner` :955). A WZO2 table with a
uniform-but-terminal-correct DTT column could pass A8's non-constant gate or fail it
independently of the WZO1 semantics. There is no WZO1/WZO2 differential for DTT at any
size. The battery's I7 at 4×4 is `battery-bad` (T258-F3, `fleet.md`) — the v1 DTT
defect that A4 documents is undetectable by the battery's own I7.

### D5 — I11: the battery declares a mode matrix it never executes

`modeForCell` declares I11 exhaustive at 2×2/3×2 and sampled at 3×3+
(`vb_common.zig:128–136`); the battery's I11 runner is a stub returning
not-applicable (`vb_fixpoint.checkI11` :473), so every baseline I11 row reads
not-applicable while the real instrument (`vb_i11.zig`) runs outside the battery
(T346). A reader of `baselines.json` sees I11 "n/a" at every size and cannot tell
that the check exists and passes. The declared matrix and the actual instrument have
diverged; nothing reconciles them. **T473 (2026-08-20) made the real instrument
 exhaustive at 4×4** — 0 / 48,636,330 SMD1 slice records and 0 / 99,133,036 stored
 table entries (`findings/T473-i11-exhaustive.json`) — so `modeForCell`'s 'sampled at
 3×3+' is now wrong on two counts: the battery never executes it, and the instrument
 it describes is exhaustive.

### D6 — key agreement: exhaustive form exists only at the largest rung

T267's game-based form covers all sizes (`differential.zig:401`) but is
sampling; the table-exhaustive form (T345, `:1244`) exists **only at 4×4** — the
rung where a defect is most expensive — because WZO2 artifacts below 3×3 do not
exist. The exhaustive form is never cross-checked against a smaller size, so its
99M-entry path has no small-rung differential against the game-based path.

### D7 — closure: WZO2-only, single artifact pair

`vb_closure.zig` runs 3×3 exhaustive and 4×4 full (T363) — both WZO2. There is no
WZO1 closure instrument and no closure run on any non-square goban; `t380_ko_slot.zig`
(:850) carries a separate correct-ko closure counter at 4×4 with its own vertex-space
semantics. The two 4×4 closure counts (C-A1 children_not_in_table=0) agree on the
verdict but are computed by different instruments against different child relations.

### D8 — mutation assertions: WZO1-2×2 fixtures vs WZO2-4×4 fixtures

`vb_mutants.zig` corrupts the 2×2 WZO1 artifact in memory; the WZO2 mutants live in
A6 (`oracle_v2_accept.checkA6` :1225) at 4×4. A mutant killed at 2×2 WZO1 calibrates
only the WZO1 path; the WZO2 instruments' sensitivity is calibrated by A6's three
fixtures. The two mutant sets share no fixture. Additionally the kill matrix is
internally inconsistent as of this writing: `mutants.md` still lists M8/M10 as
SURVIVED (kill rate 4/10, T347 amendment row) while `vb_mutants.zig` contains
red-then-green tests for M8 (:269) and M10 (:319), and the T363 note claims "seven of
seven mutants now asserted killed" — no catalogue row records that inversion. The
status sources disagree with each other, which is itself a coverage gap.

### D9 — I9 is the one check that is already size-parametric

`vb_fixpoint.checkI9` (:415) holds per-size anchors in one function and runs at every
size the battery supports; the 4×4 row exists but is only ever exercised against WZO1
artifacts. No divergence; listed for completeness.

---

## 3. Unification proposals — costed, NOT performed

Bars: report and propose only; no instrument rewrites in this row. "Cheap" = wiring
or a shared reader; "moderate" = a real refactor with a calibration gate; scale
column marks what is genuinely size-specific (a 99M-entry sweep is not a 25K sweep).

| instrument | proposal | cost | genuinely size-specific? |
|---|---|---|---|
| **I4 Bellman** | Give the general `vb_fixpoint.checkI4` a WZO2 reader (A2 already has the dispatch skeleton, `oracle_v2_accept.zig:729–756`), or factor a Φ core with a pluggable move engine (BasicKo / kernel / R8) and pluggable KO_SENSITIVE policy. Then run a same-artifact differential at 3×3 WZO2 (artifact exists, 49,428 entries) between the general path and `vb_bellman_4x4`/A2, requiring identical (violations, denominator). | moderate | no — 4×4 is a storage/scale issue (99M entries, ~866 MB), not an algorithm fork; the same reader+Φ code handles it |
| **I5 SCC** | Unify the KO_SENSITIVE denominator to the **artifact-wide census** (the convention that matches the WZO1 raw flag census, 378, and the WZO2 L≠H census, 3,455,412). Collapse the 3×2/4×3 overlap to ONE small-goban implementation (either keep `vb_graph.checkI5` or `checkI5Small`, not both). Keep the 4×4 WZO2 bitset/Tarjan path as the scale-specific backend but drive it through the same counting semantics. | low (counting semantics) / moderate (collapse) | yes at 4×4 — 1.46B linear space, ~2.8 GB RSS (T344); no below that |
| **I7 DTT** | Adopt A8's recurrence (DTT > min(children)) as the single definition; either add a WZO1 column reader to A8 or port I7's terminal checks into the WZO2 path. Differential at 3×3 (both formats exist). | moderate | no |
| **I9 anchors** | No work — already parametric. Add a 4×4 WZO2 anchor run so the parametric function is exercised on the artifact it was written for. | none | no |
| **I11** | Wire `vb_i11` as the battery's I11 runner. GAP-5 is closed: the SMD1 dump format exists and T346 verified it (`src/vb_i11.zig:65–128,174`). The declared-mode matrix then matches reality. | low (wiring only) | no longer — T473 ran 4×4 exhaustively (0 / 48,636,330 slice + 0 / 99,133,036 table, 69.5 s, 558 MB RSS); only the battery wiring remains |
| **key agreement** | Run T345's table-exhaustive form at 3×3 WZO2 (49,428 entries) as the small-rung differential; keep T267 game-based as the secondary all-size check. | low | no — the exhaustive form is only 4×4 today because that is where the WZO2 artifact is |
| **C-A1/C-A2** | Already parametric (w,h from header, `vb_closure.zig:438,702`). Declare closure WZO2-only explicitly, or add a WZO1 closure; the full 4×4 sweep (600M children, 1.1 GB) is a scale matter, keep it gated. | low (documentation) | full 4×4 sweep genuinely scale-specific |
| **mutation assertions** | Port the WZO1 2×2 mutant fixtures to WZO2 at 3×3 (construct in memory; the artifact is small enough). Reconcile `mutants.md` with `vb_mutants.zig`/T363 (M8/M10 rows, kill-rate line) so the matrix reflects the code. Kill M1/M2/M4 or mark them definitively unasserted. | moderate | no |

**Cost shape:** the two genuinely scale-specific pieces are I5 at 4×4 (bitset Tarjan,
2.8 GB) and closure at 4×4 (600M children). Everything else is a shared-reader or
wiring change. The largest payoff per unit cost is (a) unifying the I5 counting
semantics — demonstrated divergent today — and (b) wiring I11 so the battery's own
matrix is truthful.

---

## 4. The one test that would have caught this class: the cross-size differential

**Built by T391 (2026-08-06):** `src/i5_differential.zig`, wired into `zig build
 test` — both I5 implementations on `artifacts/oracle-3x2.wzo` (reachable) must
 return identical V, E, maxSCC, cycle_involved, cycle_reachable, ko_sensitive,
 ko_not_cr and verdict. The 4×3 cell is env-gated (`WEIZIGO_I5_DIFF_4X3=1`)
 because linking both instruments in one binary pushes ReleaseFast codegen past
 the tools/runner RSS cap (tooling constraint; the instrument itself runs at
 ~110 MB after BFS). See the adjudication
 `docs/evidence/I5-DISAGREEMENT/adjudication-2026-08-06.md`.

**Specification (as originally proposed by this row):** for every (check, size) cell that
has ≥2 implementations, run both on the **same artifact** and require **identical
readings** — status, numerator, denominator, and (for I5) the graph metrics
(V, E, maxSCC, cycle_reachable, ko_sensitive). Verdict equality alone is not enough:
D2 shows verdicts agreeing while every countable disagrees. The differential should
be a gate on any instrument that claims to check a property another instrument also
checks at an overlapping size.

**Demonstration (performed this row) on the I5 pair at 3×2** — the only
general/size-specific pair that shares both an artifact and a format today. Same
artifact `artifacts/oracle-3x2.wzo` (SHA-256 `d4d22c0d…`), same goban, same graph
convention (reachable-from-empty):

| metric | general `vb_graph` (verify-battery I5) | size-specific `vb_scc_4x4.checkI5Small` | agree? |
|---|---|---|---|
| V | 2,583 | 2,583 | yes |
| E | 7,364 | 5,510 | **no** |
| maxSCC | 1,000 | 1,676 (register target, `vb_graph.zig:34`) | **no** |
| cycle_reachable | 2,523 | 1,678 (register spread, `spec.md` §3.3) | **no** |
| ko_sensitive | 378 (raw artifact census: 378) | 347 | **no** |
| ko_not_cr (violations) | 0 | 0 | yes |
| verdict | pass | pass | yes (the invisible part) |

**Finding F1 — the pair disagrees today.** A cross-size differential requiring
identical readings would have failed these two instruments at T344's 3×2 calibration
rung, before the 4×4 reading was taken. Instead both passed, the disagreement was
never noticed, and the 4×4 reading was certified by an instrument whose counts do not
match the general battery's at the overlapping size. Runs: §5.

**Why this specific harness catches the class:** the divergence mechanism is a
denominator/convention fork (graph-restricted vs artifact-wide flag count; Option-A
cut-passes vs full-pass graph). Verdict-based baselines (`baselines.json`
comparison_rule compares each instrument only against its own baseline) cannot see a
cross-instrument denominator fork; a same-artifact, identical-reading requirement is
the minimal harness that does.

---

## 5. Demonstration runs (cited)

All runs under `tools/runner` (RSS guard 4 GB; `docs/infra/runner.md`), 2026-08-06.

**Run A — general I5, all-legal graph** (`fleet.md`'s default convention):
```
tools/runner -- zig-out/bin/verify-battery 3x2 artifacts/oracle-3x2.wzo \
  --invariants I5 --i5-graph all-legal
  → result: status=pass value={numerator:0, denominator:378}
    stderr: [I5] BFS: V=2958 nodes, E=8656 edges (p0=1002 p1=978 p2=978)
            [I5] Tarjan: SCCs total=439 non-trivial=1 maxSize=1000
                  cycleInvolved=1000 cycleReachable=2886
            [I5] KO_SENSITIVE flags: 378 total, 0 NOT cycle-reachable
```
**Run B — general I5, reachable-from-empty graph:**
```
tools/runner -- zig-out/bin/verify-battery 3x2 artifacts/oracle-3x2.wzo \
  --invariants I5 --i5-graph reachable
  → result: status=pass value={numerator:0, denominator:378}
    stderr: [I5] BFS: V=2583 nodes, E=7364 edges (p0=877 p1=853 p2=853)
            [I5] Tarjan: SCCs total=64 non-trivial=1 maxSize=1000
                  cycleInvolved=1000 cycleReachable=2523
            [I5] KO_SENSITIVE flags: 378 total, 0 NOT cycle-reachable
```
**Run C — size-specific I5, same artifact, reachable seed (T344's calibration test):**
```
tools/runner -- zig test src/vb_scc_4x4.zig --test-filter "SCC structure"
  → [3x2 diag] V=2583 E=5510 maxSCC=1676 nSCC_non_trivial=1
    cycle_involved=1676 cycle_reachable=1678 ko_sens=347 ko_not_cr=0
```
**Run D — size-specific I5, all-legal seed:**
```
tools/runner -- zig test src/vb_scc_4x4.zig --test-filter "spurious KO_SENSITIVE"
  → [3x2 all-legal] V=2958 ko_not_cr=0 hint_colex=null clear_hint_colex=null
    [T344 NOTE] 3×2 all-legal has no non-CR clear-flag slot in the full graph —
    seeded-defect demonstrated at 4×4 instead (… 3×2 and 4×3 are vacuous in the
    full-graph model; 2×2, 3×2, 4×3-reachable share the same vacuity).
```
**Run E — raw KO_SENSITIVE flag census of the artifact** (Python, WZO1 layout,
payload 32 + 6×729 bytes, fb at +2·total, fw at +3·total):
```
flags bit0 set: black=189 white=189 total=378    (fb/fw nonzero: 189/189)
```
Raw outputs saved at `docs/evidence/RESCUED-tmp-2026-08-08/t388-i5-gen.jsonl` (Run A),
`docs/evidence/RESCUED-tmp-2026-08-08/t388-i5-gen-reach.jsonl` (Run B), and in `findings/T388-context.json`.

---

## Landmark

**Landmark:** advances `L0 (the table and the instruments exist)` — the operator can
now see, for every check at every size, which instrument implements it and where the
implementations diverge; the demonstrated I5 disagreement at 3×2 means **the ladder's
small-rung greens do not yet certify that the 4×4 instruments measure the same
property** — the unification proposals (§3) and the cross-size differential (§4) are
the path to making "the same test at every rung" true.
