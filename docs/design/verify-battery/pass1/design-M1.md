# verify-battery M1 — harness design

```
Author:   DSPro/V-4 · 2026-07-31
Status:   PROPOSED — for pass-1 audit (V-5)
Inputs:   docs/infra/verify-battery/spec.md (rev 1) ·
          docs/infra/verify-battery/strategy.md (rev 1) ·
          docs/design/verify-battery/pass1/spec-audit.md (T137) ·
          docs/design/verify-battery/pass1/i5-feasibility.md (DSPro/T134)
```

## 1. Overview

M1 is the CLI, result schema, and artifact-loading layer. It owns no invariants
but defines the contract every invariant module (V-6–V-9) implements against.
The design binds three things:

1. **CLI contract** — invocation, flags, exit codes (three classes per spec R6).
2. **Result schema** — JSON Lines, one result per (invariant, goban, artifact) cell,
   with denominators, §6a cell coordinates, and proposed-row fields for CLAIMS.md
   absorption.
3. **Artifact loading** — per spec R8 (import nothing from `src/`). Loads WZO1
   artifacts by path with SHA-256 verification; anticipates WZO2 bracket artifacts.

## 2. CLI contract

### 2.1 Invocation

```
verify-battery <goban> <artifact> [flags]
```

| argument | type | description |
|---|---|---|
| `<goban>` | string | Goban size: `2x2`, `3x2`, `3x3`, `4x3`, `4x4` |
| `<artifact>` | path | Path to `.wzo` artifact file. Use `--i5-only` (see below) when no artifact is needed for I5 structural runs. |

### 2.2 Flags

| flag | type | default | description |
|---|---|---|---|
| `--invariants <ids>` | comma-separated list | all twelve | Which invariants to run. E.g. `I1,I2,I3` or `I5`. Any invariant not in the list reports status `skipped`. |
| `--i5-only` | bool | false | Run I5 alone, no artifact required (I5 reads no stored values from the artifact beyond flags, and the all-legal graph needs no artifact at all). Mutually exclusive with `--invariants`; sets `--invariants I5` and skips artifact loading. |
| `--i5-graph <kind>` | string | `all-legal` | Which graph I5 operates on: `reachable` (reachable-from-empty, the true game root) or `all-legal` (every legal position as independent root). Only meaningful with I5. |
| `--output <path>` | path | stdout | Write JSON-Lines results to this file. Default: stdout (data channel). |
| `--proposed-rows <path>` | path | — | Emit proposed CLAIMS.md rows to this file (see §3.4). If absent, no proposed rows are emitted. |
| `--sha256 <hash>` | hex string | — | Verify the artifact's SHA-256 before loading. Mismatch → battery-bad exit. If absent, the artifact is loaded without hash verification; the SHA-256 is computed and reported in every result row regardless. |
| `--seed <N>` | u64 | 0 (auto) | Seed for sampled invariants (I11 and any fallback-sampled runs). 0 = derive from PID + time. |
| `--sample-size <N>` | u64 | per-invariant default | Override sample size for sampled invariants. |
| `--no-fixture` | bool | false | Skip known-bad fixture validation (for production fleet runs). Fixture runs are the default during development. |
| `--help` | — | — | Print usage and exit 0. |

**Mutual exclusion:** `--i5-only` and `--invariants` may not both be specified.
`--i5-only` with `--i5-graph all-legal` needs no artifact; the `<artifact>`
argument may be the empty string `""` in that case.

**I5 vs artifact:** When I5 is run with `--i5-graph all-legal`, the artifact is
not loaded (the graph is constructed from the battery's own rules engine).
When I5 is run with `--i5-graph reachable` or as part of a full battery run,
the artifact IS loaded for its KO_SENSITIVE flags (fb/fw columns only).

### 2.3 Exit codes

Per spec R6, three non-zero exit classes, distinguishable by machine:

| code | class | meaning |
|---|---|---|
| **0** | pass | All requested invariants completed; every result has `exit_class` = `pass` or `skipped`. |
| **1** | artifact-bad | At least one invariant computed cleanly and the artifact violates it. The invariant's `value` object carries the violation details. |
| **2** | reference-bad | At least one invariant computed cleanly and disagrees with a committed register figure. No artifact-bad results are present (artifact-bad takes precedence — see below). The invariant's `value` object carries the expected and actual values. |
| **3** | battery-bad | The harness could not complete: artifact load error, SHA-256 mismatch, OOM, stack overflow, internal assertion failure, or any invariant returned `status: "error"`. Results for invariants that DID complete before the failure are still emitted. |

**Precedence when multiple classes apply:** battery-bad (3) > artifact-bad (1)
> reference-bad (2) > pass (0). If any invariant returned `status: "error"`,
the overall exit is 3. If no errors but at least one `artifact-bad`, exit 1.
If only `reference-bad` results (and no `artifact-bad`), exit 2. The per-result
`exit_class` field always carries the individual classification regardless of
the overall exit code.

**Rationale for precedence:** battery-bad means the run didn't complete cleanly
— its other results may be incomplete. Artifact-bad means the artifact is
suspect — reference disagreements are irrelevant until the artifact is cleared.
Reference-bad means the artifact looks fine but the register disagrees.

### 2.4 stdout / stderr discipline

Per `AGENTS.md`:

- **stdout** = data: JSON Lines results (one line per cell) or proposed rows.
  `verify-battery 2>/dev/null` must emit parseable data and nothing else.
- **stderr** = diagnostics: progress, warnings, timing, RSS reports. `verify-battery 1>/dev/null` must be silent on a clean run.

The `--output` flag redirects the data stream; stderr is unchanged.

## 3. Result schema

### 3.1 Transport format

**JSON Lines** (NDJSON): one complete JSON object per line, no trailing comma,
`\n` terminated. Each line is self-contained and parseable independently.
Streaming-friendly — the fleet run (V-13) can `tee` to both a file and a
monitoring pipe.

The first line of output is a **header record** (distinguished by
`"kind": "header"`), followed by one **result record** per invariant that ran.
If `--proposed-rows` is set, that file receives a separate stream of
**proposed-row records** (one per cell, not one per invariant — see §3.4).

### 3.2 Header record

Emitted once, first line of stdout (or `--output`). Identifies the run.

```json
{
  "kind": "header",
  "battery_version": "1.0.0",
  "goban": "3x2",
  "artifact": "artifacts/oracle-3x2.wzo",
  "artifact_sha256": "d4d22c0d9f1d771bfcb1d99fc43a4f19f652205113ff599123b189097b3bb523",
  "artifact_total": 729,
  "artifact_legal_count": 289,
  "artifact_rules_id": 1,
  "artifact_rules_name": "Chinese area, komi 0, positional superko",
  "timestamp": "2026-07-31T14:22:00Z",
  "seed": 42,
  "invariants_requested": ["I1","I2","I3","I4","I5","I6","I7","I9","I10","I11","I12"],
  "i5_graph": "all-legal"
}
```

**Field notes:**

- `artifact_sha256`: hex-encoded SHA-256 of the artifact file bytes. Always reported, whether or not `--sha256` was passed — the battery computes it on load regardless.
- `artifact_total`: the `total` field from the artifact header (= 3^(w*h)).
- `artifact_legal_count`: legal positions per side, from artifact header.
- `artifact_rules_id`: 1 = Chinese area PSK, 2 = basicko TIE area (see `src/artifact.zig`).
- `invariants_requested`: the list of invariants actually selected. I8 is absent here (goban=3×2, I8 is n/a per §6a); I5 is present. This reflects the §6a matrix for the goban.
- `i5_graph`: only present when I5 is in `invariants_requested`.
- `seed`: the seed used for any sampled invariants; `null` if none are sampled.

### 3.3 Result record

One per invariant run. Common fields for all invariants:

```json
{
  "kind": "result",
  "invariant": "I1",
  "goban": "3x2",
  "artifact": "artifacts/oracle-3x2.wzo",
  "artifact_sha256": "d4d22c0d...",
  "mode": "exhaustive",
  "status": "pass",
  "exit_class": "pass",
  "duration_ms": 1234,
  "peak_rss_mb": 45.2,
  "seed": null,
  "sample_size": null,
  "sample_denominator": null,
  "value": { ... }
}
```

**Common field types:**

| field | type | description |
|---|---|---|
| `kind` | string | Always `"result"`. |
| `invariant` | string | `I1`–`I12`. |
| `goban` | string | `2x2`, `3x2`, `3x3`, `4x3`, `4x4`. |
| `artifact` | string | Path as given on CLI (even if resolved). `null` for I5 all-legal runs with no artifact. |
| `artifact_sha256` | string\|null | Hex SHA-256, or `null` if no artifact was loaded. |
| `mode` | string | `exhaustive`, `sampled`, `once-per-goban`, or `not-applicable`. Per the §6a matrix. |
| `status` | string | `pass` — invariant holds. `fail` — invariant violated cleanly. `skipped` — invariant not selected. `not_applicable` — invariant doesn't apply to this goban (e.g. I8 at 3×2). `error` — invariant could not complete (resource, internal bug). |
| `exit_class` | string | `pass`, `artifact-bad`, `reference-bad`, `battery-bad`. The per-result classification. |
| `duration_ms` | u64 | Wall-clock duration of this invariant in milliseconds. |
| `peak_rss_mb` | f64 | Peak RSS in MiB during this invariant (A6). `null` if not measured. |
| `seed` | u64\|null | Seed used for this invariant, if sampled; else `null`. |
| `sample_size` | u64\|null | Sample size drawn, if sampled; else `null`. |
| `sample_denominator` | u64\|null | Total population size, if sampled (per R3: within-budget denominator). `null` for exhaustive. |
| `value` | object | Invariant-specific result data (see §3.5). |

**`status` vs `exit_class`:** `status` describes what happened during computation
(pass/fail/skipped/not_applicable/error). `exit_class` classifies the result for
the overall exit-code decision. For `status: "pass"`, `exit_class` is always
`"pass"`. For `status: "fail"`, `exit_class` is either `"artifact-bad"` (the
invariant found a genuine violation) or `"reference-bad"` (the invariant holds,
but disagrees with a committed register figure — the register entry goes to
audit). For `status: "error"`, `exit_class` is `"battery-bad"`.

**`status: "fail"` with `exit_class: "reference-bad"`:** the `value` object must
carry both the battery's computed value and the expected register value so the
auditor can see the disagreement without reading the register. See I1 and I9
value schemas for examples.

### 3.4 Proposed-row format

When `--proposed-rows <path>` is set, the battery writes a JSON Lines file with
one object per (invariant, goban, artifact) cell. This is separate from the
result stream — it is the input V-14 (register absorption) reads.

```json
{
  "kind": "proposed-row",
  "invariant": "I1",
  "goban": "3x2",
  "artifact": "artifacts/oracle-3x2.wzo",
  "artifact_sha256": "d4d22c0d...",
  "status": "pass",
  "claim_text": "I1 pin census at 3×2: L==H=2232 pin_T=322 pin_L=34 pin_H=34 / 2622 reachable states",
  "evidence_path": "docs/evidence/BATTERY/fleet.md",
  "reference_expected": null,
  "reference_actual": null,
  "reference_citation": "docs/epistemic/CLAIMS.md:557",
  "depends_on": ["GLOBAL.FP1", "3x2.C1"],
  "notes": null
}
```

**Field types:**

| field | type | description |
|---|---|---|
| `kind` | string | Always `"proposed-row"`. |
| `invariant` | string | `I1`–`I12`. |
| `goban` | string | `2x2`–`4x4`. |
| `artifact` | string | The artifact path. |
| `artifact_sha256` | string\|null | As in result record. |
| `status` | string | `pass`, `fail`, `skipped`, `not_applicable`, `error`. |
| `claim_text` | string | A human-readable one-liner describing what was tested and the result, suitable for the `claim` column of CLAIMS.md. |
| `evidence_path` | string | Where the evidence lives (always under `docs/evidence/BATTERY/`). |
| `reference_expected` | string\|null | If reference-bad: the committed register value. Else `null`. |
| `reference_actual` | string\|null | If reference-bad: the battery's computed value. Else `null`. |
| `reference_citation` | string\|null | If a register citation exists for this cell: `file:line`. Else `null`. |
| `depends_on` | [string] | CLAIMS.md claim IDs this row's truth depends on (for the `depends-on` column). E.g. `["GLOBAL.FP1", "3x2.C1"]`. |
| `notes` | string\|null | Any caveats, e.g. "I5 disagreement matches the known 1,724/1,704/1,678 spread — reference-bad, not artifact-bad." |

**Proposed-row invariants:** every invariant in the §6a matrix produces a
proposed row, even if `status: "skipped"` or `status: "not_applicable"`. This
lets the register record which cells have been evaluated and which haven't.
For I5 (once per goban), only ONE proposed row is emitted per goban, regardless
of how many artifacts are in scope — the row's `artifact` field contains the
goban-wide scope note (e.g. `"all artifacts, once per goban"`).

### 3.5 Invariant-specific `value` schemas

Every invariant's `value` object has at minimum:

```json
{
  "numerator": 2232,
  "denominator": 2622
}
```

**Per R3:** every reported number states its denominator. The `numerator` and
`denominator` fields are the top-level counts for the invariant. Additional
fields vary.

#### I1 — pin census

```json
{
  "numerator": 2622,
  "denominator": 2622,
  "L_eq_H": 2232,
  "pin_T": 322,
  "pin_L": 34,
  "pin_H": 34,
  "reference": {
    "expected_L_eq_H": 2220,
    "expected_pin_T": 298,
    "expected_pin_L": 34,
    "expected_pin_H": 34,
    "expected_denominator": 2586,
    "citation": "docs/evidence/QA-026/exp4-solve-2026-07-29.stdout:96"
  }
}
```

The `reference` sub-object is present only when a register figure exists for
this goban (3×2 and 3×3 have references; 2×2, 4×3, 4×4 do not). The battery
reports its own figures and the reference separately; the V-14 absorption step
decides reference-bad vs pass.

For 3×2, `status` is `"pass"` when the battery's denominator matches ONE of the
two committed denominators (2,586 or 2,622) and the census figures match that
reference. When the denominator doesn't match either reference, the census
is reported as-is and the V-14 seat flags it for reconciliation (per spec A3).

#### I2 — colour inversion

```json
{
  "numerator": 0,
  "denominator": 2622,
  "violations": 0,
  "violation_examples": []
}
```

`violations`: count of (position, side) pairs where `V(-pos,-side) != -V(pos,side)`,
or for bracket tables `L(-pos,-side) != -H(pos,side)`.
`violation_examples`: up to 5 example indices (colex indices) where violations
occurred; empty on pass.

#### I3 — L ≤ H

```json
{
  "numerator": 0,
  "denominator": 2622,
  "violations": 0,
  "violation_examples": []
}
```

`violations`: count of legal slots where `L > H`.
`violation_examples`: up to 5 colex indices.

#### I4 — Bellman residual

```json
{
  "numerator": 0,
  "denominator": 99133036,
  "L_violations": 0,
  "H_violations": 0,
  "note": "denominator = compact slot count (passes ∈ {0,1})"
}
```

`denominator` is the compact slot count per spec §4 I7 note. At 2×2 this is the
number of reachable (position, side, passes∈{0,1}) triples; at 4×4 it is
99,133,036.

#### I5 — SCC containment

```json
{
  "numerator": 0,
  "denominator": 508,
  "i5_graph": "all-legal",
  "nodes": 282,
  "edges": 508,
  "sccs_total": 123,
  "sccs_non_trivial": 1,
  "max_scc_size": 160,
  "cycle_involved": 160,
  "cycle_reachable": 160,
  "ko_sensitive_flags": 203,
  "ko_sensitive_not_cycle_reachable": 0,
  "calibration": {
    "max_scc_expected": 160,
    "max_scc_citation": "docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py",
    "cycle_reachable_expected": null,
    "cycle_reachable_citation": null
  }
}
```

`numerator`: count of KO_SENSITIVE flags outside the cycle-reachable set
(`ko_sensitive_not_cycle_reachable`). Should be 0.

`denominator`: total KO_SENSITIVE flags checked (or total non-settled slots,
whichever is the relevant population).

`calibration`: always present for I5. Carries the expected values from committed
evidence. If the battery's `max_scc_size` doesn't match `calibration.max_scc_expected`,
the result is `exit_class: "battery-bad"` (the Tarjan implementation is wrong,
not the artifact).

For 3×2 `--i5-graph reachable`, `calibration.cycle_reachable_expected` = 1,678
(true game root convention per spec §4).

**I5 exit_class rules (special):**
- `max_scc_size` mismatch with calibration → `battery-bad` (implementation wrong)
- `ko_sensitive_not_cycle_reachable > 0` at 2×2/3×2 → `artifact-bad`
- `ko_sensitive_not_cycle_reachable > 0` at 3×2 that matches a known spread → `reference-bad` with notes
- `ko_sensitive_not_cycle_reachable > 0` at 4×4 → `artifact-bad` (finding larger than sprint — spec §7)

#### I6 — UNDEF census

```json
{
  "numerator": 24187097,
  "denominator": 99133036,
  "illegal": 24187097,
  "legal_both_sides": 65534,
  "legal_one_side_only": 65534,
  "union_legal": 24318165,
  "oeis_a094777": 24318165,
  "union_matches_oeis": true,
  "note": "denominator = compact slot count"
}
```

#### I7 — DTT sanity

```json
{
  "numerator": 0,
  "denominator": 99133036,
  "terminals_with_dtt_neq_0": 0,
  "non_terminals_with_dtt_255": 99133036,
  "terminals_total": 0,
  "uniform_count": 99133036,
  "uniform_value": 255,
  "note": "defect signature is uniformity including terminals (spec §4 I7). 255 = DTT_FAR sentinel, legitimate on far states; uniform-including-terminals is the defect."
}
```

For the v1 4×4 artifact, `uniform_count` = `denominator`, `terminals_with_dtt_neq_0` > 0,
`non_terminals_with_dtt_255` = all non-terminal slots → `status: "fail"`, `exit_class: "artifact-bad"`.

#### I8 — truncation-gap regression (2×2 only)

```json
{
  "numerator": 0,
  "denominator": 172,
  "mismatches": 0,
  "expected_mismatches": 0,
  "fixture_states": 24,
  "citation": "docs/evidence/QA-026/calibration-2x2-mismatch.py"
}
```

`denominator` = 172 reachable non-terminals at 2×2.
`mismatches`: number of states where loopy-game fixpoint and exact first-revisit
truncation disagree. Expected = 0 (agreement fixture per T102/T103).

At gobans other than 2×2: `mode: "not_applicable"`, `status: "not_applicable"`,
`value: null`.

#### I9 — anchors

```json
{
  "expected_root": 0,
  "actual_root": 0,
  "match": true,
  "reference_citation": "docs/research/newrule-3x3-2026-07-28.md:74",
  "note": null
}
```

For 4×3: `expected_root: null`, `match: null`, `note: "no committed anchor for 4×3 — spec §4 I9"`.
For 4×4: `expected_root: 1`, `note: "+1 vs MIGOS +2 — open discrepancy (spec §4 I9)"`.
`status: "pass"` when `match: true` or when no reference exists.

#### I10 — TIE median

```json
{
  "numerator": 0,
  "denominator": 2622,
  "violations": 0,
  "tie_below_L": 0,
  "tie_above_H": 0,
  "tie_not_median": 0,
  "violation_examples": []
}
```

`violations` = `tie_below_L + tie_above_H + tie_not_median`.
`tie_not_median`: TIE ≠ median(L, TIE, H) — i.e. TIE within [L,H] but not the
median — this is the QA-023 failure shape (wrong values, sane histogram).

#### I11 — move-set consistency

```json
{
  "mode": "sampled",
  "numerator": 0,
  "denominator": 2622,
  "sample_size": 500,
  "sample_seed": 42,
  "mismatches": 0,
  "mismatch_examples": [],
  "solver_dump_path": "docs/evidence/BATTERY/move-dump-3x2.wzo",
  "note": "exhaustive at 2×2/3×2; sampled at 3×3+ per §6a"
}
```

`mismatches`: count of sampled states where the battery's legal-move set differs
from the solver engine's legal-move set (via solver-side dump).

#### I12 — score range

```json
{
  "numerator": 0,
  "denominator": 2622,
  "violations": 0,
  "area": 6,
  "out_of_range_low": 0,
  "out_of_range_high": 0,
  "violation_examples": []
}
```

`area` = goban area (w × h). Valid range: [−area, +area].

### 3.6 Error result

When an invariant cannot complete (status: `error`), the `value` object is
replaced by an `error` object:

```json
{
  "kind": "result",
  "invariant": "I5",
  "goban": "4x4",
  "artifact": "data/oracle-4x4-basicko-tie-area.wzo",
  "artifact_sha256": "edd9f68e...",
  "mode": "once-per-goban",
  "status": "error",
  "exit_class": "battery-bad",
  "duration_ms": 45000,
  "peak_rss_mb": 3950.1,
  "seed": null,
  "sample_size": null,
  "sample_denominator": null,
  "error": {
    "kind": "memory_budget",
    "message": "I5: SKIPPED — memory budget exceeded (predicted 4.2 GB > 4.0 GB cap), sample-only fallback triggered",
    "predicted_rss_mb": 4200.0,
    "fallback_tier": "F3"
  }
}
```

**Error kinds:**

| `error.kind` | meaning |
|---|---|
| `memory_budget` | Predicted allocation exceeds 4 GB cap (per R7). |
| `stack_overflow` | Tarjan frame stack exceeded depth bound. |
| `oom` | allocator returned OutOfMemory. |
| `artifact_load` | Artifact file missing, truncated, bad magic, bad checksum, or SHA-256 mismatch. |
| `internal` | Assertion failure or unexpected state. |

## 4. Artifact loading

### 4.1 R8 compliance

Per spec R8, the battery imports **nothing from `src/`**. The artifact loader,
colex/addressing (`rank_from_pos` / `pos_from_rank`), and basic-ko rules engine
are re-implemented in the battery's own source tree. This is the costliest
decision in the sprint (flagged for human at G1).

The battery's re-implemented subsystems:

| subsystem | lines (est.) | re-implements |
|---|---|---|
| Artifact loader | ~200 | WZO1 header parsing, CRC-32 verification, column extraction (replaces `src/artifact.zig`) |
| Colex addressing | ~100 | `rank_from_pos`, `pos_from_rank`, the colex mixed-radix bijection (replaces `src/colex.zig`) |
| Basic-ko rules engine | ~300 | Legal-move generation: empty-cell check, ko-forbidden check, suicide check, pass, terminal detection (replaces `src/rules.zig`) |

**Total: ~600 lines** against an estimated ~2,000-line battery (≈30%, not
"triples" — see spec audit S1). This estimate does not include the invariant
implementations themselves (V-7 through V-9).

The battery's loader MUST produce identical results to `src/artifact.zig`'s
`decode()` on every in-scope artifact. Verification: round-trip the header
fields and column byte arrays against the reference loader in V-10
(calibration).

### 4.2 WZO1 format (re-specified for the battery)

The battery re-implements the WZO1 format from the spec in `src/artifact.zig`
(lines 1–85). This section is the **battery's independent specification** of
that format — no text is copied from `src/artifact.zig`.

**Header** (32 bytes, little-endian):

| offset | size | field | description |
|---|---|---|---|
| 0 | 4 | magic | ASCII `WZO1` |
| 4 | 1 | format_version | `1` |
| 5 | 1 | colex_layout | colex layout version (`1`) |
| 6 | 1 | board_w | goban width |
| 7 | 1 | board_h | goban height |
| 8 | 1 | value_semantics | `1` = fresh-start (ADR-0008) |
| 9 | 1 | rules_id | `1` = Chinese area, komi 0, positional superko; `2` = Chinese area, komi 0, basic ko, TIE=0 on cycles (ADR-0020) |
| 10 | 1 | column_count | `6` |
| 11 | 1 | reserved | `0` |
| 12 | 8 | total | u64 LE, = 3^(board_w × board_h) |
| 20 | 8 | legal_count | u64 LE, legal positions per side (provenance/sanity) |
| 28 | 4 | payload_crc32 | u32 LE, CRC-32 (ISO-HDLC) of the entire payload |

**Payload** (6 × `total` bytes, concatenated):

| segment | offset | type | description |
|---|---|---|---|
| vb | 0 × total | i8[] | Value, Black to move (Black-positive; `-128` = illegal/undef) |
| vw | 1 × total | i8[] | Value, White to move (Black-positive; `-128` = undef) |
| fb | 2 × total | u8[] | Flags, Black to move (bit0 = KO_SENSITIVE, bit1 = FROM_FORWARD) |
| fw | 3 × total | u8[] | Flags, White to move |
| db | 4 × total | u8[] | DTT, Black to move (fastest optimal resolution depth; 255 = DTT_FAR) |
| dw | 5 × total | u8[] | DTT, White to move |

**Layout semantics:** Each column array is indexed by the colex mixed-radix
address of a position (Black/White is the side-to-move, not a colour of the
stones). `total` = 3^(w×h) covers every 3-colour assignment, including illegal
positions. A position is legal for side S iff `vS[idx] != -128`. The `legal_count`
field in the header records how many colex indices are legal for a given side
(same count for both sides, by symmetry).

**Flag bits:**

| bit | name | meaning |
|---|---|---|
| 0 | KO_SENSITIVE | The stored value is in the ko-sensitive region: its fresh-start value depends on cycle-resolution policy. Set by the retrograde engine; verified by the finisher. |
| 1 | FROM_FORWARD | The stored value was produced by the forward finisher (not the retrograde fixpoint). |

**DTT sentinel:** `255` = `DTT_FAR` — the state is unreachable from any terminal,
or its distance is unknown. Legitimate on far states. The I7 invariant's defect
signature is *uniformity including terminals*, not the value 255 itself.

**CRC-32:** ISO-HDLC polynomial (`0xEDB88320`), computed over the entire payload
(bytes 32..end). The battery uses Zig's `std.hash.crc.Crc32IsoHdlc`.

### 4.3 Load procedure

```
1. Read file bytes into memory.
2. If --sha256 <hash>: compute SHA-256, compare. Mismatch → battery-bad.
3. Report SHA-256 in header record regardless.
4. Verify magic "WZO1".
5. Verify format_version == 1.
6. Verify colex_layout == 1.
7. Verify value_semantics == 1 (fresh-start).
8. Accept rules_id ∈ {1, 2}.
9. Verify column_count == 6.
10. Verify total == 3^(board_w × board_h).
11. Verify file size == 32 + 6 × total.
12. Compute CRC-32 of payload, verify against header.
13. Allocate six column arrays (vb, vw, fb, fw, db, dw), each total bytes.
14. Copy payload segments into column arrays.
```

**Memory budget for loading:**

| goban | total | bytes per column | total payload | file size |
|---|---|---|---|---|
| 2×2 | 81 | 81 B | 486 B | 518 B |
| 3×2 | 729 | 729 B | 4,374 B | 4,406 B |
| 3×3 | 19,683 | ~19 KB | ~115 KB | ~115 KB |
| 4×3 | 531,441 | ~519 KB | ~3.0 MB | ~3.0 MB |
| 4×4 | 43,046,721 | ~41 MB | ~246 MB | ~246 MB |

At 4×4, loading allocates 6 × 41 MB = 246 MB. This is within the 4 GB runner
cap with >3.7 GB headroom for invariant computation. The loader itself is
not the bottleneck; I5 and I4 at 4×4 dominate RSS.

### 4.4 WZO2 (bracket) anticipation

The battery's artifact loader MUST NOT crash on a future WZO2 artifact. It
recognises the magic `WZO2` and reports a clean error:

```json
{
  "kind": "result",
  "invariant": "I1",
  ...
  "status": "error",
  "exit_class": "battery-bad",
  "error": {
    "kind": "artifact_load",
    "message": "WZO2 bracket artifacts not yet supported — verify-battery v1.0.0 loads WZO1 only. oracle-v2 bracket artifacts require a battery update.",
    "artifact_magic": "WZO2"
  }
}
```

The battery does NOT attempt to parse WZO2. The schema anticipates bracket
columns (L/H pairs per side) but the loader does not implement them yet. This
is a deliberate scope boundary — WZO2 support is added when oracle-v2 ships.

### 4.5 Artifact load errors

All load errors produce `status: "error"`, `exit_class: "battery-bad"`, exit
code 3. The `error` object carries:

| condition | `error.kind` | `error.message` |
|---|---|---|
| File not found | `artifact_load` | Artifact file not found: `<path>` |
| Bad magic | `artifact_load` | Bad magic: expected WZO1, got `<bytes>` |
| Bad version | `artifact_load` | Unsupported format version: `<n>` |
| Bad layout | `artifact_load` | Unsupported colex layout: `<n>` |
| Bad semantics | `artifact_load` | Unsupported value semantics: `<n>` |
| Bad total | `artifact_load` | Total mismatch: `<n>` != 3^`<cells>` |
| Truncated | `artifact_load` | Truncated: expected `<expected>` bytes, got `<actual>` |
| Bad checksum | `artifact_load` | CRC-32 mismatch: stored `<stored>`, computed `<computed>` |
| SHA-256 mismatch | `artifact_load` | SHA-256 mismatch: expected `<expected>`, got `<actual>` |
| OOM during load | `oom` | Out of memory loading artifact |

When an artifact load error occurs before any invariants run, the battery emits
only the header record (with `artifact_sha256` if computed) and the error result,
then exits 3.

## 5. Goban size parameterisation

The goban size argument `2x2`–`4x4` is parsed at startup and drives:

1. **Colex dimensions:** `w × h` for `rank_from_pos` / `pos_from_rank`.
2. **Total address space:** `total = 3^(w×h)` — validates against artifact header.
3. **§6a matrix:** which invariants are applicable, and which mode (E/S/G/n/a).
4. **I5 graph size:** node count varies; all-legal = OEIS A094777 × 2 (both sides).
5. **I11 sampling threshold:** exhaustive at 2×2/3×2; sampled at ≥3×3.
6. **I8 applicability:** 2×2 only.

The harness resolves invariants for a goban by consulting the §6a matrix at
startup. Invariants not applicable to the goban (I8 at 3×2+, I9 at 4×3 where
no anchor is committed) report `status: "not_applicable"` and do not run.

## 6. Invariant dispatch

### 6.1 Invariant interface

Each invariant module (V-7 through V-9) exports a single function:

```zig
pub fn check(
    gpa: Allocator,
    goban: GobanSize,
    cols: *const ArtifactColumns,
    opts: CheckOptions,
) CheckResult;
```

Where:

- `GobanSize` is `struct { w: u8, h: u8 }`.
- `ArtifactColumns` is the loaded artifact (or `null` for I5 all-legal).
- `CheckOptions` carries `seed: ?u64`, `sample_size: ?u64`, `i5_graph: ?I5Graph`, and `fixture_mode: bool`.
- `CheckResult` is the invariant-specific result (see §3.3).

The harness iterates over selected invariants, calls each, collects results,
and writes the JSON Lines stream. The harness owns exit-code aggregation.

### 6.2 Invariant-to-module mapping

| invariants | module | file |
|---|---|---|
| I1, I2, I3, I6, I10, I12 | M2 (table invariants) | `src/vb_table.zig` |
| I4, I7, I8, I9, I11 | M3 (fixpoint invariants) | `src/vb_fixpoint.zig` |
| I5 | M4 (graph invariant) | `src/vb_graph.zig` |

The harness itself is `src/verify_battery.zig`. All four files are new; none
imports from `src/` (spec R8). Shared utilities (colex, rules engine, artifact
loader, JSON writer) live in `src/vb_common.zig` or are inlined per module.

### 6.3 I5 special handling

I5 is the only invariant that can run without an artifact (`--i5-graph all-legal`
with `--i5-only`). When I5 runs with an artifact, it reads only the `fb`/`fw`
columns (KO_SENSITIVE flags), not the value columns.

When invoked as `--i5-only --i5-graph all-legal`, the harness skips artifact
loading entirely. The header record has `artifact: null`, `artifact_sha256: null`.

## 7. RSS measurement

Per spec A6, the battery reports peak RSS per invocation. The harness samples
RSS before and after each invariant and records the peak in `peak_rss_mb`.

On Linux: read `/proc/self/status` VmRSS field.
On macOS: `task_info` with `MACH_TASK_BASIC_INFO` → `resident_size`.

If RSS measurement fails (non-Linux, non-macOS, or permission denied),
`peak_rss_mb` is `null` — this is not an error.

The battery should also **predict** its allocation before I5 Phase 3 (per
i5-feasibility.md §5.2) and refuse to start if the prediction exceeds the
available headroom. The prediction is reported in the I5 result's `error` object
if the check triggers a fallback.

## 8. Concurrency notes

Per spec R7, the battery does not self-throttle. It is the Orchestrator's
responsibility (with human backstop) to ensure at most two 4×4-scale invocations
are in flight project-wide. The battery runs single-threaded per invocation;
concurrency across gobans and artifacts is achieved by running multiple
`verify-battery` processes, not by internal threading.

## 9. Error handling summary

| scenario | exit code | exit_class | emitted |
|---|---|---|---|
| All invariants pass | 0 | pass | header + result records |
| One invariant fails (artifact-bad) | 1 | artifact-bad | header + result records (passing ones too) |
| One invariant disagrees with register (reference-bad), none artifact-bad | 2 | reference-bad | header + result records |
| Artifact fails to load | 3 | battery-bad | header record + error result |
| SHA-256 mismatch | 3 | battery-bad | header record (with computed SHA-256) + error result |
| OOM during invariant | 3 | battery-bad | header + results for completed invariants + error result for failed one |
| Invalid goban size | 3 | battery-bad | header record + error result |
| Unknown flag | 3 | battery-bad | header record + error result |

**Partial results:** When the battery encounters a fatal error partway through
(battery-bad), it emits results for all invariants that completed before the
failure, then the error result, then exits 3. The consumer (V-13 fleet runner)
should treat any invocation with exit 3 as incomplete — green cells from that
run are not promotable until a clean re-run.

## 10. Proposed-row emission rules

1. `--proposed-rows <path>` is a separate file, not interleaved with stdout.
2. One row per (invariant, goban) cell from the §6a matrix — even if `status` is
   `skipped` or `not_applicable`. This records which cells have been evaluated.
3. Rows are written after all invariants complete (not streamed). This avoids
   partial rows on error.
4. Each row carries `evidence_path: "docs/evidence/BATTERY/fleet.md"` — the
   fleet run's aggregate evidence file. V-13 is responsible for writing that
   file; the proposed rows are its input.
5. Rows for I5 are emitted once per goban (S1), not once per artifact. The
   `artifact` field carries the goban-wide scope note.

## 11. Implementation notes

### 11.1 JSON writing

The battery must not depend on `std.json` for writing — `std.json.stringify`
allocates. Use a minimal hand-rolled JSON writer that writes directly to the
output file descriptor. The schema is flat enough (no nested arrays of
unbounded size) to make this straightforward.

### 11.2 SHA-256

Uses `std.crypto.hash.sha2.Sha256`. The digest is computed while streaming the
file into memory (single pass), avoiding a second read.

### 11.3 Build

`zig build` — the battery is a standalone executable. It does not link against
any solver object files. The build.zig entry is:

```zig
const vb = b.addExecutable(.{
    .name = "verify-battery",
    .root_source_file = b.path("src/verify_battery.zig"),
    .target = target,
    .optimize = optimize,
});
```

### 11.4 Test

`zig test src/verify_battery.zig` — standalone test, no dyld dependencies.
Per-module tests for `vb_table.zig`, `vb_fixpoint.zig`, `vb_graph.zig` follow
the same pattern. The artifact loader's round-trip test encodes a tiny WZO1
with known bytes and verifies the battery's independent decoder reproduces
every field exactly.

## 12. What this design does not cover

- **Invariant algorithms** — those are V-7, V-8, V-9.
- **Fixtures** — those are V-10.
- **The fleet run** — that is V-13.
- **Register absorption** — that is V-14.
- **WZO2 bracket format** — oracle-v2's design. The battery loads WZO1 only and
  errors cleanly on WZO2.
- **The independent re-implementation (A5)** — V-11, which reads this schema
  but not the battery source.

## 13. Open questions for the pass-1 auditor (V-5)

1. **JSON vs line protocol:** JSON Lines was chosen for human readability and
   `jq` compatibility. A simpler line protocol (tab-separated, no quoting) would
   be faster to emit and parse. Is JSON the right call for a tool running ~60
   times, or would a line protocol be more appropriate?

2. **I5 artifact independence:** The spec says I5 "reads no stored values" but
   still needs the artifact's `fb`/`fw` columns to check KO_SENSITIVE flags. Is
   the design's handling (allow `--i5-only` without artifact for `all-legal`
   graph structure, require artifact for `--i5-graph reachable` and flag checks)
   consistent with the spec's intent?

3. **Proposed-row file vs stdout:** Should proposed rows go to a separate file
   (`--proposed-rows`), or should they be a separate `kind` in the main output
   stream? The current design separates them so the fleet runner can consume
   results without filtering, but a single stream is simpler to pipe.

4. **RSS prediction for I5:** The design says the battery should predict its I5
   allocation before Phase 3 and refuse if >4 GB. Should this be a compile-time
   check (goban-size-gated), a run-time check, or both? The i5-feasibility memo
   §5.2 recommends a run-time check.
