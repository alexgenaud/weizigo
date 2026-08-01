# findings/ — knowledge-capture findings format

**Created:** 2026-08-01 · **Design:** `docs/epic-01-markovian/sprints/knowledge-capture/pass0/design.md` · **Author:** DSPro/T194

## Purpose

One JSON file per task. Each file records what a worker found: claim status
changes proposed, new register rows proposed, and the evidence backing them.
This directory is the machine-readable bridge between task outputs and the
epistemic register (`docs/epistemic/CLAIMS.md`).

**Integrity rule:** A findings file MUST NOT be edited after the Orchestrator
ratifies absorption. If a later re-examination changes a verdict, it is a NEW
task with a NEW findings file. The findings file is an immutable record.

## File naming

```
<TASKID>-<slug>.json
```

- `TASKID` — the `managent` task identifier (e.g. `T129`, `T172`)
- `slug` — short lowercase identifier for the primary finding (e.g. `qa027`, `gap5`)

## Schema

```json
{
  "task_id": "<string, required>",
  "date": "<YYYY-MM-DD, required>",
  "model": "<string, required>",
  "claims": [
    {
      "id": "<string, required>",
      "proposed_status": "<string, required>",
      "rationale": "<string, required>",
      "evidence_path": "<string, required>"
    }
  ],
  "new_rows": [
    {
      "id": "<string, required>",
      "legacy": "<string, required>",
      "goban": "<string, required>",
      "claim": "<string, required>",
      "status": "<string, required>",
      "evidence": "<string, required>",
      "depends_on": "<string, required>",
      "narrowed": "<number, required>",
      "wrong_answer_pass_rate": "<string, required>"
    }
  ],
  "notes": "<string, optional>"
}
```

## Field semantics

| Field | Required | Type | Description |
|---|---|---|---|
| `task_id` | yes | string | `managent` task identifier, e.g. `"T129"` |
| `date` | yes | string | ISO date `YYYY-MM-DD` when the finding was produced |
| `model` | yes | string | Model name, e.g. `"DSPro"`, `"Fable"`, `"Consul"` |
| `claims` | yes | array | Claim status changes proposed by this task |
| `claims[].id` | yes | string | Claim ID as registered in CLAIMS.md §2, e.g. `"QA-027"` |
| `claims[].proposed_status` | yes | string | One of: `PROVEN`, `CLAIMED`, `FALSE-AS-SCOPED`, `FALSE`, `UNTESTED`, `INTRACTABLE`, `MEASUREMENT` |
| `claims[].rationale` | yes | string | One-sentence justification for the status change |
| `claims[].evidence_path` | yes | string | Path to evidence file (relative to repo root), typically a PROVENANCE.md |
| `new_rows` | no | array | New CLAIMS.md rows proposed by this task |
| `new_rows[].id` | yes | string | Proposed claim ID (must follow the §1 ID scheme) |
| `new_rows[].legacy` | yes | string | Legacy ID or `"—"` if minted |
| `new_rows[].goban` | yes | string | Goban scope: `"all"`, `"n/a"`, `"2x2"`, etc. |
| `new_rows[].claim` | yes | string | The claim text (may contain markdown) |
| `new_rows[].status` | yes | string | Proposed status |
| `new_rows[].evidence` | yes | string | Evidence path(s) |
| `new_rows[].depends_on` | yes | string | Edge list, same format as CLAIMS.md depends-on column |
| `new_rows[].narrowed` | yes | number | Narrowing count (0 for new rows) |
| `new_rows[].wrong_answer_pass_rate` | yes | string | Rate or `"?"` |

## Status values

| Canonical | JSON value |
|---|---|
| PROVEN | `"PROVEN"` |
| CLAIMED | `"CLAIMED"` |
| FALSE-AS-SCOPED | `"FALSE-AS-SCOPED"` |
| FALSE | `"FALSE"` |
| UNTESTED | `"UNTESTED"` |
| INTRACTABLE | `"INTRACTABLE"` |
| MEASUREMENT | `"MEASUREMENT"` |

The `(definition)` pseudo-status is not a valid proposed status.

## Tooling

- **`weizigo-claimlint C7`** — scans `findings/*.json`, flags unabsorbed
  findings (status mismatches, missing new rows). Exits non-zero on
  unabsorbed findings.
- **`weizigo-absorb`** — reads a findings JSON file + CLAIMS.md, outputs
  JSON-Lines edit directives to stdout. Use `--dry-run` to suppress the
  absorption log append to `untracked/absorption.md`.
