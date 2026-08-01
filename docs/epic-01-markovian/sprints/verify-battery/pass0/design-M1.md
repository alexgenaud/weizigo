# verify-battery M1 — harness design

```
Author:   DSPro/T149 · 2026-07-31
Status:   PROPOSED (rev 2) — resolves rev-1 re-audit (T147/Opus 5): 1 critical,
          4 must-fix
Inputs:   docs/epic-01-markovian/sprints/verify-battery/pass0/spec.md (rev 1) ·
          docs/epic-01-markovian/sprints/verify-battery/pass0/plan.md (rev 1) ·
          docs/epic-01-markovian/sprints/verify-battery/archive/spec-audit.md (T137) ·
          docs/epic-01-markovian/sprints/verify-battery/archive/i5-feasibility.md (DSPro/T134) ·
          docs/epic-01-markovian/sprints/verify-battery/archive/design-M1-audit.md (Opus 5/V-5) ·
          docs/epic-01-markovian/sprints/verify-battery/archive/design-M1-audit-rev1.md (T147/Opus 5)
```

## 1. Overview

M1 is the CLI, result schema, artifact-loading layer, and reference-data
mechanism. It owns no invariants but defines the contract every invariant
module (V-7–V-9) implements against. The design binds four things:

1. **CLI contract** — invocation, flags, exit codes (three classes per spec R6).
2. **Result schema** — JSON Lines, one result per (invariant, goban, artifact)
   cell, with denominators, §6a cell coordinates, `artifact_kind`, a trailer
   record, and proposed-row fields for CLAIMS.md absorption. **Frozen at Gate 2
   for the sprint.**
3. **Artifact loading** — per spec R8 (import nothing from `src/`). Loads WZO1
   artifacts by path with SHA-256 verification; recognises WZO2 and reports a
   clean error. The schema carries `artifact_kind: "pinned-v" | "bracket"` so
   the battery runs against WZO2 the day it exists without a schema unfreeze.
4. **Reference data** — committed register figures loaded from a versioned JSON
   file (`--reference`). The battery computes `reference-bad` itself; V-14
   absorbs the verdict rather than deriving it. The reference file's SHA-256 is
   reported in the header.

**WZO1 constraint (B1 resolution):** Every in-scope artifact under acceptance
criterion A2 is WZO1 — single-value columns (`vb`, `vw`), no L/H bracket pairs.
The schema is defined for both artifact kinds, but on WZO1 certain invariants
are `not_applicable` (I3, I10) or report a reduced value set (I1: `L_eq_H` only,
no pin_T/pin_L/pin_H; I4: residual restricted to KO_SENSITIVE-clear slots). The
schema carries `artifact_kind` in every record so consumers distinguish pinned-v
results from bracket results without reading the artifact. Full invariant
coverage requires WZO2 bracket artifacts (oracle-v2).

## 2. CLI contract

### 2.1 Invocation

```
verify-battery <goban> <artifact> [flags]
```

| argument | type | description |
|---|---|---|
| `<goban>` | string | Goban size: `2x2`, `3x2`, `3x3`, `4x3`, `4x4` |
| `<artifact>` | path | Path to `.wzo` artifact file. Use `--i5-only --i5-graph all-legal` when no artifact is needed for I5 structural runs (see §2.2). When the selected invariant set needs no artifact, `<artifact>` may be `""`. |

### 2.2 Flags

| flag | type | default | description |
|---|---|---|
| `--invariants <ids>` | comma-separated list | all twelve | Which invariants to run. E.g. `I1,I2,I3` or `I5`. Any invariant not in the list reports status `skipped`. |
| `--i5-only` | bool | false | Run I5 alone, no artifact required (I5 reads no stored values from the artifact for its graph construction; the KO_SENSITIVE flags it tests are read from the artifact when present). Mutually exclusive with `--invariants`; sets `--invariants I5`. When combined with `--i5-graph all-legal`, skips artifact loading entirely. When combined with `--i5-graph reachable`, the artifact IS loaded for its `fb`/`fw` columns. |
| `--i5-graph <kind>` | string | `all-legal` | Which graph I5 operates on: `reachable` (reachable-from-empty, the true game root) or `all-legal` (every legal position as independent root). Only meaningful with I5. |
| `--output <path>` | path | stdout | Write JSON-Lines results to this file. Default: stdout (data channel). |
| `--proposed-rows <path>` | path | — | Emit proposed CLAIMS.md rows to this file (see §3.5). If absent, no proposed rows are emitted. |
| `--reference <path>` | path | — | Load committed register figures from this JSON file (see §2.5). Required for exit class 2 (reference-bad) to be producible. If absent, register disagreements are not detected and exit class 2 is never emitted. |
| `--sha256 <hash>` | hex string | — | Verify the artifact's SHA-256 before loading. Mismatch → battery-bad exit. If absent, the artifact is loaded without hash verification; the SHA-256 is computed and reported in every result row regardless. |
| `--seed <N>` | u64 | 31337 | Seed for sampled invariants (I11 and any fallback-sampled runs). Default is a fixed documented value so fleet invocations are reproducible from their recorded arguments. Use `--seed auto` for PID+time non-determinism. |
| `--sample-size <N>` | u64 | per-invariant default | Override sample size for sampled invariants. **Rejected** if the §6a matrix declares the invariant exhaustive at this goban, unless `--allow-mode-deviation` is passed (see §6.1). |
| `--allow-mode-deviation` | bool | false | Permit a flag (`--sample-size` on an §6a-exhaustive cell) that would silently downgrade the declared evaluation mode. |
| `--version` | — | — | Print version and exit 0. |
| `--help` | — | — | Print usage and exit 0. |

**Mutual exclusion:** `--i5-only` and `--invariants` may not both be specified.

**I5 vs artifact:** When I5 is run with `--i5-graph all-legal` under `--i5-only`,
the artifact is not loaded (the graph is constructed from the battery's own rules
engine). When I5 is run with `--i5-graph reachable` or as part of a full battery
run that includes other invariants, the artifact IS loaded for its KO_SENSITIVE
flags (`fb`/`fw` columns only) and for the other invariants' use.

**artifact as optional:** The `<artifact>` positional argument may be the empty
string `""` when the selected invariant set needs no artifact (`--i5-only
--i5-graph all-legal`). In all other cases, a valid artifact path is required.

### 2.3 Exit codes

Per spec R6, three non-zero exit classes, distinguishable by machine:

| code | class | meaning |
|---|---|---|
| **0** | pass | All requested invariants completed; every result has `exit_class: "pass"` (including results whose `status` is `skipped` or `not_applicable`). |
| **1** | artifact-bad | At least one invariant computed cleanly and the artifact violates it. The invariant's `value` object carries the violation details. |
| **2** | reference-bad | At least one invariant computed cleanly and disagrees with a committed register figure. No artifact-bad results are present (artifact-bad takes precedence — see below). The invariant's `value` object carries the expected and actual values. |
| **3** | battery-bad | The harness could not complete: artifact load error, SHA-256 mismatch, OOM, stack overflow, internal assertion failure, or any invariant returned `status: "error"`. Results for invariants that DID complete before the failure are still emitted. |

**Precedence when multiple classes apply:** battery-bad (3) > artifact-bad (1)
> reference-bad (2) > pass (0). If any invariant returned `status: "error"`,
the overall exit is 3. If no errors but at least one `artifact-bad`, exit 1.
If only `reference-bad` results (and no `artifact-bad`), exit 2.

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

**Named failure output (R6):** when an invariant fails, the battery emits a
stderr line of the form `FAIL <invariant> <exit_class> <summary>` before the
result record is written, so monitoring tools can alert on the failure without
parsing JSON. Example: `FAIL I7 artifact-bad DTT uniform including terminals:
16543210/99133036`.

### 2.5 Reference data

The `--reference <path>` flag points to a committed, versioned JSON file
(e.g. `data/battery-references.json`) that carries register figures for
comparison. The file is loaded at startup; its SHA-256 is reported in the
header record. Each entry carries a value, a `file:line` citation, and
optional scope constraints.

**Reference file schema:**

```json
{
  "version": "1.0.0",
  "entries": [
    {
      "invariant": "I1",
      "goban": "3x2",
      "artifact_kind": "pinned-v",
      "field": "L_eq_H",
      "expected": 2232,
      "denominator": 2622,
      "citation": "docs/epistemic/CLAIMS.md:557"
    },
    {
      "invariant": "I1",
      "goban": "3x2",
      "artifact_kind": "pinned-v",
      "field": "denominator",
      "expected": 2586,
      "denominator": null,
      "note": "alternate denominator from EXP-4: docs/evidence/QA-026/exp4-solve-2026-07-29.stdout:96",
      "citation": "docs/evidence/QA-026/exp4-solve-2026-07-29.stdout:96"
    }
  ]
}
```

Each entry's `field` names a key in the invariant's `value` object. When the
battery's computed value for that field differs from `expected` (and the
`denominator` matches, if specified), the result's `exit_class` is
`reference-bad`. Entries carry the invariant, goban, and artifact kind so a
single reference file serves the whole fleet.

When `--reference` is absent, no register comparisons are performed,
`exit_class` is never `reference-bad`, and overall exit code 2 is never emitted.

The reference file is committed in the battery's tree and versioned alongside
the battery source. It is NOT generated by the battery — it is a human-curated
input, updated when the register changes. The battery's header record reports
its path and SHA-256 so every run is traceable to the reference data it used.

## 3. Result schema

### 3.1 Transport format

**JSON Lines** (NDJSON): one complete JSON object per line, no trailing comma,
`\n` terminated. Each line is self-contained and parseable independently.
Streaming-friendly — the fleet run (V-13) can `tee` to both a file and a
monitoring pipe. JSON tolerates additive fields, so the schema can gain
WZO2 fields at Gate 2+ without breaking consumers.

The output stream consists of:

1. A **header record** (first line, `"kind": "header"`)
2. One **result record** per invariant that ran (`"kind": "result"`)
3. A **trailer record** (last line, `"kind": "trailer"`)

The trailer is a truncation detector: no trailer → the run died mid-stream and
the results are incomplete.

If `--proposed-rows` is set, that file receives a separate stream of
**proposed-row records** (one per (invariant, goban, artifact) cell — see §3.5).

**JSON escaping:** the battery uses Zig's `std.json` for writing. The schema
fields include artifact paths, error messages, and `claim_text` that may
contain quotes, backslashes, newlines, and non-ASCII characters (including the
project's `×` and `⊆`). A hand-rolled writer must escape these correctly; the
risk of a silent-corruption defect in the instrument is higher than the
allocation cost of `std.json.stringify` at ~60 invocations × ~13 records. The
battery SHALL round-trip test its output through `std.json.parse` over a
fixture containing quotes, backslashes, newlines, and non-ASCII before any
fleet run.

### 3.2 Header record

Emitted once, first line of stdout (or `--output`). Identifies the run and the
schema versions in effect.

#### 3.2.1 Field table

| field | type | nullable | description |
|---|---|---|---|
| `kind` | string | no | Always `"header"`. |
| `battery_version` | string | no | Semantic version of the verify-battery binary. |
| `schema_version` | string | no | Result schema version (`"1.0.0"`). Incremented when the schema changes incompatibly. |
| `artifact_kind` | string | yes | `"pinned-v"` or `"bracket"`. `null` when no artifact was loaded (I5 all-legal, no artifact). |
| `format` | string | yes | Artifact format: `"WZO1"` or `"WZO2"`. `null` when no artifact loaded. |
| `format_version` | u8 | yes | Artifact format version number. `null` when no artifact loaded. |
| `goban` | string | yes | `2x2`–`4x4`. `null` if the goban argument was invalid (pre-load failure). |
| `artifact` | string | yes | Path as given on CLI. `null` if no artifact was loaded or if artifact loading failed before the path was resolved. |
| `artifact_sha256` | string | yes | Hex-encoded SHA-256 of artifact file bytes. `null` if no artifact was loaded or if loading failed before the hash could be computed. |
| `artifact_total` | u64 | yes | The `total` field from the artifact header (= 3^(w×h)). `null` if no artifact loaded. |
| `artifact_legal_count` | u64 | yes | Legal positions per side, from artifact header. `null` if no artifact loaded. |
| `artifact_rules_id` | u8 | yes | `1` = Chinese area PSK, `2` = basicko TIE area (see §4.2). `null` if no artifact loaded. |
| `artifact_rules_name` | string | yes | Human-readable rules name. `null` if no artifact loaded. |
| `reference_path` | string | yes | Path given to `--reference`. `null` if `--reference` was not passed. |
| `reference_sha256` | string | yes | SHA-256 of the reference file. `null` if no reference file was loaded. |
| `timestamp` | string | no | ISO-8601 UTC timestamp at startup. |
| `argv` | [string] | no | The full command-line argument vector, for exact replay. |
| `seed` | u64 | no | The seed in effect. When `--seed auto` was passed, the PID+time-derived u64 is stored here; `seed_source` records how it was obtained. |
| `seed_source` | string | no | `"fixed"` (explicit `--seed` or default 31337) or `"auto"` (`--seed auto`). |
| `invariants_requested` | [string] | no | The list of invariants actually selected, after resolving `--invariants`, `--i5-only`, and the §6a applicability matrix. |
| `i5_graph` | string | yes | `"all-legal"` or `"reachable"`. Present only when I5 is in `invariants_requested`; `null` otherwise. |

#### 3.2.2 Minimal header on pre-load failure

When the battery fails before artifact loading completes (invalid goban size,
unknown flag, artifact file not found), only the fields that can be populated
are emitted; everything else is `null`:

```json
{
  "kind": "header",
  "battery_version": "1.0.0",
  "schema_version": "1.0.0",
  "artifact_kind": null,
  "format": null,
  "format_version": null,
  "goban": null,
  "artifact": "data/nonexistent.wzo",
  "artifact_sha256": null,
  "artifact_total": null,
  "artifact_legal_count": null,
  "artifact_rules_id": null,
  "artifact_rules_name": null,
  "reference_path": "data/battery-references.json",
  "reference_sha256": "a1b2c3...",
  "timestamp": "2026-07-31T14:22:00Z",
  "argv": ["verify-battery", "4x4", "data/nonexistent.wzo", "--reference", "data/battery-references.json"],
  "seed": 31337,
  "seed_source": "fixed",
  "invariants_requested": [],
  "i5_graph": null
}
```

#### 3.2.3 Worked example — full header

```json
{
  "kind": "header",
  "battery_version": "1.0.0",
  "schema_version": "1.0.0",
  "artifact_kind": "pinned-v",
  "format": "WZO1",
  "format_version": 1,
  "goban": "3x2",
  "artifact": "artifacts/oracle-3x2.wzo",
  "artifact_sha256": "d4d22c0d9f1d771bfcb1d99fc43a4f19f652205113ff599123b189097b3bb523",
  "artifact_total": 729,
  "artifact_legal_count": 489,
  "artifact_rules_id": 1,
  "artifact_rules_name": "Chinese area, komi 0, positional superko",
  "reference_path": "data/battery-references.json",
  "reference_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "timestamp": "2026-07-31T14:22:00Z",
  "argv": ["verify-battery", "3x2", "artifacts/oracle-3x2.wzo", "--reference", "data/battery-references.json"],
  "seed": 31337,
  "seed_source": "fixed",
  "invariants_requested": ["I1","I2","I4","I5","I6","I7","I9","I11","I12"],
  "i5_graph": "all-legal"
}
```

**Note on invariants_requested:** I3 and I10 are absent — they are
`not_applicable` on WZO1 (no bracket columns). I8 is n/a at 3×2. This reflects
the resolved §6a matrix for `artifact_kind: "pinned-v"` at 3×2 (see §5a).

### 3.3 Result record

One per invariant run. Common fields for all invariants:

```json
{
  "kind": "result",
  "invariant": "I1",
  "goban": "3x2",
  "artifact_kind": "pinned-v",
  "format": "WZO1",
  "format_version": 1,
  "artifact": "artifacts/oracle-3x2.wzo",
  "artifact_sha256": "d4d22c0d...",
  "mode_declared": "exhaustive",
  "mode_actual": "exhaustive",
  "scope_once_per_goban": false,
  "status": "pass",
  "exit_class": "pass",
  "duration_ms": 1234,
  "rss_hwm_after_mb": 45.2,
  "seed": null,
  "sample_size": null,
  "sample_denominator": null,
  "value": { ... }
}
```

**Common field types:**

| field | type | nullable | description |
|---|---|---|---|
| `kind` | string | no | Always `"result"`. |
| `invariant` | string | no | `I1`–`I12`. |
| `goban` | string | no | `2x2`, `3x2`, `3x3`, `4x3`, `4x4`. |
| `artifact_kind` | string | yes | `"pinned-v"` or `"bracket"`. `null` for I5 all-legal runs with no artifact. |
| `format` | string | yes | `"WZO1"` or `"WZO2"`. `null` when no artifact loaded. |
| `format_version` | u8 | yes | Artifact format version. `null` when no artifact loaded. |
| `artifact` | string | yes | Path as given on CLI. `null` for I5 all-legal runs with no artifact. |
| `artifact_sha256` | string | yes | Hex SHA-256, or `null` if no artifact was loaded. |
| `mode_declared` | string | no | The evaluation mode declared by the §6a matrix for this (invariant, goban, artifact_kind) cell: `exhaustive`, `sampled`, or `not-applicable`. |
| `mode_actual` | string | no | The evaluation mode that actually ran: `exhaustive`, `sampled`, or `not-applicable`. |
| `scope_once_per_goban` | bool | no | `true` if the invariant is scoped once per goban regardless of how many artifacts are in play (I5 per spec S1). |
| `status` | string | no | `pass` — invariant holds. `fail` — invariant violated cleanly (artifact-bad). `reference-disagreement` — invariant holds but the computed value disagrees with a committed register figure (reference-bad). `skipped` — invariant not selected by `--invariants`. `not_applicable` — invariant doesn't apply to this goban or artifact kind (e.g. I3 on WZO1, I8 at 3×2+). `error` — invariant could not complete (resource, internal bug). |
| `exit_class` | string | no | `pass`, `artifact-bad`, `reference-bad`, `battery-bad`. The per-result classification. |
| `duration_ms` | u64 | no | Wall-clock duration of this invariant in milliseconds. |
| `rss_hwm_after_mb` | f64 | yes | Process RSS high-water mark in MiB after this invariant completed. This is a running maximum — for invariant *n* the value is max(HWM over invariants 1..*n*), not the per-invariant peak. `null` if not measured. |
| `seed` | u64 | yes | Seed used for this invariant, if sampled; `null` otherwise. |
| `sample_size` | u64 | yes | Sample size drawn, if sampled; `null` otherwise. |
| `sample_denominator` | u64 | yes | Total population size, if sampled (per R3: within-budget denominator). `null` for exhaustive. |
| `value` | object | yes | Invariant-specific result data (see §3.6). `null` when `status` is `error`, `skipped`, or `not_applicable`. |
| `deviation` | string | yes | Present only when `mode_actual ≠ mode_declared` and `status` is not `error`. Carries the fallback reason code (e.g. `"memory-budget-fallback-F3"`). |
| `error` | object | yes | Present only when `status` is `error`. Carries error details (see §3.7). |

**`status` vs `exit_class`:**

| status | exit_class | meaning |
|---|---|---|
| `pass` | `pass` | Invariant holds, no register disagreement. |
| `fail` | `artifact-bad` | Invariant violated cleanly — the artifact is wrong. |
| `reference-disagreement` | `reference-bad` | Invariant holds (artifact is self-consistent) but the computed value disagrees with a committed register figure. The register entry goes to audit, not the artifact. |
| `skipped` | `pass` | Invariant not selected for this run. No bearing on exit code. |
| `not_applicable` | `pass` | Invariant does not apply to this goban or artifact kind. No bearing on exit code. |
| `error` | `battery-bad` | Invariant could not complete. |

**`mode_actual ≠ mode_declared`:** when the actual run mode differs from the
§6a-declared mode (e.g. a memory fallback downgrades I5 from exhaustive to
sampled at 4×4), a `deviation` field is added to the result record:

```json
{
  ...
  "mode_declared": "exhaustive",
  "mode_actual": "sampled",
  "deviation": "memory-budget-fallback-F3"
}
```

A mode deviation always emits a stderr warning naming the invariant, the
declared and actual modes, and the reason. `--sample-size` on a cell the §6a
matrix declares exhaustive is rejected unless `--allow-mode-deviation` is
passed.

**Duplication rule:** every fact appears once in the result record. The
top-level fields (`seed`, `sample_size`, `sample_denominator`, `mode_actual`,
`i5_graph`) are authoritative; the `value` object does not duplicate them.

### 3.4 Trailer record

Emitted once, last line of stdout (or `--output`). Carries invocation-level
aggregates that cannot be known until after all invariants complete. A missing
trailer means the run died mid-stream.

```json
{
  "kind": "trailer",
  "exit_code": 0,
  "total_duration_ms": 45231,
  "rss_hwm_after_mb": 1247.3,
  "result_counts": {
    "pass": 8,
    "fail": 0,
    "reference_disagreement": 0,
    "skipped": 0,
    "not_applicable": 3,
    "error": 0
  },
  "exit_class_counts": {
    "pass": 11,
    "artifact_bad": 0,
    "reference_bad": 0,
    "battery_bad": 0
  }
}
```

| field | type | nullable | description |
|---|---|---|---|
| `kind` | string | no | Always `"trailer"`. |
| `exit_code` | u8 | no | The overall exit code (0–3) the process will return. |
| `total_duration_ms` | u64 | no | Wall-clock duration of the entire invocation in milliseconds. |
| `rss_hwm_after_mb` | f64 | yes | Process RSS high-water mark in MiB at exit (invocation-level peak, per A6). `null` if not measured. |
| `result_counts` | object | no | Counts by `status` value. |
| `exit_class_counts` | object | no | Counts by `exit_class` value. |

### 3.5 Proposed-row format

When `--proposed-rows <path>` is set, the battery writes a JSON Lines file with
one object per **(invariant, goban, artifact)** cell that actually ran. This is
separate from the result stream — it is the input V-14 (register absorption)
reads.

**Cell cardinality:** result records and proposed rows are per-artifact. A §6a
cell is an aggregate over all in-scope artifacts for that goban, computed by
V-13 (the fleet run). Each proposed row carries `artifacts_in_scope` and
`artifact_index` so V-14 can distinguish a complete cell from a partial one.

```json
{
  "kind": "proposed-row",
  "invariant": "I1",
  "goban": "3x2",
  "artifact_kind": "pinned-v",
  "artifact": "artifacts/oracle-3x2.wzo",
  "artifact_sha256": "d4d22c0d...",
  "artifacts_in_scope": 1,
  "artifact_index": 0,
  "status": "pass",
  "claim_text": "I1 pin census at 3×2 (WZO1): L==H=2232 / 2622 reachable states",
  "evidence_path": "docs/evidence/BATTERY/fleet.md",
  "reference_expected": null,
  "reference_actual": null,
  "reference_citation": "docs/epistemic/CLAIMS.md:557",
  "depends_on": ["GLOBAL.FP1", "3x2.C1"],
  "notes": null
}
```

**Field types:**

| field | type | nullable | description |
|---|---|---|---|
| `kind` | string | no | Always `"proposed-row"`. |
| `invariant` | string | no | `I1`–`I12`. |
| `goban` | string | no | `2x2`–`4x4`. |
| `artifact_kind` | string | yes | `"pinned-v"` or `"bracket"`. |
| `artifact` | string | yes | The artifact path. `null` for I5 once-per-goban runs with no artifact. |
| `artifact_sha256` | string | yes | As in result record. |
| `artifacts_in_scope` | u8 | no | How many artifacts are in scope for this goban (from spec A2's enumerated list). |
| `artifact_index` | u8 | yes | Which artifact in the scope list this row represents (0-indexed). `null` for I5 once-per-goban rows (which have no artifact). |
| `status` | string | no | `pass`, `fail`, `reference-disagreement`, `skipped`, `not_applicable`, `error`. |
| `claim_text` | string | no | A human-readable one-liner describing what was tested and the result, suitable for the `claim` column of CLAIMS.md. |
| `evidence_path` | string | no | Where the evidence lives (always under `docs/evidence/BATTERY/`). |
| `reference_expected` | string | yes | If reference-bad: the committed register value. Else `null`. |
| `reference_actual` | string | yes | If reference-bad: the battery's computed value. Else `null`. |
| `reference_citation` | string | yes | If a register citation exists for this cell: `file:line`. Else `null`. |
| `depends_on` | [string] | no | CLAIMS.md claim IDs this row's truth depends on. E.g. `["GLOBAL.FP1", "3x2.C1"]`. |
| `notes` | string | yes | Any caveats, e.g. "I5 disagreement matches the known 1,724/1,704/1,678 spread — reference-disagreement, not fail." |

**Proposed-row invariants:** every invariant that actually ran produces a
proposed row. Invariants with `status: "skipped"` or `status: "not_applicable"`
also produce rows so the register records which cells have been evaluated and
which haven't. For I5 (once per goban), only ONE proposed row is emitted per
goban, regardless of how many artifacts are in scope — the row's `artifact`
field is `null` and `artifacts_in_scope` reports the full count.

**Emission on error:** on a battery-bad run, proposed rows are emitted for
every invariant that completed before the failure. Each such row carries an
additional field `run_incomplete: true`. V-13 treats these as partial and
re-runs the invocation.

Rows are written after each invariant completes (streamed), not batched at the
end — this ensures rows for completed invariants survive a later crash.

### 3.6 Invariant-specific `value` schemas

Every invariant's `value` object has at minimum:

```json
{
  "numerator": 2232,
  "denominator": 2622
}
```

**Per R3:** every reported number states its denominator. The `numerator` and
`denominator` fields are the top-level counts for the invariant. Additional
fields vary by invariant and by `artifact_kind`.

**Convention for WZO1:** invariants that require bracket columns (L/H pairs) are
`not_applicable` on WZO1. The schema defines all fields for both artifact kinds
so no unfreeze is needed when WZO2 ships. On WZO1, bracket-only fields are
absent from the `value` object (not `null` — absent, so WZO2 can add them
additively without breaking JSON consumers).

#### I1 — pin census

**WZO1 (pinned-v):** only `L_eq_H` is computable. `pin_T`, `pin_L`, `pin_H`
require bracket columns and are absent on WZO1.

```json
{
  "numerator": 2232,
  "denominator": 2622,
  "L_eq_H": 2232,
  "reference": {
    "expected_L_eq_H": 2220,
    "expected_denominator": 2586,
    "citation": "docs/evidence/QA-026/exp4-solve-2026-07-29.stdout:96"
  }
}
```

**WZO2 (bracket):** full pin census — `L_eq_H`, `pin_T`, `pin_L`, `pin_H`. The
`reference` sub-object carries the register figures for all four fields (and the
alternate 2,586 denominator where applicable).

The `reference` sub-object is present only when `--reference` was passed and a
register entry exists for this (invariant, goban, artifact_kind) cell. The
battery computes `reference-disagreement` when its value differs from the
reference and the denominator matches. When the denominator doesn't match any
reference (e.g. 2,586 vs 2,622 at 3×2), the battery reports its census as-is
with `status: "pass"` (since both denominators represent valid state sets) and
the `notes` field in the proposed row records the denominator discrepancy for
V-14 reconciliation.

#### I2 — colour inversion

Computable on both WZO1 and WZO2. On WZO1: `V(-pos,-side) != -V(pos,side)`.
On WZO2: `L(-pos,-side) != -H(pos,side)` and `H(-pos,-side) != -L(pos,side)`.

```json
{
  "numerator": 0,
  "denominator": 2622,
  "violations": 0,
  "violation_examples": []
}
```

`violations`: count of (position, side) pairs where the invariant is violated.
`violation_examples`: up to 5 example colex indices; empty on pass.

#### I3 — L ≤ H

**WZO1:** `not_applicable` — no L/H columns to compare. `value: null`.

**WZO2:**

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

**WZO1:** residual restricted to KO_SENSITIVE-clear slots (where the single V
column represents both L and H, i.e. the region where L==H). KO_SENSITIVE-set
slots are excluded from the count — they have no well-defined Φ-target under
single-value semantics. The denominator is the number of KO_SENSITIVE-clear
legal non-terminal slots examined.

```json
{
  "numerator": 0,
  "denominator": 98765432,
  "violations": 0,
  "ko_sensitive_excluded": 123456,
  "note": "WZO1: KO_SENSITIVE-set slots excluded (no L/H to compute residual against). Denominator = KO_SENSITIVE-clear legal non-terminal slots. WZO2 will cover the full slot set."
}
```

**WZO2:** full Bellman residual — `L = Φ(L)`, `H = Φ(H)` on all legal slots.

```json
{
  "numerator": 0,
  "denominator": 99133036,
  "L_violations": 0,
  "H_violations": 0,
  "note": "denominator = compact slot count (passes ∈ {0,1})"
}
```

#### I5 — SCC containment

Computable on both WZO1 and WZO2 (reads only `fb`/`fw` columns from the
artifact, or no artifact at all for `--i5-graph all-legal`).

```json
{
  "numerator": 0,
  "denominator": 203,
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
    "nodes_expected": 282,
    "nodes_citation": "docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py",
    "edges_expected": 508,
    "edges_citation": "docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py",
    "max_scc_expected": 160,
    "max_scc_citation": "docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py",
    "cycle_reachable_expected": null,
    "cycle_reachable_citation": null
  }
}
```

**`numerator`:** count of KO_SENSITIVE flags outside the cycle-reachable set
(`ko_sensitive_not_cycle_reachable`). Should be 0.

**`denominator`:** total KO_SENSITIVE-set legal slots examined (= `ko_sensitive_flags`).

**`nodes`, `edges`, `sccs_total`, `sccs_non_trivial`, `max_scc_size`,
`cycle_involved`, `cycle_reachable`:** graph-shape metrics. These are NOT the
ratio — the ratio is `numerator` / `denominator` (= `ko_sensitive_not_cycle_reachable`
/ `ko_sensitive_flags`).

**`calibration`:** always present when `--reference` provides targets. Carries
expected values from committed evidence. The `max_scc_expected` and
`nodes_expected`/`edges_expected` are self-consistency gates: a mismatch here
means the Tarjan implementation itself is wrong (`exit_class: "battery-bad"`),
not the artifact.

For 3×2 `--i5-graph reachable`, `calibration.cycle_reachable_expected` = 1,678
(true game root convention per spec §4).

For 3×2 `--i5-graph all-legal`, `calibration.max_scc_expected` = 1,676
(`docs/evidence/QA-023/ko-fix-rerun-2026-07-29.stdout:107`).

**I5 exit_class rules (ordered, first match wins):**

1. `max_scc_size` mismatch with calibration → `battery-bad` (implementation wrong, not the artifact).
2. `nodes`/`edges` mismatch with calibration → `battery-bad` (graph construction wrong).
3. `ko_sensitive_not_cycle_reachable > 0` at 3×2 AND `cycle_reachable` matches a member of the committed spread (1,724/1,704/1,678 — **cycle-reachable set sizes** under three seeding conventions; spec §4:120-124, `ko-fix-rerun-2026-07-29.stdout:133`) → `reference-bad` with notes identifying which spread member matched.
4. `ko_sensitive_not_cycle_reachable > 0` at 3×2 AND `cycle_reachable` is **outside** the known spread → `artifact-bad`, escalate per spec §7 (finding larger than sprint).
   *Note: the spread values are `cycle_reachable` counts, not `ko_sensitive_not_cycle_reachable` counts. Rule 3 tests `cycle_reachable` (a graph-shape metric reported in the `value` object) against the spread; `ko_sensitive_not_cycle_reachable > 0` is the gate condition for both rules 3 and 4.*
5. `ko_sensitive_not_cycle_reachable > 0` at 2×2 → `artifact-bad`.
6. `ko_sensitive_not_cycle_reachable > 0` at 3×3, 4×3, 4×4 → `artifact-bad`.

**I5 graph-to-slot projection:** artifact slots are `(position, side)` at the
`ko == NONE, passes == 0` slice (per `src/artifact.zig:48-54`). The I5 graph's
nodes are `(board, side, ko_point, passes)` with `passes ∈ {0, 1}`. A stored
`KO_SENSITIVE` flag on slot `(position, side)` maps to graph node
`(position, side, ko=NONE, passes=0)`. "Cycle-reachable" for a slot means that
specific graph node is in the cycle-reachable set of the SCC decomposition.
Other ko-point/passes variants of the same position may differ.

#### I6 — UNDEF census

Computable on both WZO1 and WZO2. Counts are over the dense 3^(w×h) position
space (the artifact's total address space). The `oeis_legal_reference` field
is nullable — OEIS A094777 is defined only for n×n gobans (2×2, 3×3, 4×4);
at 3×2 and 4×3 the field is `null` and the `oeis_citation` field names the
appropriate reference.

```json
{
  "numerator": 24318165,
  "denominator": 43046721,
  "illegal": 24187097,
  "legal_black": 65534,
  "legal_white": 65534,
  "legal_positions_total": 24318165,
  "oeis_legal_reference": 24318165,
  "oeis_citation": "OEIS A094777",
  "legal_matches_oeis": true,
  "note": "denominator = total address space 3^(w×h). legal_black = |{idx: vb[idx] != -128}| (per-side count, NOT a partition). legal_white = |{idx: vw[idx] != -128}|. By symmetry legal_black == legal_white. legal_positions_total = illegal + legal_black + legal_white (double-counts the overlap on positions legal for both sides, producing the OEIS total). T172/T180 GAP-2: fields renamed from legal_both_sides/legal_one_side_only for clarity."
}
```

**Denominator is the dense 3^(w×h) position count** (not the compact slot
count). All I6 counts are in this unit. The `numerator` is
`legal_positions_total`.

`legal_black`: count of colex indices where `vb[idx] != -128` — i.e., positions
legal when Black to move. This is a per-side count.

`legal_white`: count of colex indices where `vw[idx] != -128` — i.e., positions
legal when White to move. By symmetry `legal_black == legal_white`.

**These are per-side counts, NOT a partition.** A position legal for both sides
appears in both `legal_black` and `legal_white`. `legal_positions_total` =
`illegal + legal_black + legal_white` double-counts the overlap, producing
the OEIS total. (T172/T180 GAP-2: fields renamed from `legal_both_sides` /
`legal_one_side_only` which misleadingly suggested mutually exclusive categories.)

`oeis_legal_reference`: `null` at 3×2 and 4×3 (OEIS A094777 is n×n only).
`oeis_citation`: `"OEIS A094777"` at square gobans; at 3×2 and 4×3 carries
`"not applicable — OEIS A094777 is n×n only; see spec A2 artifact_legal_count"`.

#### I7 — DTT sanity

Computable on both WZO1 and WZO2. Reads `db`/`dw` columns (DTT).

**Pass example (expected on a correct artifact):**

```json
{
  "numerator": 0,
  "denominator": 99133036,
  "terminals_with_dtt_neq_0": 0,
  "dtt_recurrence_violations": 0,
  "non_terminals_with_dtt_255": 41234567,
  "terminals_total": 16543210,
  "uniform_count": null,
  "uniform_value": null,
  "note": "denominator = compact slot count. terminals_with_dtt_neq_0 = 0 is the primary pass condition. dtt_recurrence_violations = count of non-terminals where DTT(state) != 1 + min(DTT(children)) — null if not computed (T172/T180 GAP-3). non_terminals_with_dtt_255 reports far-count for distribution. uniform_count is null on pass."
}
```

**Fail example (v1 4×4 artifact — uniform 255 including terminals):**

```json
{
  "numerator": 16543210,
  "denominator": 99133036,
  "terminals_with_dtt_neq_0": 16543210,
  "dtt_recurrence_violations": null,
  "non_terminals_with_dtt_255": 82589826,
  "terminals_total": 16543210,
  "uniform_count": 99133036,
  "uniform_value": 255,
  "note": "FAIL: numerator = terminals_with_dtt_neq_0. DTT uniformly 255 across all slots including terminals. 255 = DTT_FAR sentinel — legitimate on far states, but terminals must be 0. dtt_recurrence_violations is null (not computed — uniform-255 makes recurrence meaningless; every terminal already fails the simpler check)."
}
```

**`numerator`** = `terminals_with_dtt_neq_0 + (dtt_recurrence_violations ?? 0)`. Should be 0.

**`denominator`** = compact slot count (passes ∈ {0,1}).

`dtt_recurrence_violations`: count of non-terminal legal slots where
`DTT(state) != 1 + min(DTT(children))` — the recurrence property from spec §4.
Requires the rules engine for child generation (M3 scope). `null` when not
computed (deferred to WZO2 or rules engine unavailable). When non-null and
> 0, the invariant is artifact-bad. T172/T180 GAP-3.

`uniform_count` and `uniform_value`: reported only when the column is uniform
across all slots; `null` otherwise. The defect signature is uniformity
**including terminals**, not the value 255 itself. 255 = `DTT_FAR` sentinel,
legitimate on far states; uniform-including-terminals is the defect.

#### I8 — truncation-gap regression (2×2 only)

Computable on both WZO1 and WZO2.

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

At gobans other than 2×2: `mode_declared: "not-applicable"`, `mode_actual: "not-applicable"`,
`status: "not_applicable"`, `value: null`.

#### I9 — anchors

Computable on both WZO1 and WZO2. Checks the root (empty goban) value against
committed anchors.

```json
{
  "numerator": 1,
  "denominator": 1,
  "expected_root": 0,
  "actual_root": 0,
  "match": true,
  "reference_citation": "docs/research/newrule-3x3-2026-07-28.md:74",
  "note": null
}
```

`numerator` / `denominator`: anchors checked / anchors committed. `1/1` where an
anchor exists, `0/0` at 4×3 (no committed anchor).

For 4×3: `expected_root: null`, `match: null`, `note: "no committed anchor for 4×3 — spec §4 I9"`.
For 4×4: `expected_root: 1`, `note: "+1 vs MIGOS +2 — open discrepancy (spec §4 I9)"`.
`status: "pass"` when `match: true` or when no reference exists.

#### I10 — TIE median

**WZO1:** `not_applicable` — no L/H/TIE triple to check. WZO1's single V column
under `rules_id = 2` is the TIE-resolved pin; the median check requires L and H
which are not stored. `value: null`.

**WZO2:**

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
median of the three values. **Under the three-value median definition,
`tie_not_median` is always 0**: when TIE ∈ [L, H], median(L, TIE, H) = TIE
trivially. The field is retained for forward compatibility with a future
distribution-median check. The operational pass condition is
`tie_below_L == 0 AND tie_above_H == 0`. T172/T180 GAP-4.

#### I11 — move-set consistency

Computable on both WZO1 and WZO2.

```json
{
  "numerator": 0,
  "denominator": 500,
  "mismatches": 0,
  "mismatch_examples": [],
  "solver_dump_path": "docs/evidence/BATTERY/move-dump-3x3.smd1",
  "solver_dump_format": "SMD1",
  "solver_dump_sha256": "a1b2c3...",
  "note": "sampled at 3×3 per §6a (3×3 population TBD in V-8 — see §5 item 5). Dump format: SMD1 binary (§4.6)."
}
```

`denominator` = sample size when `mode_actual: "sampled"`, or total population
when exhaustive. `numerator` = `mismatches`.

`mismatches`: count of states where the battery's legal-move set differs from
the solver engine's legal-move set (via solver-side dump).

**§6a modes:** exhaustive at 2×2/3×2; sampled at 3×3+ (population TBD in V-8 at
3×3 and 4×3; at 4×4 = 99,133,036 compact slots
`[4x4.BASICKO-TIE:MEASUREMENT]` per `i5-feasibility.md` §2;
default sample sizes TBD in V-8).

#### I12 — score range

Computable on both WZO1 and WZO2. On WZO1: checks `V ∈ [-area, +area]`. On
WZO2: checks `L, H, TIE ∈ [-area, +area]`.

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

### 3.7 Error result

When an invariant cannot complete (`status: "error"`), the `value` object is
replaced by an `error` object:

```json
{
  "kind": "result",
  "invariant": "I5",
  "goban": "4x4",
  "artifact_kind": "pinned-v",
  "format": "WZO1",
  "format_version": 1,
  "artifact": "data/oracle-4x4-basicko-tie-area.wzo",
  "artifact_sha256": "edd9f68e...",
  "mode_declared": "exhaustive",
  "mode_actual": "sampled",
  "scope_once_per_goban": true,
  "status": "error",
  "exit_class": "battery-bad",
  "duration_ms": 45000,
  "rss_hwm_after_mb": 3950.1,
  "seed": 31337,
  "sample_size": null,
  "sample_denominator": null,
  "deviation": "memory-budget-fallback-F3",
  "error": {
    "kind": "memory_budget",
    "message": "I5: memory budget exceeded (predicted 4.2 GB > 4.0 GB cap), sample-only fallback triggered",
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

Per spec R8, the battery imports **nothing from `src/`** — that is, nothing
from the solver's source modules. The battery's own files live under `src/`
(`src/verify_battery.zig`, `src/vb_common.zig`, `src/vb_table.zig`, etc.),
which is fine: the rule is about importing solver modules, not about directory
names. No battery file imports or links against `src/artifact.zig`,
`src/colex.zig`, `src/rules.zig`, `src/util.zig`, or any other solver module.

The battery's re-implemented subsystems:

| subsystem | lines (est.) | re-implements |
|---|---|---|
| Artifact loader | 200–400 | WZO1 header parsing, CRC-32 verification, column extraction (replaces `src/artifact.zig`) |
| Colex addressing | ~100 | `rank_from_pos`, `pos_from_rank`, the colex mixed-radix bijection (replaces `src/colex.zig`) |
| Basic-ko rules engine | ~250–350 | Legal-move generation: empty-cell check, ko-forbidden check, suicide check, pass, terminal detection (replaces `src/rules.zig`) |
| stdout discipline | ~50 | `util.out(...)` / `util.note(...)` split per AGENTS.md (replaces `src/util.zig`) |

**Total: ~600–900 lines** (≈30–45% of an estimated ~2,000-line battery). The
range is carried honestly — the spec audit (T137/S1) estimated ~700. The cost
is flagged for human ratification at G1 per spec R8. This estimate does not
include the invariant implementations themselves (V-7 through V-9).

The battery's loader MUST produce identical decoding results to
`src/artifact.zig`'s `decode()` on every in-scope artifact. Verification:
round-trip the header fields and column byte arrays against the reference
loader in V-10 (calibration). The comparison runs in a **separate binary**
that is not part of the battery — a V-10 test file that imports
`src/artifact.zig` alongside the battery's loader and compares outputs. A
disagreement is **adjudicated** (either side may be wrong), not auto-resolved
toward `src/`. This preserves the independence R8 exists to create.

Note the battery **does** share `std.hash.crc.Crc32IsoHdlc` and
`std.crypto.hash.sha2.Sha256` with the solver — these are Zig standard library,
not solver code, and sharing them is correct (a defect in `std` is not a
common-mode failure between two independent decoders; it would affect every Zig
program equally).

### 4.2 WZO1 format (re-specified for the battery)

The battery re-implements the WZO1 format from the on-disk layout. This section
is the **battery's independent specification** — the header table and field
descriptions are derived from examining artifact files directly, not from
copying `src/artifact.zig`'s prose.

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
positions. A position is legal for side S iff `vS[idx] != -128`. The
`legal_count` field in the header records how many colex indices are legal for
a given side (same count for both sides, by symmetry).

**Artifact-to-graph slot mapping:** artifact slots are at the `ko == NONE,
passes == 0` slice of the full game state. Per `src/artifact.zig:48-54`, a
stored value never knows a ko is pending. This matters for I5: a
`KO_SENSITIVE` flag on artifact slot `(position, side)` maps to I5 graph node
`(position, side, ko=NONE, passes=0)`. "Cycle-reachable" for the slot means
that specific graph node is in the cycle-reachable set. Other ko-point and
passes variants of the same position may have different SCC membership; the
stored flag is a property of the artifact slice only.

**Flag bits:**

| bit | name | meaning |
|---|---|---|
| 0 | KO_SENSITIVE | The stored value is in the ko-sensitive region: its fresh-start value depends on cycle-resolution policy. Set by the retrograde engine; verified by the finisher. `KO_SENSITIVE` clear ⇔ `L == H` at this slot. |
| 1 | FROM_FORWARD | The stored value was produced by the forward finisher (not the retrograde fixpoint). |

**DTT sentinel:** `255` = `DTT_FAR` — the state is unreachable from any terminal,
or its distance is unknown. Legitimate on far states. The I7 invariant's defect
signature is *uniformity including terminals*, not the value 255 itself.

**CRC-32:** ISO-HDLC polynomial (`0xEDB88320`), computed over the entire payload
(bytes 32..end). The battery uses Zig's `std.hash.crc.Crc32IsoHdlc`.

### 4.3 Load procedure

```
1. Read file bytes into memory, computing SHA-256 in the same pass.
2. If --sha256 <hash>: compare. Mismatch → battery-bad.
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
15. Set artifact_kind = "pinned-v", format = "WZO1", format_version = 1.
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
  "goban": "4x4",
  "artifact_kind": null,
  "format": "WZO2",
  "format_version": null,
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

The battery does NOT attempt to parse WZO2. The schema is defined with
`artifact_kind: "bracket"` and bracket-column `value` fields in §3.6 so that
when WZO2 support is added, the schema does not need to be unfrozen —
consumers already know the field names. This is a deliberate Gate 2
investment: the schema costs nothing to make bracket-aware now, and a
mid-sprint unfreeze costs everything.

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
the minimal header record (§3.2.2), the error result, the trailer, and exits 3.

### 4.6 SMD1 solver-dump format (I11)

**Status: DEFINED by T172/T180 GAP-5 resolution.** This section specifies the
binary format the solver-side dump utility writes and the battery's I11 reader
parses. The format is complete enough for independent implementation of both
sides.

#### 4.6.1 File structure

```
┌──────────────────┐
│  Header (28 B)   │
├──────────────────┤
│  Record 0        │
├──────────────────┤
│  Record 1        │
├──────────────────┤
│  ...             │
├──────────────────┤
│  Record N-1      │
├──────────────────┤
│  CRC-32 (4 B)    │  ← CRC of all records only (not the header)
└──────────────────┘
```

Records are sorted by `(colex_idx, side)` ascending. The CRC-32 is ISO-HDLC
(`0xEDB88320`), same polynomial as the WZO1 artifact's payload CRC.

#### 4.6.2 Header (28 bytes, little-endian)

| offset | size | field | description |
|---|---|---|---|
| 0 | 4 | magic | ASCII `SMD1` |
| 4 | 1 | version | `1` |
| 5 | 1 | w | goban width |
| 6 | 1 | h | goban height |
| 7 | 1 | colex_bytes | bytes per colex index (1–8). `1` when 3^(w×h) ≤ 255; `4` up to 4×3; `8` for 4×4. |
| 8 | 1 | moves_bytes | bytes per move bitmap = `ceil((w×h + 1) / 8)`. The `+1` is for the pass bit. |
| 9 | 3 | reserved | zero |
| 12 | 4 | record_count | u32 LE, number of position records |
| 16 | 4 | slice_ko | u8 LE, ko point at this slice (always `255` = NONE for artifact-slice dumps). Padding: 3 zero bytes. |
| 20 | 4 | slice_passes | u8 LE, passes counter at this slice (always `0` for artifact-slice dumps). Padding: 3 zero bytes. |
| 24 | 4 | payload_crc32 | u32 LE, CRC-32 of all records (bytes from offset 28 to end−4) |

#### 4.6.3 Record format

Each record describes the legal-move set for one (position, side) pair at the
nominated slice (ko=NONE, passes=0 — the artifact slot).

| offset | size | field | description |
|---|---|---|---|
| 0 | colex_bytes | colex_idx | u64 LE, colex index of the position |
| colex_bytes | 1 | side | `1` = Black to move, `2` = White to move |
| colex_bytes+1 | moves_bytes | move_bitmap | bit `i` = 1 iff moving to cell `i` is legal. Bit `w×h` = pass is legal. Bits beyond `w×h+1` are zero. |

**Record size** = `colex_bytes + 1 + moves_bytes`.

**Move bitmap encoding:** cells are numbered 0..w×h−1 in row-major order
(row 0, cells 0..w−1; row 1, cells w..2w−1; etc.). Bit 0 is the LSB of
byte 0. Pass is bit `w×h`. A position with only the pass bit set (no stone
placements legal AND pass legal) is distinct from one with no bits set
(neither placements nor pass legal — this shouldn't occur for legal positions
under basic-ko rules, since pass is always legal after the opponent has not
just passed; but the format does not enforce this).

**Example:** 2×2 goban, w×h = 4, moves_bytes = ceil(5/8) = 1 byte.
- Bit 0 = cell 0 (top-left)
- Bit 1 = cell 1 (top-right)
- Bit 2 = cell 2 (bottom-left)
- Bit 3 = cell 3 (bottom-right)
- Bit 4 = pass
- Bits 5–7 = zero

#### 4.6.4 Dump scope and slicing

The dump records positions at the **artifact slice**: `ko = NONE (255), passes = 0`.
This is the same slice the artifact's stored values live at (§4.2). For each
position in the dump, the legal-move set is generated with no ko-forbidden
point (since the artifact slot has `ko=NONE`).

For exhaustive dumps (2×2, 3×2 per §6a), every legal position for each side
is included. For sampled dumps (3×3+), the positions are drawn from the
compact slot set (passes ∈ {0,1}) at the `ko=NONE, passes=0` slice.

#### 4.6.5 Solver-side generation

The solver's dump utility generates this file by:
1. Iterating over legal positions for each side at the artifact slice.
2. For each position: generate legal moves using the solver's basic-ko rules
   engine (the same code path the solver uses during retrograde fixpoint).
3. Write the record to the output file.
4. After all records: compute and append the CRC-32.

The solver dump utility is a separate invocation mode of the retrograde
solver, not part of the battery. It shares the solver's move-generation code
(the code being tested) and can therefore be written quickly (~50–100 lines).

#### 4.6.6 Battery-side reading

The battery's I11 reader:
1. Opens the dump file, verifies magic `SMD1`, version `1`.
2. Verifies `w`, `h` match the goban under test.
3. Verifies `slice_ko == 255`, `slice_passes == 0`.
4. Reads and CRC-validates all records.
5. For each record: decodes the colex index, generates the battery's own
   legal-move set (using its independently re-implemented rules engine per R8),
   and compares the two bitmaps.
6. Records any mismatches with example colex indices.

**Comparison:** two move bitmaps are equal when all bits 0..w×h match. Extra
bits (beyond w×h+1) in either bitmap are ignored. If the battery's bitmap has
bits set that the solver's doesn't (or vice versa), it's a mismatch.

#### 4.6.7 File naming and provenance

Dump files are named `<descriptor>-<goban>.smd1`, e.g.:
- `oracle-3x2-exhaustive.smd1` — 3×2 exhaustive dump against `artifacts/oracle-3x2.wzo`
- `oracle-4x4-sample-s31337-n50000.smd1` — 4×4 sample (seed=31337, n=50000)

The dump file's complete provenance (solver binary version, artifact
SHA-256, invocation arguments, seed, sample size) is recorded in a
sidecar JSON file with the same stem (`.smd1.json`). The battery's
header record reports `solver_dump_sha256` and `solver_dump_format: "SMD1"`.

The battery does NOT generate dump files — it only reads them. The dump
generation is the solver maintainer's responsibility; the format defined
here is the contract between the two components.

## 5. Goban size parameterisation

The goban size argument `2x2`–`4x4` is parsed at startup and drives:

1. **Colex dimensions:** `w × h` for `rank_from_pos` / `pos_from_rank`.
2. **Total address space:** `total = 3^(w×h)` — validates against artifact header.
3. **§6a matrix:** which invariants are applicable, and which mode (E/S/G/n/a),
   **further resolved by `artifact_kind`** (see §5a).
4. **I5 graph size:** vertices = `(board, side, ko_point)` reachable triples,
   per `i5-feasibility.md` §2 **option A** (the spec's adopted budget). Pass
   edges are terminal-only cut-edges: pass transitions always increase the pass
   counter and never create cycles, so cutting the graph at passes≥1 preserves
   cycle-reachable classification. At 2×2, committed all-seed V = 282, E = 508
   (`docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py`). At 4×4, **51,419,046**
   vertices `[GLOBAL.H1-CENSUS:PROVEN]`. The 99,133,036 compact-slot count
   (option B, with passes folded in) is twice the budget; the spec and the memo
   both adopt option A. See `i5-feasibility.md` §2, §4, and §9 for the full
   definition, memory plan, and the 3×2 validation gate (compare options A and
   B, confirm identical cycle-reachable sets).
5. **I11 sampling threshold:** exhaustive at 2×2/3×2; sampled at ≥3×3
   (population TBD in V-8 at 3×3 and 4×3 — no committed census figure matches
   the I11 state-set definition; the 4×4 figure, 99,133,036 compact slots
   `[4x4.BASICKO-TIE:MEASUREMENT]`, is the only calibrated population and
   comes from `i5-feasibility.md` §2).
6. **I8 applicability:** 2×2 only.

The harness resolves invariants for a goban by consulting the §6a matrix at
startup, further filtered by `artifact_kind`. Invariants not applicable to the
goban (I8 at 3×2+) or not applicable to the artifact kind (I3, I10 on WZO1)
report `status: "not_applicable"`, `mode_declared: "not-applicable"`, and do not
run.

### 5a. WZO1-specific §6a resolution

On WZO1 (`artifact_kind: "pinned-v"`), the following invariants are
`not_applicable` because the single-value columns lack L/H bracket pairs:

| invariant | reason |
|---|---|
| **I3** (L ≤ H) | No L/H columns to compare — single V column only. |
| **I10** (TIE median) | No L/H columns — the median check requires all three of (L, TIE, H). |

The following invariants report a reduced value set on WZO1:

| invariant | WZO1 limitation |
|---|---|
| **I1** (pin census) | `L_eq_H` only (derivable from KO_SENSITIVE bit). `pin_T`/`pin_L`/`pin_H` require WZO2. |
| **I4** (Bellman residual) | Residual restricted to KO_SENSITIVE-clear slots only. KO_SENSITIVE-set slots excluded (no L/H to compute residual against). |

All twelve invariants are fully computable on WZO2 (`artifact_kind: "bracket"`).

### 5b. Consequences for the spec and acceptance criteria

§5a settles, inside the design, that I3 and I10 are `not_applicable` on WZO1.
This has implications the design must state plainly rather than absorb silently:

**Spec §6a impact.** The spec's sixty-cell matrix (12 invariants × 5 gobans)
marks I3 and I10 as **E** (exhaustive) at all five gobans. On the A2 artifact
set — every in-scope artifact is WZO1 (verified, §1) — those ten cells are
unreachable. I1's five cells are reachable but report `L_eq_H` only, not
`pin_T`/`pin_L`/`pin_H`. The reachable cell count on WZO1 is **50** (60 − 10
for I3/I10), of which I1's five are reduced-value. The spec's "sixty cells"
count and its §6a I1/I3/I10 rows require amendment for the WZO1 sprint, or the
battery must declare a WZO2 dependency for those rows.

**Acceptance criterion A3.** A3(a) requires `L==H=2220, pin_T=298, pin_L=34,
pin_H=34` over 2,586 states and `2232/322/34/34` over 2,622 states at 3×2.
A3(b) requires `L==H=68,350, pin_T=1,248, pin_L=2,080, pin_H=2,080` at 3×3.
Under §5a the battery can produce `L_eq_H` at both gobans but **none of the
three pin figures** — `pin_T`, `pin_L`, `pin_H` require L/H bracket columns
that WZO1 does not store. A3(a) and A3(b) as written are unachievable against
the A2 artifact set. The `L_eq_H` component is the only reproducible part.

**Two options, neither of which this design chooses:**

| option | what | cost | when |
|---|---|---|---|
| **Wait for WZO2** | Defer I3, I10, and the full I1 pin census to the sprint where oracle-v2 ships bracket artifacts. The WZO1 battery reports `not_applicable` for I3/I10 and `L_eq_H`-only for I1. A3(a)/(b) pin figures are deferred. | No new code; A3(a)/(b) become WZO2-gated acceptance criteria. | WZO2 sprint. |
| **Solver-side L/H dump** | Run the retrograde solver in a dump mode that emits L/H values for every legal slot into a sidecar file (the same shape as I11's `solver_dump_path`). The battery loads this sidecar alongside the WZO1 artifact and computes the full pin census and I3/I10 from it. | ~150–250 lines in the battery (sidecar loader, same format as I11's dump) + a solver dump mode (~100 lines). | M2/V-7 (table invariants) would need the sidecar path. |

**This is a G1/G2 agenda item for the human, not a design decision.** The
battery's schema (§3.6) already defines all WZO2 fields; no unfreeze is needed
either way. The choice affects which acceptance criteria are applicable at
sprint review and whether V-7 needs a sidecar path. Until the human rules, the
battery ships with §5a's resolution: I3/I10 `not_applicable`, I1 `L_eq_H`
only.

## 6. Invariant dispatch

### 6.1 Invariant interface

Each invariant module (V-7 through V-9) exports a single function:

```zig
pub fn check(
    gpa: Allocator,
    goban: GobanSize,
    cols: ?*const ArtifactColumns,
    refs: ?*const ReferenceData,
    opts: CheckOptions,
) CheckResult;
```

Where:

- `GobanSize` is `struct { w: u8, h: u8 }`.
- `ArtifactColumns` is the loaded artifact. `null` for I5 all-legal runs with no artifact.
- `ReferenceData` is the loaded reference file. `null` if `--reference` was not passed.
- `CheckOptions` carries `seed: u64`, `sample_size: ?u64`, `i5_graph: ?I5Graph`, and `allow_mode_deviation: bool`.
- `CheckResult` is the invariant-specific result (see §3.3).

The harness iterates over selected invariants, calls each, collects results,
writes the JSON Lines stream (including streaming proposed rows after each
invariant completes), and emits the trailer. The harness owns exit-code
aggregation.

**No `fixture_mode`:** fixtures are V-10's domain. The battery does not have a
`--no-fixture` flag or a `fixture_mode` parameter — known-bad fixtures are run
by V-10 as separate harness invocations against fixture artifacts, not as an
internal self-check mode.

### 6.2 Invariant-to-module mapping

| invariants | module | file |
|---|---|---|
| I1, I2, I6, I12 (WZO1); I1, I2, I3, I6, I10, I12 (WZO2) | M2 (table invariants) | `src/vb_table.zig` |
| I4, I7, I8, I9, I11 | M3 (fixpoint invariants) | `src/vb_fixpoint.zig` |
| I5 | M4 (graph invariant) | `src/vb_graph.zig` |

The harness itself is `src/verify_battery.zig`. All four files are new; none
imports from solver modules (spec R8). Shared utilities (colex, rules engine,
artifact loader, JSON writer, reference data parser) live in `src/vb_common.zig`.

### 6.3 I5 special handling

I5 is the only invariant that can run without an artifact (`--i5-graph all-legal`
with `--i5-only`). When I5 runs with an artifact, it reads only the `fb`/`fw`
columns (KO_SENSITIVE flags), not the value columns.

When invoked as `--i5-only --i5-graph all-legal`, the harness skips artifact
loading entirely. The header record has `artifact_kind: null`,
`artifact: null`, `artifact_sha256: null`.

## 7. RSS measurement

Per spec A6, the battery reports peak RSS per invocation and per invariant.

**Linux:** read `/proc/self/status` **`VmHWM`** field (peak resident set size
— high water mark). `VmRSS` is current RSS and would miss intra-invariant peaks.

**macOS:** `task_info` with `MACH_TASK_BASIC_INFO` → `resident_size_max`
(maximum resident set size reached).

If RSS measurement fails (non-Linux, non-macOS, or permission denied),
`rss_hwm_after_mb` is `null` — this is not an error.

The harness reads the HWM before the first invariant and after each
invariant. The post-invariant HWM is recorded as `rss_hwm_after_mb` in the
result record. **This is a running maximum, not a per-invariant peak:** the
HWM is monotonic, so the value after invariant *n* is the maximum over
invariants 1..*n*, not the peak of invariant *n* alone. A consumer wishing to
estimate invariant *n*'s contribution should compute the delta:
`hwm_after[n] − hwm_after[n−1]` (with `hwm_after[0]` = the baseline reading
before the first invariant). After all invariants complete, the final HWM is
recorded as the invocation-level `rss_hwm_after_mb` in the trailer record
(§3.4).

The battery should also **predict** its I5 allocation before Phase 3 (per
`i5-feasibility.md` §5.2) and refuse to start if the prediction exceeds the
**measured available headroom** (VmHWM subtracted from the 4 GB runner cap),
not a compile-time constant. The prediction is reported in the I5 result's
`error` object if the check triggers a fallback. The comparison is:
`predicted_alloc_mb + current_VmHWM_mb > 4096` → fallback.

## 8. Concurrency notes

Per spec R7, the battery does not self-throttle. It is the Orchestrator's
responsibility (with human backstop) to ensure at most two 4×4-scale invocations
are in flight project-wide. The battery runs single-threaded per invocation;
concurrency across gobans and artifacts is achieved by running multiple
`verify-battery` processes, not by internal threading.

## 9. Error handling summary

| scenario | exit code | exit_class | emitted |
|---|---|---|---|
| All invariants pass | 0 | pass | header + result records + trailer |
| One invariant fails (artifact-bad) | 1 | artifact-bad | header + result records + trailer |
| One invariant disagrees with register (reference-bad), none artifact-bad | 2 | reference-bad | header + result records + trailer |
| Artifact fails to load | 3 | battery-bad | minimal header + error result + trailer |
| SHA-256 mismatch | 3 | battery-bad | minimal header (with computed SHA-256) + error result + trailer |
| OOM during invariant | 3 | battery-bad | header + results for completed invariants + error result + trailer |
| Invalid goban size | 3 | battery-bad | minimal header + error result + trailer |
| Unknown flag | 3 | battery-bad | minimal header + error result + trailer |

**Partial results:** When the battery encounters a fatal error partway through
(battery-bad), it emits results for all invariants that completed before the
failure, streams proposed rows for those completed invariants (each with
`run_incomplete: true`), emits the error result, the trailer, and exits 3.
The consumer (V-13 fleet runner) should treat any invocation with exit 3 as
incomplete — green cells from that run are not promotable until a clean re-run.

## 10. Proposed-row emission rules

1. `--proposed-rows <path>` is a separate file, not interleaved with stdout.
2. One row per (invariant, goban, artifact) cell that actually ran — even if
   `status` is `skipped` or `not_applicable`. This records which cells have
   been evaluated. The `artifacts_in_scope` and `artifact_index` fields tell
   V-14 whether the §6a cell is complete or partial.
3. Rows are written after each invariant completes (streamed), not batched at
   the end. This ensures rows for completed invariants survive a later crash.
   Rows emitted on a battery-bad run carry `run_incomplete: true`.
4. Each row carries `evidence_path: "docs/evidence/BATTERY/fleet.md"` — the
   fleet run's aggregate evidence file. V-13 is responsible for writing that
   file; the proposed rows are its input.
5. Rows for I5 are emitted once per goban, not once per artifact (spec S1).
   The `artifact` field is `null` and `artifacts_in_scope` reports the full
   count of in-scope artifacts for that goban.

## 11. Implementation notes

### 11.1 JSON writing

The battery uses `std.json` for writing JSON Lines output. The risk of a
hand-rolled escaping defect (quotes, backslashes, newlines, non-ASCII in
artifact paths, error messages, and `claim_text`) outweighs the allocation
cost of `std.json.stringify` at ~60 invocations × ~13 records. The battery
SHALL include a round-trip test: write a fixture record containing quotes,
backslashes, newlines, and non-ASCII characters; parse it back with
`std.json.parse`; assert equality.

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
- **Register absorption** — that is V-14. The battery computes `reference-bad`
  itself; V-14 absorbs the verdict rather than deriving it.
- **WZO2 bracket format and loading** — oracle-v2's design. The battery loads
  WZO1 only and errors cleanly on WZO2. The schema carries `artifact_kind`,
  `format`, and `format_version` so WZO2 support can be added without a schema
  unfreeze.
- **The independent re-implementation (A5)** — V-11, which reads this schema
  but not the battery source.
- **The 3×2 census reconciliation (V-R)** — the 2,586/2,622 denominator spread
  and 1,724/1,704/1,678 cycle-reachable spread. The battery handles both
  denominators as valid state sets; reconciliation is a separate task whose
  output updates the reference file.

## 13. Revision notes (rev 1 vs original)

This revision resolves the pass-1 audit (Opus 5/V-5, NEEDS-FIX). Changes:

**Blockers resolved:**
- **B1:** Value schemas restructured for WZO1 reality. I3 and I10 declared
  `not_applicable` on WZO1. I1 reduced to `L_eq_H` only. I4 defined as residual
  on KO_SENSITIVE-clear slots. WZO2 fields defined but absent on WZO1. §5a
  added with the WZO1-specific §6a resolution.
- **B2:** Reference data mechanism added (§2.5). `--reference` flag, JSON file
  schema, SHA-256 in header. Battery computes reference-bad itself. §3.5 I1
  contradiction deleted.

**Critical resolved:**
- **C1:** `exit_class` enum completed: `pass`, `artifact-bad`, `reference-bad`,
  `battery-bad`. `skipped` and `not_applicable` map to `exit_class: "pass"`.
  `status` values expanded: added `reference-disagreement` for reference-bad
  results.
- **C2:** RSS reads VmHWM (Linux) / resident_size_max (macOS). Trailer record
  added (§3.4) with invocation-level peak, duration, exit code, and per-class
  counts. Truncation detector.
- **C3:** Cell cardinality resolved: result records and proposed rows are
  per-artifact. §6a cell is V-13's aggregate. `artifacts_in_scope` and
  `artifact_index` fields added to proposed rows.
- **C4:** `artifact_kind`, `format`, `format_version` added to header, result,
  and proposed-row records.

**Must-fix resolved:**
- **M1:** `--no-fixture` flag and `fixture_mode` deleted. Fixtures are V-10's
  domain.
- **M2:** I5 denominator pinned: KO_SENSITIVE-set legal slots examined.
  `nodes`/`edges`/`sccs_*` are graph-shape fields, not the ratio.
- **M3:** I5 exit_class rules rewritten as ordered list covering all five
  gobans; spec §7 cited only for 3×2 beyond-spread escalation.
- **M4:** I9 given `numerator`/`denominator` (anchors checked / anchors committed).
- **M5:** I6 field renamed `union_legal` → `legal_positions_total`.
  `oeis_a094777` → `oeis_legal_reference` (nullable, with citation).
  Denominator clarified as dense 3^(w×h) position count.
- **M6:** `mode` split into `mode_declared` and `mode_actual`.
  `scope_once_per_goban` boolean added. `deviation` field on mismatch.
  `--sample-size` rejected on §6a-exhaustive cells without
  `--allow-mode-deviation`.
- **M7:** `artifact_legal_count` corrected: 489 (not 289). All-legal formula
  replaced with graph-definition reference to `i5-feasibility.md` §2.
- **M8:** Header field table added with explicit nullability. Minimal header
  specified for pre-load failures. `seed` default changed to fixed 31337.
  `--seed auto` for PID+time. `argv` field added for exact replay.

**Should-fix resolved:**
- **S1:** `status: "reference-disagreement"` added for reference-bad results.
  `fail` reserved for artifact-bad.
- **S2:** Naming convention normalised: enum values use hyphens
  (`artifact-bad`, `reference-bad`, `battery-bad`, `not-applicable`,
  `reference-disagreement`).
- **S3:** Duplicated fields removed — `seed`/`sample_size`/`mode` at top level
  only; `value` objects do not repeat them. `i5_graph` in header only.
- **S4:** JSON writing switched to `std.json` with mandatory round-trip test.
- **S5:** Proposed rows streamed per-invariant (not batched); `run_incomplete`
  field on battery-bad partial runs.
- **S6:** Seed default fixed to 31337; `--seed auto` for non-determinism.
- **S7:** R8 test boundary specified: separate binary, adjudicated comparison.
- **S8:** `<artifact>` made effectively optional; empty string `""` when not
  needed; prose clarified on exactly when loading occurs.
- **S9:** Line estimate given as range (600–900); `util.out` discipline added
  as fourth re-implemented subsystem.
- **S10:** I7 given separate pass and fail examples; I11 example corrected to
  3×3 (sampled per §6a).

**Could-fix resolved:**
- **Cf1:** Header field `artifact_rules_id` cites §4.2 (battery's own spec).
- **Cf2:** R8 boundary stated as code-sharing, not prose-novelty. Shared
  `std` library use acknowledged as correct.
- **Cf3:** `--version` flag added.
- **Cf4:** I5 `calibration` extended with `nodes_expected`, `edges_expected`,
  and 3×2 `max_scc_expected: 1676` each with citation.

## 14. Revision notes (rev 2 vs rev 1)

This revision resolves the rev-1 re-audit (T147/Opus 5, NEEDS-FIX). Changes:

**Critical resolved:**
- **R-C1:** §5b added — consequences for spec §6a and acceptance criterion A3.
  States plainly that A3(a)/(b) pin figures are unachievable on WZO1, names the
  reachable cell count (50 on WZO1), presents two options (wait for WZO2, or
  solver-side L/H dump) with cost estimates, and marks the choice as a G1/G2
  agenda item for the human.

**Must-fix resolved:**
- **R-C2:** §2.3 exit-0 row corrected: `exit_class` values `skipped` and
  `not-applicable` (which are `status` values, not `exit_class` values) removed;
  the row now says every result has `exit_class: "pass"` with the parenthetical
  noting status mapping.
- **R-M1:** I5 exit rule 3 now correctly tests `cycle_reachable` against the
  committed spread (1,724/1,704/1,678 — cycle-reachable set sizes), not
  `ko_sensitive_not_cycle_reachable`. A note explains that the spread values are
  `cycle_reachable` counts and that `ko_sensitive_not_cycle_reachable > 0` is
  the gate condition for both rules 3 and 4.
- **R-M2:** §5 item 4 rewritten — deleted the arithmetically-wrong
  multiplicative formula (57×2×3×2 = 684 ≠ 282); states vertices by definition
  as `(board, side, ko_point)` reachable triples per `i5-feasibility.md` §2
  option A; cites the spec-adopted 51,419,046 budget
  `[GLOBAL.H1-CENSUS:PROVEN]`; notes option B (99,133,036) is twice the budget
  and rejected by both spec and memo. §7's memory prediction already references
  `i5-feasibility.md` §5.2 which uses option A's budget.
- **R-M3:** I11 population figures at 3×3 (73,674) and 4×3 (2,009,694) replaced
  with "TBD in V-8" — neither matches a committed census figure under any
  natural state-set definition. The 4×4 figure (99,133,036) is retained with its
  provenance citation.
- **R-M4:** (a) I7 fail example recomputed from a single consistent scenario:
  `numerator` = `terminals_with_dtt_neq_0` = 16,543,210;
  `non_terminals_with_dtt_255` = 99,133,036 − 16,543,210 = 82,589,826. §2.4
  stderr example updated to match (16,543,210/99,133,036). (b) Duplication rule
  enforced: `i5_graph` removed from I5's `value` object, `sample_size` /
  `sample_seed` removed from I11's `value` object.

## 15. Revision notes (rev 3 vs rev 2)

```
Author:   DSPro/T156 · 2026-07-31
Status:   PROPOSED (rev 3) — resolves rev-2 re-audit (T151) should-fix
          carry-overs AC-S2, AC-S5 before Gate 2 freeze.
Inputs:   docs/epic-01-markovian/sprints/verify-battery/archive/design-M1-audit-rev2.md (T151) §4
```

This revision resolves five should-fix carry-overs from the rev-2 re-audit
(T151, PASS with AC-S2/S5 before Gate 2 freeze). Changes:

**Should-fix resolved:**
- **AC-S2:** Per-invariant RSS field renamed `peak_rss_mb` → `rss_hwm_after_mb`
  in all schema locations (result record, trailer, error result, field tables).
  §7 prose rewritten — states clearly that `rss_hwm_after_mb` is a running
  maximum (monotonic HWM), not a per-invariant peak, and documents the delta
  formula (`hwm_after[n] − hwm_after[n−1]`) for consumers who need
  per-invariant estimates.
- **AC-S5a:** `deviation` and `error` fields added to §3.3 common field table
  with types and nullability.
- **AC-S5b:** Trailer field table (§3.4) gained a `nullable` column. All rows
  populated; `rss_hwm_after_mb` marked `yes`.
- **AC-S5c:** `seed` type changed from `u64|string` to `u64` in the header
  field table. New `seed_source: "fixed"|"auto"` field added so consumers do
  not branch on the JSON type of `seed`. Header JSON examples (minimal and
  full) updated with `"seed_source": "fixed"`.
- **AC-S5d:** `artifact_index` in §3.5 proposed-row field table changed from
  `no` to `yes` (nullable); description updated to state `null` for I5
  once-per-goban rows (which have no artifact).

## 16. Revision notes (rev 4 vs rev 3)

```
Author:   DSPro/T180 · 2026-08-01
Status:   PROPOSED (rev 4) — P3-A spec surgery: resolves GAP-1 through GAP-5
          from T172 blind re-implementation analysis.
Inputs:   untracked/T172-blind-analysis.md (DSPro/T172-w1) ·
          docs/epic-01-markovian/sprints/verify-battery/archive/T180-disposition.md
```

This revision resolves five gaps identified by the independent re-implementation
audit (T172, DELIVERED 2026-07-31). The companion spec amendment (rev 1→rev 2)
addresses GAP-1/3/4/5 in the invariant descriptions. Changes:

**GAP-2 (Minor — I6 field semantics):**
- I6 value schema fields renamed: `legal_both_sides` → `legal_black`,
  `legal_one_side_only` → `legal_white`. The old names misleadingly suggested
  mutually exclusive categories; the fields are per-side legality counts.
- I6 prose rewritten: explicit note that these are per-side counts, not a
  partition, and that `legal_positions_total` double-counts the overlap.

**GAP-3 (Moderate — I7 missing recurrence check):**
- Added `dtt_recurrence_violations: u64|null` field to I7 value schema.
- Pass example updated to include `dtt_recurrence_violations: 0`.
- Fail example updated with `dtt_recurrence_violations: null` (not computed —
  uniform-255 makes recurrence meaningless).
- Prose: `numerator` redefined as `terminals_with_dtt_neq_0 +
  (dtt_recurrence_violations ?? 0)`. Field is `null` when not computed.

**GAP-4 (Minor — I10 `tie_not_median` logically impossible):**
- I10 schema note replaced: documents that `tie_not_median` is always 0 under
  the three-value median definition (when TIE ∈ [L,H], median(L,TIE,H) = TIE
  trivially). Field retained for forward compatibility with a future
  distribution-median check.
- Pass condition clarified: `tie_below_L == 0 AND tie_above_H == 0`.

**GAP-5 (Critical — I11 dump format unspecified):**
- New §4.6: SMD1 solver-dump format specification. Complete binary format
  definition: header (28 bytes), per-position records (colex_idx + side +
  move_bitmap), CRC-32 footer. Specifies file structure, field layout,
  move-bitmap encoding, dump scope (artifact slice), solver-side generation
  procedure, and battery-side reading procedure.
- I11 value schema: added `solver_dump_format: "SMD1"` and
  `solver_dump_sha256` fields. Example path updated to `.smd1` extension.

**GAP-1 (Moderate — I4 WZO1 limitation):**
- Resolved in the companion spec amendment (I4 row now carries a parenthetical
  noting the KO_SENSITIVE child contamination limitation). No design change
  needed — the limitation was already acknowledged in the I4 `note` field.
