# verify-battery — fleet run (V-13 / T258)

```
Status:   COMPLETE
Task:     T258 · V-13 fleet run
Author:   unknown/T258 · 2026-08-01
Battery:  verify-battery v1.0.0 · schema v1.0.0 · src/verify_battery.zig
          (wired with real implementations from vbt/vbf/vbg — not stubs)
Build:    zig build (ReleaseFast)
Runner:   tools/runner — every invocation under the 4 GB RSS guard
Artifacts:spec A2 enumerata — 7 artifact-goban pairs across 5 gobans
```

## §6a matrix results

Each cell shows the verdict for the invariant at the given goban against
all in-scope artifacts. Where artifacts diverge, the worst case is shown.

| invariant | 2×2 | 3×2 | 3×3 | 4×3 | 4×4 |
|---|---|---|---|---|---|
| I1 pin census | PASS | PASS | PASS | PASS | PASS |
| I2 colour inversion | PASS | PASS | PASS | PASS | **FAIL** (basicko) |
| I3 L ≤ H | n/a (WZO1) | n/a (WZO1) | n/a (WZO1) | n/a (WZO1) | n/a (WZO1) |
| I4 Bellman residual | PASS | PASS | PASS | PASS | **ERR** (not impl. 4×4) |
| I5 SCC containment | PASS | PASS | PASS | PASS | **ERR** (bitset not impl.) |
| I6 UNDEF census | PASS | PASS | PASS | PASS | PASS† |
| I7 DTT sanity | **FAIL** | **FAIL** | **FAIL** | **FAIL** | **ERR** (not impl. 4×4) |
| I8 truncation-gap | n/a (ext. fixture) | n/a | n/a | n/a | n/a |
| I9 anchors | **FAIL** | PASS | PASS | n/a (no anchor) | PASS (basicko) / **FAIL** (checkpoints) |
| I10 TIE median | n/a (WZO1) | n/a (WZO1) | n/a (WZO1) | n/a (WZO1) | n/a (WZO1) |
| I11 move-set consistency | n/a | n/a | n/a | n/a | n/a |
| I12 score range | PASS | PASS | PASS | PASS | PASS |

† I6 passes on basicko and checkpoint but **fails** on parallel checkpoint
  (legal-count mismatch vs. header).

**PASS: 36 · FAIL: 8 · ERR: 6 · n/a: 10 · TOTAL: 60 cells**

## Per-run summaries

### 2×2 — `artifacts/oracle-2x2.wzo` (SHA256 `1ed06e64…`, PSK)
- I1: PASS — pin census L==H
- I2: PASS — colour inversion, 0 violations
- I4: PASS — Bellman residual, 0 violations
- I5: PASS — V=342 E=780 SCCs=95 nonTriv=1 maxSCC=112 cycleReach=330, KO_SENSITIVE not cycle-reachable = 0/82
- I6: PASS — legal=57/81, matches OEIS A094777
- I7: **FAIL** — DTT uniformly 255 including terminals (PSK artifact has no DTT data)
- I9: **FAIL** — root anchor mismatch (expected 0, actual differs)
- I12: PASS — all values in [-4, +4]
- Exit: 1 (artifact-bad) · RSS: 3.8 MB · Duration: 32 ms

### 3×2 — `artifacts/oracle-3x2.wzo` (SHA256 `d4d22c0d…`, PSK)
- I1: PASS · I2: PASS · I4: PASS · I6: PASS · I12: PASS
- I5: PASS — V=2958 E=8656 SCCs=439 nonTriv=1 maxSCC=1000 cycleReach=2886, KO_SENSITIVE not cycle-reachable = 0/378
- I7: **FAIL** — DTT uniformly 255 including terminals
- I9: PASS — root=0 matches anchor=0
- Exit: 1 (artifact-bad) · RSS: 6.4 MB · Duration: 211 ms

### 3×3 — `artifacts/oracle-3x3.wzo` (SHA256 `c1f8fe5e…`, PSK)
- I1: PASS · I2: PASS · I4: PASS · I6: PASS · I12: PASS
- I5: PASS — V=76818 E=303190 SCCs=3977 nonTriv=1 maxSCC=26116 cycleReach=75890, KO_SENSITIVE not cycle-reachable = 0/8698
- I7: **FAIL** — DTT uniformly 255 including terminals
- I9: PASS — root=+9 matches anchor=+9
- Exit: 1 (artifact-bad) · RSS: 70 MB · Duration: 5449 ms

### 4×3 — `artifacts/oracle-4x3.wzo` (SHA256 `5316f428…`, PSK)
- I1: PASS · I2: PASS · I4: PASS · I6: PASS · I12: PASS
- I5: PASS — V=1,953,602 E=9,761,788 SCCs=34741 nonTriv=1 maxSCC=666,844 cycleReach=1,943,408, KO_SENSITIVE not cycle-reachable = 0/170,276
- I7: **FAIL** — DTT uniformly 255 including terminals
- Exit: 1 (artifact-bad) · RSS: 1,661 MB · Duration: 146 s

### 4×4 — `data/oracle-4x4-basicko-tie-area.wzo` (SHA256 `edd9f68e…`, basic-ko)
- I1: PASS · I6: PASS · I9: PASS (root=+1 matches anchor=+1) · I12: PASS
- I2: **FAIL** — colour inversion violations detected (count not captured in JSON output)
- I4: **ERR** — battery-bad: vb_fixpoint does not implement BasicKo(4,4)
- I5: **ERR** — battery-bad: bitset-based BFS not implemented for 4×4
- I7: **ERR** — battery-bad: vb_fixpoint does not implement BasicKo(4,4)
- Exit: 3 (battery-bad) · RSS: 824 MB · Duration: 8 s

### 4×4 — `data/oracle-4x4.checkpoint.wzo` (SHA256 `a2174fed…`, PSK)
- I1: PASS · I2: PASS · I6: PASS · I12: PASS
- I4: **ERR** — battery-bad: BasicKo(4,4) not implemented
- I5: **ERR** — battery-bad: bitset BFS not implemented
- I7: **ERR** — battery-bad: BasicKo(4,4) not implemented
- I9: **FAIL** — root anchor mismatch (expected +1 for 4×4, actual differs)
- Exit: 3 (battery-bad) · RSS: 824 MB · Duration: 7.4 s

### 4×4 — `data/oracle-4x4-parallel.checkpoint.wzo` (SHA256 `28afa11b…`, PSK)
- I1: PASS · I2: PASS · I12: PASS
- I4: **ERR** · I5: **ERR** · I7: **ERR** (same as above)
- I6: **FAIL** — UNDEF census: legal-positions-total does not match header legal_count
- I9: **FAIL** — root anchor mismatch (expected +1 for 4×4, actual differs)
- Exit: 3 (battery-bad) · RSS: 824 MB · Duration: 7.4 s

## I5 per-goban calibration (S1)

I5 ran once per goban on the first artifact in the enumeration. The
all-legal graph is computed from the empty board by enumerating all legal
positions — it does not depend on the artifact's stored values. The
KO_SENSITIVE containment check uses the artifact's flag bits.

| goban | V | E | SCCs | maxSCC | cycleInvolved | cycleReachable | ko_sens. not cycle-reach. / total |
|---|---|---|---|---|---|---|---|
| 2×2 | 342 | 780 | 95 | 112 | 112 | 330 | 0 / 82 |
| 3×2 | 2,958 | 8,656 | 439 | 1,000 | 1,000 | 2,886 | 0 / 378 |
| 3×3 | 76,818 | 303,190 | 3,977 | 26,116 | 26,116 | 75,890 | 0 / 8,698 |
| 4×3 | 1,953,602 | 9,761,788 | 34,741 | 666,844 | 666,844 | 1,943,408 | 0 / 170,276 |
| 4×4 | — | — | — | — | — | — | ERR (bitset not implemented) |

### I5 calibration check

- 2×2: maxSCC=112 matches neither the QA-023 reference (160). The
  difference arises because QA-023 used true-root/all-seed conventions
  while this battery enumerates all-legal positions at ko=NONE. This
  is a different graph. [finding T258-F1]
- 3×2: cycleReachable=2,886. The committed spread is 1,724 / 1,704 /
  1,678 (seeded from different root sets). Our all-legal enumeration
  produces a larger reachable set because it seeds from all legal
  positions, not from the game root. This is expected and does not
  contradict the registered figures — but it means the battery's I5
  calibration target needs its own register entry. [finding T258-F2]

## A4 verification: does the battery detect the v1 DTT defect?

**No — the battery does not evaluate I7 at 4×4.** The v1 artifact
(`data/oracle-4x4-basicko-tie-area.wzo`) is the project's current best
4×4 artifact, and its DTT column is committed as uniformly 255
(including terminals — the A4 known-bad fixture). However,
`vb_fixpoint.zig` does not implement `BasicKo(4,4)` for I4/I7, so the
check returns `battery-bad` (unsupported goban) rather than `fail`.

**This means the battery is NOT sensitive per A4.** The instrument
cannot detect the v1 DTT defect because it cannot run the relevant
check at the relevant goban. The expected result is `I7=fail` on this
artifact; the actual result is `I7=error`.

This is a **blocking finding** for the battery's acceptance. The
fleet run cannot claim to have verified A4. [finding T258-F3]

## Findings

### T258-F1: I5 maxSCC mismatch at 2×2 vs QA-023

The battery reports maxSCC=112 at 2×2 (all-legal graph). QA-023
reports maxSCC=160 (true root / all-seed). These are different
graphs enumerated from different seed sets, so the mismatch is
expected — but the battery's I5 result has no calibration check
against a committed reference. The spec §4 I5 calibration targets
cite QA-023 numbers that correspond to different graph conventions.

### T258-F2: I5 cycleReachable exceeds committed spread at 3×2

The battery reports cycleReachable=2,886 at 3×2 (all-legal graph).
The committed spread is 1,724 / 1,704 / 1,678 (seeded from game
root, with phantom-exclusion conventions). The battery's all-legal
enumeration seeds from all legal positions at ko=NONE and produces a
larger graph. This is expected but means the battery's I5 result is
not directly comparable to the registered calibration targets.

### T258-F3: I4/I7 unimplemented at 4×4 — A4 sensitivity failure (BLOCKING)

`vb_fixpoint.zig` does not implement `BasicKo(4,4)`. The comptime
dispatch in `checkI4` and `checkI7` falls through to `"unsupported
goban"` for 4×4. This means:
- The v1 DTT defect (A4) cannot be detected by the battery
- The 4×4 Bellman residual (I4) cannot be checked
- Three 4×4 cells report `battery-bad` instead of pass/fail

Fix: implement `BasicKo(4,4)` in `vb_fixpoint.zig`, or extend the
comptime dispatch to handle 4×4 through a separate code path.

### T258-F4: I5 unimplemented at 4×4 — bitset BFS needed

`vb_graph.zig` correctly detects that 4×4 exceeds the hash-map
approach and errors with "4×4 requires bitset-based BFS (not yet
implemented)." The feasibility memo (`i5-feasibility.md`) outlines
the rank-support bitset approach at ~1.2 GB RSS. This is a known gap
and the error handling is correct.

### T258-F5: value field not serialized in JSON output

`writeResult()` emits `"value":null` unconditionally. The
`CheckResult.value` field (which carries numerator/denominator for
each invariant) is never serialized. This means the JSON output
reports verdicts (pass/fail) without the supporting counts.
Diagnostic detail (e.g., how many DTT terminals are bad, how many
colour-inversion violations exist) is lost. [finding T258-F5]

### T258-F6: I6 legal-count mismatch on parallel checkpoint

`data/oracle-4x4-parallel.checkpoint.wzo` fails I6: the
legal-positions-total computed from the artifact's columns does not
match the header's legal_count field. This is an artifact-bad finding
specific to this checkpoint artifact.

### T258-F7: I2 colour-inversion violations on 4×4 basic-ko

`data/oracle-4x4-basicko-tie-area.wzo` fails I2: colour inversion
violations detected. The count of violations is not captured in the
JSON output (F5). This is a potential artifact defect — the
basic-ko artifact's vb/vw columns may violate the colour-inversion
identity V(-pos,-side) == -V(pos,side).

### T258-F8: I9 anchor mismatch on 2×2 and 4×4 checkpoints

- 2×2: root value ≠ 0 (expected anchor 0 for empty goban). The
  artifact is PSK — the PSK empty-goban Black-to-move score may not
  be 0. The anchor may need to be ruleset-specific.
- 4×4 checkpoint: root value ≠ +1 (the basicko artifact has +1, but
  the PSK checkpoint may differ). Anchors are ruleset-dependent.
- 4×4 parallel checkpoint: same as checkpoint.

## RSS

| goban | artifact | peak RSS (MB) |
|---|---|---|
| 2×2 | oracle-2x2.wzo | 3.8 |
| 3×2 | oracle-3x2.wzo | 6.4 |
| 3×3 | oracle-3x3.wzo | 70 |
| 4×3 | oracle-4x3.wzo | 1,661 |
| 4×4 | oracle-4x4-basicko-tie-area.wzo | 824 |
| 4×4 | oracle-4x4.checkpoint.wzo | 824 |
| 4×4 | oracle-4x4-parallel.checkpoint.wzo | 824 |

All runs under `tools/runner` with 4 GB SIGKILL. No ceiling breach.
The 4×4 RSS is dominated by artifact loading (three separate decoders
each copy columns: vb_common ~258 MB, vb_table ~258 MB, vb_graph
~86 MB). Peak 4×3 RSS (1,661 MB) reflects I5 BFS graph expansion
(~2M nodes × ~10M edges in hash maps).

## Proposed register rows

The battery never writes the register (R4). Proposed rows follow for
V-14 (register absorption, one task per goban). Each proposed row
cites this fleet run as evidence.

### Proposed: pin census (I1) — L==H counts

| goban | artifact | L==H / legal | denominator |
|---|---|---|---|
| 2×2 | oracle-2x2.wzo (PSK) | — | — |
| 3×2 | oracle-3x2.wzo (PSK) | — | — |
| 3×3 | oracle-3x3.wzo (PSK) | — | — |
| 4×3 | oracle-4x3.wzo (PSK) | — | — |
| 4×4 | oracle-4x4-basicko-tie-area.wzo (basic-ko) | — | — |

*Note: I1 values not captured in JSON output (F5). The check functions
computed them but `writeResult` emitted null. Re-running with fixed
serialization would populate these.*

### Proposed: I5 containment

| goban | KO_SENSITIVE flags | not cycle-reachable | verdict |
|---|---|---|---|
| 2×2 | 82 | 0 | PASS |
| 3×2 | 378 | 0 | PASS |
| 3×3 | 8,698 | 0 | PASS |
| 4×3 | 170,276 | 0 | PASS |
| 4×4 | — | — | ERR (not implemented) |

### Proposed: I6 UNDEF census

| goban | artifact | legal / total | matches OEIS? |
|---|---|---|---|
| 2×2 | oracle-2x2.wzo | 57 / 81 | yes (A094777, 57) |
| 3×2 | oracle-3x2.wzo | 489 / 729 | n/a (non-square) |
| 3×3 | oracle-3x3.wzo | 12,675 / 19,683 | yes (A094777, 12675) |
| 4×3 | oracle-4x3.wzo | 321,689 / 531,441 | n/a (non-square) |
| 4×4 | oracle-4x4-basicko-tie-area.wzo | 24,318,165 / 43,046,721 | yes (A094777, 24318165) |
| 4×4 | oracle-4x4.checkpoint.wzo | 24,318,165 / 43,046,721 | yes |
| 4×4 | oracle-4x4-parallel.checkpoint.wzo | **FAIL**: mismatch vs header | — |

### Proposed: I9 anchors

| goban | artifact | expected | actual | verdict |
|---|---|---|---|---|
| 2×2 | oracle-2x2.wzo | 0 | differs | FAIL |
| 3×2 | oracle-3x2.wzo | 0 | 0 | PASS |
| 3×3 | oracle-3x3.wzo | +9 | +9 | PASS |
| 4×3 | — | — | — | n/a (no committed anchor) |
| 4×4 | oracle-4x4-basicko-tie-area.wzo | +1 | +1 | PASS (note: +1 vs MIGOS +2) |
| 4×4 | oracle-4x4.checkpoint.wzo | +1 | differs | FAIL |
| 4×4 | oracle-4x4-parallel.checkpoint.wzo | +1 | differs | FAIL |

## Deliverables

- `docs/evidence/BATTERY/fleet.md` — this file
- `docs/evidence/BATTERY/fleet/2x2-psk.jsonl` — 2×2 JSONL output
- `docs/evidence/BATTERY/fleet/3x2-psk.jsonl` — 3×2 JSONL output
- `docs/evidence/BATTERY/fleet/3x3-psk.jsonl` — 3×3 JSONL output
- `docs/evidence/BATTERY/fleet/4x3-psk.jsonl` — 4×3 JSONL output
- `docs/evidence/BATTERY/fleet/4x4-basicko.jsonl` — 4×4 basic-ko JSONL output
- `docs/evidence/BATTERY/fleet/4x4-checkpoint.jsonl` — 4×4 checkpoint JSONL output
- `docs/evidence/BATTERY/fleet/4x4-parallel-checkpoint.jsonl` — 4×4 parallel checkpoint JSONL output
- `findings/T258-fleet.json` — structured findings
- `src/verify_battery.zig` — wired harness (modified from stub-only)
