# verify-battery — golden-master baselines and the gate (T292)

```
Task:   T292 · Role: worker · Model: not stated at dispatch · Date: 2026-08-03
Status: DELIVERED — baselines recorded, comparison semantics defined, gate wired
Parent: pass1/spec.md (T290) · pass1/mutants.md (T291)
Inputs: Amendment 1 (Feathers 2004 — golden master / characterization testing),
        DIRECTION.md §5, pass1/spec.md §7 (regression baseline), this sprint's
        verify-battery implementation (src/verify_battery.zig + vb_*.zig, T168-T187)
Prior art: Feathers, *Working Effectively with Legacy Code* (2004), ch. "Characterization Testing"
```

**A regression input's pass condition is "unchanged from the recorded baseline" —
never "fails".** This document records the baseline — every in-scope artifact,
every check, every denominator — and defines the comparison precisely enough to
mechanise. The machine-readable copy is `docs/evidence/BATTERY/baselines.json`
(committed; the gate reads it). The suite gate is `tools/regression-battery-
baselines.sh` (wired into `zig build test`); the slow full-artifact sweep is
`zig build battery-sweep`.

---

## 1. What was recorded, and how

Every in-scope artifact was run through the battery on 2026-08-03, under
`tools/runner` (RSS cap 4096 MB per PID, one invocation at a time — no
concurrent sweeps, GRAND-AUDIT §3). Recorded per check: status, numerator /
denominator, declared/actual mode, exit class, plus the command, the artifact
SHA-256 and the binary version stamp. Raw JSONL of every run is in
`docs/evidence/BATTERY/baselines.json` (normalized) — the run transcripts were
captured at `/tmp/weizigo/*-baseline.jsonl` during the session (disposable).

| instrument | version stamp | binary SHA-256 |
|---|---|---|
| `zig-out/bin/verify-battery` | `verify-battery f8eb7c3-dirty built 2026-08-03T01:35:58Z zig 0.16.0` (HEAD `f8eb7c3`, dirty tree, ReleaseFast) | `8e8ee52b05cc8520ed18cdb4e358952f3c11dd0c` (legacy 40-hex; T309: field renamed from sha256 — the T292 binary is gone, a proper SHA-256 cannot be retroactively computed) |
| `oracle-v2-accept` (WZO2 acceptance) | built 2026-08-03 from `src/oracle_v2_accept.zig` at HEAD `f8eb7c3`, ReleaseFast | `2d04767aee004da5d863efcde654d61bc7be54f9` (legacy 40-hex; T309: field renamed from sha256 — first 40 chars of actual SHA-256) |

Commands: `tools/runner -- zig-out/bin/verify-battery <goban> <artifact>` (all
twelve invariants, JSONL to stdout) and `tools/runner -- <oracle-v2-accept>
untracked/oracle-v2/oracle-4x4-v2.wzo2 [a1..a9]` (per-check invocations for
machine-readable counts — see §6 finding F6 for why).

### 1.1 The seven WZO1 artifacts — headline readings

| artifact (SHA-256 prefix) | goban | rules | I1 pin | I2 inv | I4 Bell | I5 SCC | I6 census | I7 DTT | I9 anchor | I12 range |
|---|---|---|---|---|---|---|---|---|---|---|
| `artifacts/oracle-2x2.wzo` `1ed06e64…` | 2×2 | PSK | pass 32/114 | pass 0/57 | pass 0/28 | pass 0/82 | pass 57/81 | **fail 8/114** | **fail** (root +1, anchor 0) | pass 0/114 |
| `artifacts/oracle-3x2.wzo` `d4d22c0d…` | 3×2 | PSK | pass 600/978 | pass 0/489 | pass 0/540 | pass 0/378 | pass 489/729 | **fail 52/978** | pass (root 0) | pass 0/978 |
| `artifacts/oracle-3x3.wzo` `c1f8fe5e…` | 3×3 | PSK | pass 16,652/25,350 | pass 0/12,675 | pass 0/15,742 | pass 0/8,698 | pass 12,675/19,683 | **fail 822/25,350** | pass (root +9) | pass 0/25,350 |
| `artifacts/oracle-4x3.wzo` `5316f428…` | 4×3 | PSK | pass 473,102/643,378 | pass 0/321,689 | pass 0/463,024 | pass 0/170,276 | pass 321,689/531,441 | **fail 9,766/643,378** | n/a (no anchor) | pass 0/643,378 |
| `data/oracle-4x4-basicko-tie-area.wzo` `edd9f68e…` | 4×4 | basic-ko | pass 46,543,120/48,505,262 | **fail 11,658,047/24,318,165** | **error** (unsupported) | **error** (unsupported) | pass 24,318,165/43,046,721 | **error** (unsupported) | pass (root +1) | pass 0/48,505,262 |
| `data/oracle-4x4.checkpoint.wzo` `a2174fed…` | 4×4 | PSK | pass 38,268,408/48,636,330 | pass 0/24,318,165 | **error** | **error** | pass 24,318,165/43,046,721 | **error** | **fail** (root +2, anchor +1) | pass 0/48,636,330 |
| `data/oracle-4x4-parallel.checkpoint.wzo` `28afa11b…` | 4×4 | PSK | pass 38,268,408/48,547,492 | pass 0/24,318,165 | **error** | **error** | **fail 24,312,854/43,046,721** | **error** | **fail** (root UNDEF) | pass 0/48,547,492 |

Peak RSS per run (battery trailer `rss_hwm_after_mb`): 2×2 1.9 MB · 3×2 3.0 MB ·
3×3 22.4 MB · 4×3 544.4 MB · 4×4 v1 823.2 MB · 4×4 checkpoint 823.2 MB ·
4×4 parallel 823.2 MB · WZO2 acceptance 1,361 MB. All ≤ 4 GB; none approached
the cap (the host kernel-panic precedent at 12.5 GB is untouched).

### 1.2 The WZO2 artifact — `untracked/oracle-v2/oracle-4x4-v2.wzo2` (`0c3366f0…`)

Read by the WZO2 acceptance instrument (`oracle-v2-accept`), not the battery
(the battery's loader rejects WZO2 by design — `decodeWZO1` returns
`WZO2NotSupported`). **All checks PASS** — completeness checks pass, as
Amendment 1 requires:

| check | verdict | measurement |
|---|---|---|
| A1 self-play | PASS | refusals 0 / 200 queries |
| A4 pin census | PASS | pin_L==pin_H; pin_T=95,677,624 pin_L=1,280,098 pin_H=1,280,098 pin_0=895,216 over 99,133,036 entries |
| A2 Bellman | PASS | L/H violations 0, missing_child 0 over checked=99,432 (stride 997, denominator 99,133,036) |
| A3 colour inversion | PASS | 0 violations, 0 not_found, checked 99,133,036 (exhaustive) |
| A5 round-trip | PASS | 0 mismatches over 1,021,991 checked (stride 97, denominator 99,133,036) |
| A8 DTT | PASS | non-constant, far=0, terminal_dtt0_errs=0; consistency 0 violations over 49,592 (stride 1999) |
| A6 calibration | PASS | 3/3 synthetic fixtures caught (perturbed value→SHA-256, dropped ko state→file size, zeroed DTT→A8) |
| A9 reproducibility | PASS | embedded SHA matches computed; groups_sorted, entries_sorted, entry_order_violations=0 |

Group-size distribution (verified during this task): 24,318,165 groups,
99,133,036 entries; sizes {2: 131,068, 4: 22,146,993, 5: 1,959,216, 6: 79,472,
7: 1,312, 8: 104}. **No zero-entry groups; cumulative entry count matches the
header exactly** — the structural-completeness reading (G3a discharged) holds
at group granularity too.

The 131,068 size-2 groups echo T266's "131,068 absent passes=1 entries" number.
They are *positions* (one-side-legal, both passes present), not missing
entries; the numeric coincidence is noted, not resolved here.

---

## 2. What "newly fails" means, mechanically

**A regression is any difference from the recorded baseline in the cell tuple**

```
(status, numerator, denominator, mode_declared, mode_actual, exit_class,
 seed, sample_size, sample_denominator)
```

compared under **exact equality — no tolerance**. This is the whole rule; the
gate (`tools/battery-baseline-compare.py`) implements exactly this tuple.

Consequences, made explicit:

- **A recorded `fail` is a characteristic, not a gate failure.** The v1 4×4 I2
  failure (11,658,047/24,318,165) is the *baseline*. The gate compares the
  recorded numbers: 11,658,047 stays green; 11,658,048 or 0 are both diffs.
  This is the "in either direction" signal the brief demands — a repair of a
  known defect is as much a change to adjudicate as a new failure.
- **`deviation` (the I9 note text, I8's note) is informational and does not
  trigger.** It is a diagnostic string, not a measurement. The counts are the
  measurement.
- **Sampled checks carry their sample parameters in the baseline and compare
  them exactly** (seed, sample_size, sample_denominator, stride where the
  instrument reports it). A sampled check with an **unfixed seed
  (`seed_source=auto`) is NOT a golden master** — it is excluded from
  comparison and must be declared "not baselined" in the baseline document.
  None exist in the current battery: every sampled cell today (the WZO2
  acceptance A2/A5/A8 strides) is a fixed stride from entry 0, fully
  deterministic, so exact equality is well-defined.
- **Status `error`/battery-bad is a baseline too.** The 4×4 cells I4/I5/I7
  error because the battery's fixpoint/graph dispatch stops at 4×3 (finding
  F4). A future battery that implements 4×4 changes those cells; the change is
  adjudicated and the baseline updated, not auto-failed.
- **A check the run produces but the baseline lacks (or vice versa) is a
  diff.** If the battery ever gains a thirteenth invariant, the gate names it.

### 2.1 A5's stride, and what the coprimality question means for it

A5 (WZO2 round-trip) samples every 97th entry at 4×4 (1,021,991 of 99,133,036
entries). T215/T223 recorded that stride 97 was never verified coprime to the
group-size distribution. This task computed it directly from the artifact's
group index:

> **Group sizes in `0c3366f0` are {2, 4, 5, 6, 7, 8} — all < 97 and all
> coprime to 97. No group size is a multiple of 97.** Moreover, since 97 >
> max group size, the stride hits **at most one entry per group**: no two
> samples fall in the same group, so no "fixed offset within a group" blind
> spot can exist. T215's coprimality concern is **discharged for this
> artifact**.

For baselining, the important consequence is simpler and independent of the
coprimality math: the sample is *deterministic* (stride 97 from entry 0, no
randomness), so A5's result is a pure function of the artifact bytes. Exact
equality is the correct comparison regardless of what the sample covers.
Coprimality would only matter if the stride were random or the sample were
re-seeded per run — it is not.

---

## 3. The gate

### 3.1 Fast path — in `zig build test` (like `regression-precommit.sh`)

`build.zig` wires `tools/regression-battery-baselines.sh` into the test step.
The script receives the freshly-built `verify-battery` binary via
`addArtifactArg` (a compile dependency, so the gate always runs the current
battery) and executes `tools/battery-baseline-compare.py --mode fast`, which:

1. runs the battery under `tools/runner` on the four **git-tracked** artifacts
   (`artifacts/oracle-{2x2,3x2,3x3,4x3}.wzo` — present on every clone),
2. verifies each artifact's SHA-256 against the baseline before comparing,
3. compares every (artifact, check) cell against `baselines.json` under §2's
   tuple,
4. exits non-zero naming every diff; exits 0 when all cells match.

The v1 I7 known-failure and the 4×4s are NOT in the fast path — those cells
live in the baseline (documented characteristics) but the 258 MB artifacts are
host-only (`data/` is gitignored) and the 4×4 I4/I5/I7 cells are battery
errors anyway. The suite's job is the deterministic every-clone gate.

**Wall-clock added: 3.3 s** (suite 30.1 s → 33.4 s, measured 2026-08-03 under
`tools/runner -- zig build test`). The dominant cost is I5's 4×3 Tarjan
(~544 MB peak, ~1 s). A suite nobody waits for gets bypassed; 33 s is
well inside the existing budget.

### 3.2 Slow path — `zig build battery-sweep` (explicit step, never in the suite)

Covers the three `data/` 4×4 WZO1 artifacts and `0c3366f0` (WZO2 via
`oracle-v2-accept`, built as a proper artifact in build.zig). Same comparison
tuple, same exit discipline. Host-only artifacts absent on a fresh clone
**SKIP loudly** (named in the output; exit 0). Sequential by construction:
one script, one artifact at a time, every invocation under `tools/runner`
(GRAND-AUDIT §3 — the runner's cap is per-PID; nothing sums).

Measured wall-clock: ~18 s for the full sweep (WZO2 acceptance dominates:
eight per-check reads of the 518 MB file).

### 3.3 Demonstrated red, then restored (the bar)

1. Perturbed `baselines.json` by hand: 2×2 I2 denominator 57 → 58.
   Gate output: `DIFF I2: denominator: baseline=58 actual=57` →
   `BASELINE COMPARISON: FAIL (1 diff(s))`, exit 1.
2. Restored. Gate output: `BASELINE COMPARISON: PASS`, exit 0.
3. Perturbed in the other direction (the "repair" signal): flipped 2×2 I7
   baseline status fail → pass. Gate output: `DIFF I7: status:
   baseline='pass' actual='fail'` → FAIL, exit 1. Restored.

The gate is red when the baseline lies, green when it tells the truth, and
sensitive in both directions.

### 3.4 Updating the baseline

A baseline change is a **recorded event**, not a silent edit (same rule as
axiom changes): edit `docs/evidence/BATTERY/baselines.json` *and* this
document's tables, with a dated amendment-log entry (§7), and commit both.
The gate then re-greens on the new truth. The `generated_by` block records the
binary stamp and commands of the recording session so a later reader can
reproduce it.

---

## 4. Known-failing baselines (characteristics, not new findings)

The following are the *intended* recorded failures — the baseline exists so
that a *change* to any of them is the signal:

- **v1 4×4 I2: fail 11,658,047 / 24,318,165 (47.9%).** This **reproduces the
  register's PROVEN `4x4.V1-INVSYM-BROKEN`** (T260) exactly — a golden-master
  success. Note the pass1 spec §7 baseline table says v1's "I3, I2, I12 pass";
  that row is **wrong** — the battery's reading and the register agree on
  fail (finding F1).
- **I7 fail on all four PSK artifacts** (2×2 8/114, 3×2 52/978, 3×3 822/25,350,
  4×3 9,766/643,378). This is a **battery predicate mismatch**, not an artifact
  defect (finding F2): the battery's `isTerminal` = "no legal placement move",
  while the solver's DTT semantics terminate on **two consecutive passes**
  (`passes==2`); a no-placement state with pass available is not terminal and
  legitimately carries DTT=255 (`DTT_FAR`). The flagged slots are exactly the
  no-placement states with DTT_FAR.
- **I9 fail at 2×2 (root +1 vs anchor 0) and the two PSK checkpoints (root +2,
  UNDEF, vs anchor +1).** The battery's anchor table is ruleset-blind —
  hardcoded basic-ko anchors applied to PSK artifacts (finding F3). 3×2 and
  3×3 PSK roots (0, +9) coincide with the anchors and pass. The parallel
  checkpoint's root slot is **UNDEF** (empty goban not stored).
- **I6 fail at the parallel checkpoint: 24,312,854 stored-legal vs 24,318,165
  header/OEIS — a deficit of 5,311 positions.** The parallel checkpoint's
  stored columns and its own header disagree (finding F5). It is one of the
  unhashed PSK-lineage checkpoints the register already distrusts; the battery
  now quantifies why.
- **DTT uniformly 255 in ALL THREE 4×4 artifacts** (verified directly on the
  raw columns, 43,046,721 slots each) — the `CODE.WZO1-DTT-UNSET` signature.
  pass1 spec §7 documents it for v1 only; the checkpoints share it.

---

## 5. What the gate does NOT check (honest gaps)

- **The 4×4 I4/I5/I7 cells are battery errors** (dispatch stops at 4×3) — no
  Bellman residual, SCC containment or DTT reading exists at 4×4 today
  (finding F4). The "0/99,133,036 Bellman precedent" from pass0 §4 remains
  unimplemented in the battery. The WZO2 acceptance's A2 covers the Bellman
  family on the WZO2 artifact only.
- **I8 is stubbed** (`not-applicable` at every goban): the 24-state
  truncation-gap fixture is "verified externally" per the implementation; the
  gate baselines the stub.
- **I11 is stubbed** (`not-applicable`): the SMD1 dump format does not exist.
- **I3/I10 are `not-applicable` on WZO1** (no bracket columns) — the matrix
  cells exist only for WZO2, where the acceptance A2/A3/A4/A8 are the
  instrument.
- **The 3×3 pin census register target (L==H=68,350) is not reproducible by
  the battery's I1** (16,652/25,350 legal slots): the register counts
  reachable states, I1 counts legal slots. Different denominators, both
  recorded; no gate attaches to the register figure (reference-noted).

---

## 6. Findings

| # | finding | status |
|---|---|---|
| F1 | pass1 spec §7's v1 row says "I2 passes"; the battery reads I2 **fail 11,658,047/24,318,165**, exactly reproducing `4x4.V1-INVSYM-BROKEN:PROVEN` (T260). The spec's §7 baseline table is wrong and should be corrected by the spec owner (T290) | spec bug |
| F2 | Battery I7 terminal predicate ("no legal placement") mismatches the solver's pass-based termination (`passes==2`); the four PSK artifacts' I7 failures (8/52/822/9,766) are predicate artifacts, not DTT defects. The v1 4×4 DTT-unset (uniform 255) is real but **unreachable by the battery** — I7 errors at 4×4 | battery bug |
| F3 | I9's anchor table is ruleset-blind (basic-ko anchors applied to PSK artifacts); the 4×4 anchor should be keyed by rules_id (PSK 4×4 root is +2; basic-ko +1 per T274) | battery bug |
| F4 | `vb_fixpoint.checkI4/checkI7` and `vb_graph.checkI5` dispatch stops at 4×3 — no 4×4 case. The 4×4 matrix cells error (battery-bad), so pass0's "0/99,133,036 Bellman standing check" does not exist in the battery | battery gap |
| F5 | Parallel checkpoint: stored legal 24,312,854 vs header 24,318,165 (deficit 5,311) — the first quantified structural inconsistency in the unhashed checkpoints | artifact |
| F6 | `oracle-v2-accept` all-checks mode corrupts stdout (per-check lines truncated/lost); per-check invocations are clean. A pre-existing T182 bug, worked around by the sweep running checks individually | tool bug |
| F7 | `verify_battery.writeResult` hardcoded `"value":null` and `"deviation":null` — denominators were silently dropped from the JSONL. Fixed in this task (value/seed/sample/deviation now emitted) — without it, "record every check's result with its denominator" was impossible | fixed here |
| F8 | Harness exit codes predate T290 spec §6's refinement: the harness uses 1=artifact-bad, 2=reference-bad, 3=battery-bad; the spec says 2=battery-bad, 3=reference-bad, 4=measurement-only. Left unchanged (consumers may depend on the current values); the JSON `exit_class` field is the authoritative machine channel | noted |
| F9 | The suite's `failed command:` test-step echoes are a known zig 0.16 build-runner quirk (T289 recorded: not failures, each exits 0; suite exit 0) — reconfirmed at 6 echoes, exit 0 | non-issue |
| F10 | Brief's premise "v1 4×4 fails I7 today" is not what the battery delivers: it **errors** (unsupported goban at 4×4). The DTT-unset characteristic is recorded directly (raw-column check, uniform 255) | brief vs reality |

---

## 7. Amendment log

| date | amendment | by |
|---|---|---|
| 2026-08-04 | Initial baseline — T292 (all seven WZO1 artifacts + WZO2 `0c3366f0`) | T292 |
| 2026-08-03 | T309: added A2/A5/A8 exhaustive baseline rows (stride=1, all 99,133,036 entries); all PASS; peak RSS 866 MB; wall clocks A5 0.18s, A2 50.6s, A8 55.9s. Fixed record defects (hash field renames, date corrections). | T309 |
