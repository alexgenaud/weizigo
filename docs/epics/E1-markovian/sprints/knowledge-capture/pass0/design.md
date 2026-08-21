# design.md — knowledge-capture tooling design

Revision: 1 · Status: DRAFT · Tier: sprint · Author: DSPro/T188

## 1. Findings JSON format (R1)

### 1.1 File layout

```
findings/
  README.md                  — format spec (canonical copy of this §1)
  T129-qa027.json            — example: QA-027 falsified at 4×4
  T172-gap5.json             — example: GAP-5 critical finding
```

One file per task. Name: `<TASKID>-<slug>.json`. The slug is a shortlowercase
identifier for the primary finding. The task ID is the `managent` T-ID.

### 1.2 Schema

```json
{
  "task_id": "T129",
  "date": "2026-07-31",
  "model": "DSPro",
  "claims": [
    {
      "id": "QA-027",
      "proposed_status": "FALSE-AS-SCOPED",
      "rationale": "Falsified at 4×4: certified fraction = 10.71%, not 100% by construction",
      "evidence_path": "docs/evidence/QA-027/4x4/PROVENANCE.md"
    }
  ],
  "new_rows": [
    {
      "id": "CODE.VB-BLINDGAPS",
      "legacy": "—",
      "goban": "n/a",
      "claim": "T172's blind reimplementation found five specification gaps...",
      "status": "PROVEN",
      "evidence": "docs/epics/E1-markovian/sprints/verify-battery/archive/T172-blind-analysis.md",
      "depends_on": "",
      "narrowed": 0,
      "wrong_answer_pass_rate": "?"
    }
  ],
  "notes": "Single finding: QA-027 was falsified. The 100%-by-construction claim failed exactly where brackets appear."
}
```

### 1.3 Field semantics

| Field | Required | Type | Description |
|---|---|---|---|
| `task_id` | yes | string | `managent` task identifier, e.g. `"T129"` |
| `date` | yes | string | ISO date `YYYY-MM-DD` when the finding was produced |
| `model` | yes | string | Model name (not worker ID), e.g. `"DSPro"`, `"Fable"`, `"Consul"` |
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
| `notes` | no | string | Free-form context for the Orchestrator |

### 1.4 Status names

The `proposed_status` field uses the canonical status names from CLAIMS.md §1:

| Canonical | JSON value |
|---|---|
| PROVEN | `"PROVEN"` |
| CLAIMED | `"CLAIMED"` |
| FALSE-AS-SCOPED | `"FALSE-AS-SCOPED"` |
| FALSE | `"FALSE"` |
| UNTESTED | `"UNTESTED"` |
| INTRACTABLE | `"INTRACTABLE"` |
| MEASUREMENT | `"MEASUREMENT"` |

The `(definition)` pseudo-status (`— (definition)`) is not a valid proposed
status — definitions are not findings.

### 1.5 Integrity rule

A findings file MUST NOT be edited after the Orchestrator ratifies absorption.
If a task produces multiple findings, they go in one file. If a later
re-examination changes a verdict, it is a NEW task with a NEW findings file
(not an edit of the old one). The findings file is an immutable record of what
a specific task found at a specific time.

---

## 2. claimlint C7 — unabsorbed findings check (R2)

### 2.1 What it checks

C7 scans `findings/*.json` and for each claim in each file, verifies that
CLAIMS.md §2 reflects the proposed status. A finding is **unabsorbed** when:

1. **Status mismatch:** The claim ID exists in the register but its status
   differs from the proposed status. Example: findings says
   `QA-027 → FALSE-AS-SCOPED`, register says `QA-027 → CLAIMED`.

2. **Missing row:** The claim ID is in `new_rows[]` but NOT in the register.
   The finding proposed a new row that was never added.

3. **Stale new-row:** The claim ID is in `new_rows[]` AND in the register but
   with a different status than proposed. The row was added but the finding's
   intent was altered.

A finding is **absorbed** when all its claim IDs are in the register with
matching statuses. C7 reports only unabsorbed findings.

### 2.2 Integration into claimlint

C7 is added to `src/claimlint.zig` as a new check section, between C6
(cite-tag verification) and A (narrowing smells). The check:

1. Reads all `*.json` files from the `findings/` directory.
2. Parses each as a `Finding` struct.
3. For each claim in `finding.claims`, looks up `claim.id` in the register.
   - If not found: reports `UNKNOWN CLAIM ID` (this is an error — the
     finding references a claim the register doesn't know).
   - If found with different status: reports `UNABSORBED: <id> findings says
     <proposed>, register says <actual>`.
4. For each new row in `finding.new_rows`, looks up the id in the register.
   - If NOT found: reports `UNABSORBED NEW ROW: <id>`.
   - If found with different status: reports `UNABSORBED: <id> new-row
     proposed <proposed>, register has <actual>`.
   - If found with matching status: silent (absorbed).
5. Reports totals: files scanned, claims touched, unabsorbed count.

### 2.3 Exit code

C7 failures exit non-zero. Tier: **load-bearing** — same as C1 (orphans),
C2 (dangling evidence), and C6 (cite-tags). An unabsorbed finding means the
register is out of date with respect to committed evidence, which is exactly
the gap msg 071 was created to prevent.

### 2.4 Implementation notes

- JSON parsing: use `std.json` if Zig 0.16's churn permits; otherwise a
  hand-rolled parser for this flat, fixed-schema format is ~80 lines.
- The `findings/` directory is resolved relative to the repo root (same as
  CLAIMS.md). Default: `findings/`.
- If `findings/` does not exist or is empty, C7 reports `0 files, 0 claims`
  and exits 0 — no findings means nothing to absorb.
- The check can be disabled with `--no-c7` for runs that intentionally
  operate on a partial register.

### 2.5 Calibration

C7 MUST carry a synthetic calibration case (like the existing C1b/C5/C6
synthetics). The calibration:

1. Creates a temporary directory with a single findings JSON:
   ```json
   {
     "task_id": "T999",
     "date": "2026-08-01",
     "model": "TestModel",
     "claims": [
       {
         "id": "GLOBAL.CALPARENT-DEAD",
         "proposed_status": "FALSE-AS-SCOPED",
         "rationale": "Synthetic calibration",
         "evidence_path": "none"
       }
     ]
   }
   ```
   The synthetic register has `GLOBAL.CALPARENT-DEAD` as `FALSE-AS-SCOPED`
   (matching — absorbed) and adds a row `GLOBAL.CAL-SHOULDBE-FALSE` as
   `PROVEN` (with the finding proposing `FALSE-AS-SCOPED` — unabsorbed).
2. C7 must catch exactly 1 unabsorbed finding (the status mismatch) and exit
   non-zero.
3. C7 run against findings that match the register must exit 0.

The existing `CAL_SYNTHETIC` register in claimlint is extended with two extra
rows for the C7 calibration, keeping the pattern consistent.

---

## 3. Absorption tool — `weizigo-absorb` (R3)

### 3.1 Behaviour

```
weizigo-absorb <findings.json> [--dry-run]
```

1. Reads the findings JSON file.
2. Reads `docs/epistemic/CLAIMS.md`.
3. For each claim in the findings:
   a. Parses the CLAIMS.md register to find the row for that claim ID.
   b. If the register status differs: emits an edit directive.
   c. If the claim ID is not in the register: reports an error (new claims
      go in `new_rows[]`, status changes go in `claims[]`).
4. For each new row in the findings:
   a. Checks the CLAIMS.md register for existing entry with that ID.
   b. If none: emits an add-row directive with the insertion point.
   c. If one exists with different status: emits an edit directive (the
      add was absorbed but altered — flag for Orchestrator review).
   d. If one exists with matching status: silent (already absorbed).
5. Outputs a JSON-Lines stream to stdout, one directive per line.
6. Appends one line to `untracked/absorption.md` (unless `--dry-run`).

### 3.2 Output format (JSON Lines)

Each line is a JSON object with directive type and edit details:

**Status-change directive:**
```json
{
  "directive": "edit_status",
  "claim_id": "QA-027",
  "current_status": "CLAIMED",
  "proposed_status": "FALSE-AS-SCOPED",
  "line": 574,
  "old_cell_text": "CLAIMED",
  "new_cell_text": "FALSE-AS-SCOPED (at 4×4; 3×3 measured 100.00%)",
  "note": "The new_cell_text includes the parenthetical scope; edit the exact status prefix."
}
```

**New-row directive:**
```json
{
  "directive": "add_row",
  "claim_id": "CODE.VB-BLINDGAPS",
  "insert_after": "CODE.VB-STUBS",
  "section": "2.10",
  "row_text": "| `CODE.VB-BLINDGAPS` | — | n/a | ... | PROVEN (blind-reimplementation audit, committed) | ... |"
}
```

**No-op (already absorbed):**
```json
{
  "directive": "noop",
  "claim_id": "QA-027",
  "note": "Register already reflects proposed status FALSE-AS-SCOPED"
}
```

### 3.3 Status cell editing

The status column in CLAIMS.md uses a common pattern: `STATUS (scope qualifier)`.
Examples:

```
| CLAIMED |
| FALSE-AS-SCOPED (at 4×4; 3×3 measured 100.00%) |
| PROVEN (as scoped) |
| MEASUREMENT |
```

The tool matches the **status prefix** (the word before any parenthetical or
whitespace). When proposing an edit, it replaces the prefix only, preserving
any existing parenthetical qualifier. If the proposed status inherently carries
a qualifier (e.g. `FALSE-AS-SCOPED (at 4×4)`), the tool includes it in
`new_cell_text` and the Orchestrator decides.

### 3.4 New-row insertion

New rows are inserted after the last row in their section. The tool determines
the section by matching the `goban` field in the new row against the register's
board column. Insertion point: after the last row with the same board value.

If the findings specify `insert_after` (a claim ID to insert after), the tool
uses that instead.

### 3.5 Edge case: duplicate absorption

If a findings file has already been absorbed (all claims match), the tool
outputs only `noop` directives and does NOT append to the absorption log.
The log line is idempotent — it is only written when at least one edit or
add-row directive is emitted.

### 3.6 Implementation

- `src/absorb.zig` — standalone binary, ~300 lines.
- Reuses the `parseRegister()` function from `src/claimlint.zig`. Extract it
  into a shared module (`src/claims_register.zig`) or duplicate it (claimlint
  is already self-contained; duplication is acceptable for a tool this size).
- The CLAIMS.md table-editing logic uses line-level string matching: find the
  row's line number via the register parser's `Row.line` field, then perform
  a targeted replacement of the status cell.
- Markdown table cells are pipe-delimited. The status is in column 6 (0-indexed
  column 5 counting from the leading `|`). The edit replaces the text between
  the 5th and 6th pipe on that line.

### 3.7 Calibration (A2)

The tool must produce correct diffs for two test cases:

1. **T129/QA-027:** A findings file proposing `QA-027 → FALSE-AS-SCOPED`
   against a CLAIMS.md where QA-027 is still `CLAIMED`. The tool should emit
   exactly one `edit_status` directive for line 574, with `current_status:
   "CLAIMED"` and `proposed_status: "FALSE-AS-SCOPED"`.

2. **T172/GAP-5:** A findings file with `new_rows` containing
   `CODE.VB-BLINDGAPS` against a CLAIMS.md where that row does not exist.
   The tool should emit an `add_row` directive with the full row text
   matching what was committed (line 503 in the current CLAIMS.md), inserted
   after `CODE.VB-STUBS`.

Both test cases are run as part of `zig build test` for the absorb module.

---

## 4. Absorption log integration (R4)

### 4.1 Format

The absorption log (`untracked/absorption.md`) format, as defined by msg 071:

```
<TASKID> <DATE> <MODEL> <CLAIM-IDS-ABSORBED> CLAIMS:<yes/no> model-perf:<yes/no>
```

The absorption tool appends one line per non-dry-run invocation that produces
at least one edit or add-row directive.

### 4.2 Auto-populated fields

| Field | Source |
|---|---|
| TASKID | `finding.task_id` |
| DATE | Current date (ISO) — the absorption date, not the finding date |
| MODEL | `finding.model` (the worker model) |
| CLAIM-IDS-ABSORBED | Space-separated list of claim IDs from the findings file |
| CLAIMS:yes | Hard-coded to `yes` (the tool only runs when CLAIMS.md is being updated) |
| model-perf | Hard-coded to `no` (the absorption tool doesn't know about model-perf; the Orchestrator updates model-perf separately) |

### 4.3 Idempotency

If the findings file has already been absorbed (all claims match, all new rows
exist), the tool does NOT append to the absorption log. This prevents duplicate
entries from re-runs.

### 4.4 Dry run

`--dry-run` suppresses the log append. The diff is still emitted to stdout.
Use case: Orchestrator reviewing proposed changes before applying them.

---

## 5. File map

```
src/
  claimlint.zig           — extended with C7 check + synthetic calibration
  absorb.zig              — new: absorption tool binary
  (or claims_register.zig — new: shared register parser, if extracted)

findings/
  README.md               — format spec (canonical, replicated from design §1)
  T129-qa027.json         — calibration fixture: QA-027 falsification
  T172-gap5.json          — calibration fixture: GAP-5 critical gap

untracked/
  absorption.md           — existing; auto-appended by absorb tool

docs/epics/E1-markovian/sprints/knowledge-capture/pass0/
  spec.md                 — existing
  plan.md                 — this sprint's build plan
  design.md               — this file
```

## 6. Test strategy

### 6.1 claimlint C7

- **Unit:** Parse findings JSON files with known-good and known-bad contents.
  Verify correct detection of status mismatches, missing new-rows, and
  already-absorbed findings.
- **Integration:** Run full claimlint pipeline with synthetic register +
  synthetic findings. C7 must report exactly 1 unabsorbed finding and exit
  non-zero.
- **Calibration:** The existing claimlint calibration section gains a
  C7 block (known-bad: synthetic findings disagree with synthetic register;
  known-good: matching findings and register, C7 silent).

### 6.2 Absorption tool

- **Unit:** Parse findings JSON, parse CLAIMS.md register, compute edit
  directives. Verify directives match expected for T129 and T172 fixtures.
- **Unit:** New-row insertion point computation — test that
  `CODE.VB-BLINDGAPS` is inserted after `CODE.VB-STUBS` in section 2.10.
- **Unit:** Idempotency — running the tool twice produces `noop` directives
  on the second run and does not double-append to the absorption log.
- **Integration:** Run tool on T129 fixture against a pre-absorption CLAIMS.md
  snapshot. Verify the output directives, when manually applied, produce
  the post-absorption CLAIMS.md (which is the current committed state).

### 6.3 Acceptance (from spec.md)

| Acceptance | Test |
|---|---|
| A1 — T129 gap flagged by claimlint | claimlint C7 calibration: synthetic findings + register where QA-027 is CLAIMED → C7 reports unabsorbed, exits non-zero |
| A2 — correct diff for T172 GAP-5 | Run `weizigo-absorb findings/T172-gap5.json` → diff matches CODE.VB-BLINDGAPS row as committed in CLAIMS.md:503 |
| A3 — claimlint exits 0 after absorption | Apply the tool's edits to CLAIMS.md, re-run claimlint → C7 passes (0 unabsorbed) |
