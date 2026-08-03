# Retirement ruling sheet — 116 proposed retirements

Task: T318 · Role: worker · Model: glm-5.2 · Date: 2026-08-03

## What this is


One line per proposed retirement from `register-tree-map.md` §2, grouped by the existing six
families. DIRECTION reserves retirement to the human; this sheet is what the human rules on.
**Nothing is retired by this row** — no register edit, no status change. The `RULING:` column
is left empty for the human.

Each row carries: the claim ID and its **current register status** (from `docs/epistemic/CLAIMS.md`,
parsed at HEAD on 2026-08-03), the **family reason** (one line, copied from §2 — not re-argued
per row), **what is lost if it is retired**, and an empty `RULING:` column.

### How "what is lost" was cross-checked

Two mechanical checks, both reported per row, plus a judged flag:

- **In-register dependents** — parsed from the `dependents` column of the retiring row in
  `CLAIMS.md`, then filtered to those whose own `tree` cell is **not** `RETIRED` (i.e. still
  live). The edge kind (`e:` evidenced-by / `d:` derives-from / untyped / dependents-only) is
  read from the *live* row's `depends-on` column. A `dependents-only` edge means the retiring
  row's `dependents` column names the live row, but the live row's `depends-on` does not name
  the retiring row — an asymmetric register entry that breaks nothing on retirement.
- **External `docs/` citations** — `grep` for the claim ID across every `docs/**/*.md` except
  `CLAIMS.md`, `register-tree-map.md`, and this sheet. These are counted and three example paths
  shown. A high count usually means historical narrative (PROGRESS.md, ADRs), not a live
  logical dependency; it is reported so the human can see how widely the row is referenced.
- **⚑ sole-evidence flag (judged from the mechanical data)** — where a retiring row is the
  `e:` (evidenced-by) source for a live row whose status is still believed (PROVEN / CLAIMED /
  UNTESTED / MEASUREMENT, i.e. not FALSE-AS-SCOPED), it is flagged. Per the T318 bar, such a row
  is **not a retirement candidate** until the live row's `depends-on` is re-pointed; retiring
  it silently would leave a still-believed claim with a dangling evidence edge. Eight rows are
  so flagged.

## Summary counts


- Proposed retirements: **116** (reconciled to all four sources in `register-tree-map.md` §3.1).
- Sheet rows: **116** — equals the reconciled retirement count.
- Rows with ≥1 live in-register dependent: **27**.
- Rows flagged ⚑ sole-`e:`-evidence-for-still-believed: **8** —
  `3x3.ANCHOR`, `4x3.M3`, `4x4.ANCHOR`, `4x4.M4`, `4x4.M6`, `4x4.PARALLEL`, `CODE.UNDEF`,
  `GLOBAL.FIN-BRACKET`.
- Rows with no live dependent and no external citation (cleanest retirements):
  **0**.


## §2.1 ruleset-choice — 21 rows

**Family reason:** Evidences the choice of ruleset R (k=1 basic ko) by foreclosing the alternatives; the foreclosures are recorded decisions (AGENTS.md, AXIOMS §4), not requirements of Z under the fixed R — no tree node states them.


| ID | register status | what is lost if retired | RULING |
|---|---|---|---|
| `2x2.R1` | MEASUREMENT | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/PROGRESS.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `2x2.R3` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `3x2.R1` | MEASUREMENT | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/PROGRESS.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `3x2.R3` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x3.S3b` | UNTESTED | Live register dependents: `4x3.C1` ((dependents-only, asymmetric)). External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. | |
| `4x4.KO-RULE-NULL` | PROVEN (these two games) | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.R1` | CLAIMED | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.R3` | PROVEN (falsification) | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/PROGRESS.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.S3b` | UNTESTED | Live register dependents: `4x4.C1` ((dependents-only, asymmetric)); `4x4.C2` ((dependents-only, asymmetric)); `4x4.C3` ((dependents-only, asymmetric)). External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/PROGRESS.md (+1 more)) — historical narrative, not register edges. | |
| `GLOBAL.ADR0004-P1` | PROVEN | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/claimlint-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ANCHOR-DELTA` | CLAIMED | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/audits/AUDIT-REF-DSPro-2026-07-29.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.PSK-GAP` | PROVEN | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/PROGRESS.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.R1` | PROVEN (structural) | Live register dependents: `GLOBAL.REFRAME` ((dependents-only, asymmetric)). External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+3 more)) — historical narrative, not register edges. | |
| `GLOBAL.R2` | PROVEN (argument) + MEASUREMENT | External `docs/` citations: 12 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+9 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.R3` | FALSE-AS-SCOPED | External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+3 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.RNPLY-FORBID` | PROVEN | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/PROGRESS.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.RPLY` | PROVEN (falsification) | External `docs/` citations: 9 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+6 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.RPLY-RETRO` | CLAIMED | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.RPLY-TRAP` | PROVEN (argument) | External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+4 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.S3b` | CLAIMED | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-024` | CLAIMED | External `docs/` citations: 10 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+7 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |

## §2.2 old-artifact — 45 rows

**Family reason:** Measured or diagnosed the old writes-on PSK-era artifact(s); the theorem's table requirements are verified on the k=1 builds by the acceptance battery (I2/A2/A3/A5/A8/A9) and the Bellman-identity checks, not by this measurement — no tree node.


| ID | register status | what is lost if retired | RULING |
|---|---|---|---|
| `2x2.M4` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `3x2.M4` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `3x3.ANCHOR` | MEASUREMENT | ⚑ SOLE `e:` evidence for live still-believed row(s) `3x3.C1` (CLAIMED). Retiring leaves that row with a dangling evidence edge — per the T318 bar this is **not a retirement candidate** until the live row's `depends-on` is re-pointed to other evidence. Other live dependents: `3x3.C1` (e:evidence). External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+1 more)) — historical narrative, not register edges. | |
| `3x3.BRACKET` | MEASUREMENT | Live register dependents: `3x3.C3` ((dependents-only, asymmetric)). External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/research/ruleset-options.md (+2 more)) — historical narrative, not register edges. | |
| `3x3.M1` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `3x3.M4` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x3.BRACKET` | MEASUREMENT | Live register dependents: `4x3.C1` ((dependents-only, asymmetric)). External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+1 more)) — historical narrative, not register edges. | |
| `4x3.M1` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x3.M3` | MEASUREMENT | ⚑ SOLE `e:` evidence for live still-believed row(s) `4x4.D3` (UNTESTED). Retiring leaves that row with a dangling evidence edge — per the T318 bar this is **not a retirement candidate** until the live row's `depends-on` is re-pointed to other evidence. Other live dependents: `4x4.D3` (e:evidence). External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. | |
| `4x3.M4` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x3.TANGLE` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.ANCHOR` | MEASUREMENT | ⚑ SOLE `e:` evidence for live still-believed row(s) `4x4.C1` (UNTESTED). Retiring leaves that row with a dangling evidence edge — per the T318 bar this is **not a retirement candidate** until the live row's `depends-on` is re-pointed to other evidence. Other live dependents: `4x4.C1` (e:evidence). External `docs/` citations: 19 (e.g. docs/INDEX.md, docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md (+16 more)) — historical narrative, not register edges. | |
| `4x4.BRACKET` | MEASUREMENT | External `docs/` citations: 8 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+5 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.COMPLETE-2026-07-21` | FALSE-AS-SCOPED | Live register dependents: `GLOBAL.ADR0012-GATE` (d:derives). External `docs/` citations: 11 (e.g. docs/INDEX.md, docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md (+8 more)) — historical narrative, not register edges. | |
| `4x4.CYCLE-INSENS` | CLAIMED | External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+2 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.KO-CENSUS` | MEASUREMENT | Live register dependents: `4x4.D3` ((dependents-only, asymmetric)). External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/PROGRESS.md) — historical narrative, not register edges. | |
| `4x4.M1` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.M3` | MEASUREMENT | Live register dependents: `GLOBAL.H5c` ((dependents-only, asymmetric)). External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. | |
| `4x4.M4` | MEASUREMENT | ⚑ SOLE `e:` evidence for live still-believed row(s) `4x4.FP1-C3` (PROVEN (as scoped)). Retiring leaves that row with a dangling evidence edge — per the T318 bar this is **not a retirement candidate** until the live row's `depends-on` is re-pointed to other evidence. Other live dependents: `4x4.FP1-C3` (e:evidence); `GLOBAL.H4` ((dependents-only, asymmetric)). External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+4 more)) — historical narrative, not register edges. | |
| `4x4.M5` | PROVEN | External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+2 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.M6` | MEASUREMENT | ⚑ SOLE `e:` evidence for live still-believed row(s) `4x4.F2` (UNTESTED), `4x4.F3` (UNTESTED). Retiring leaves that row with a dangling evidence edge — per the T318 bar this is **not a retirement candidate** until the live row's `depends-on` is re-pointed to other evidence. Other live dependents: `4x4.F2` (e:evidence); `4x4.F3` (e:evidence). External `docs/` citations: 9 (e.g. docs/INDEX.md, docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md (+6 more)) — historical narrative, not register edges. | |
| `4x4.M6-EXCESS` | CLAIMED | Live register dependents: `4x4.F3` ((dependents-only, asymmetric)). External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+2 more)) — historical narrative, not register edges. | |
| `4x4.M6-FLOOR` | PROVEN (on the swept artifact) | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.M6-SCREEN` | CLAIMED | External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+3 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.PARALLEL` | MEASUREMENT | ⚑ SOLE `e:` evidence for live still-believed row(s) `4x4.B43` (MEASUREMENT). Retiring leaves that row with a dangling evidence edge — per the T318 bar this is **not a retirement candidate** until the live row's `depends-on` is re-pointed to other evidence. Other live dependents: `4x4.B43` (e:evidence). External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+1 more)) — historical narrative, not register edges. | |
| `4x4.SINGLE` | MEASUREMENT | Live register dependents: `GLOBAL.REFRAME` ((dependents-only, asymmetric)). External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. | |
| `4x4.TANGLE` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.VALBATTERY` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.WRITESOFF` | MEASUREMENT | Live register dependents: `4x4.F3` ((dependents-only, asymmetric)). External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+1 more)) — historical narrative, not register edges. | |
| `CODE.ADR0011-DTT` | CLAIMED | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/claimlint-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `CODE.WZO1-DTT-UNSET` | PROVEN (I7 across four gobans + independent spot-check + positive contrast artifact) | External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/PROGRESS.md (+3 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `CODE.WZO2-CHAINSHORT` | SUPERSEDED (2026-08-03, T269: true when written — the WZO2 chainability check WAS short-circuited; T261 later confirmed the code was fixed, `chainable_at_pos` now runs the real chain check for WZO2 in `src/gtp.zig`, so the row no longer describes the code. The register had no status for "true when written, overtaken by events" — this is its first use) | External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/ORACLE-V2/m4b-triage-T261.md (+2 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.C-1` | FALSE-AS-SCOPED | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.CHAIN-DEF` | — (definition) | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epic-01-markovian/sprints/project-restructure/pass0/backlog.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.CHAIN-KIND` | PROVEN | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.CHAIN-KO` | PROVEN | External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+4 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.CHAIN-LH` | PROVEN (on the audited artifacts) | Live register dependents: `4x4.FP1-C3` ((dependents-only, asymmetric)); `GLOBAL.H4` ((dependents-only, asymmetric)). External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.SESSION-CHOOSE/PROVENANCE.md (+4 more)) — historical narrative, not register edges. | |
| `GLOBAL.MAXGAP` | CLAIMED | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/decisions/0016-per-board-independence-empirical-vs-structural.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.T14.1` | CLAIMED | Live register dependents: `GLOBAL.REFRAME` ((dependents-only, asymmetric)). External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/README.md (+1 more)) — historical narrative, not register edges. | |
| `QA-005` | FALSE | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/critique-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-006` | FALSE | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/critique-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-007` | CLAIMED | Live register dependents: `4x4.F3` ((dependents-only, asymmetric)). External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/research/ko-sensitive-chainability.md (+3 more)) — historical narrative, not register edges. | |
| `QA-008` | UNTESTED | Live register dependents: `4x4.F3` ((dependents-only, asymmetric)). External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+2 more)) — historical narrative, not register edges. | |
| `QA-016` | FALSE | External `docs/` citations: 12 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+9 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-017` | CLAIMED | External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+2 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |

## §2.3 player — 24 rows

**Family reason:** The GTP player and play-time search are consumers of the table; the theorem asserts nothing about them — no tree node.


| ID | register status | what is lost if retired | RULING |
|---|---|---|---|
| `4x4.A-1` | FALSE-AS-SCOPED | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.A-3` | FALSE-AS-SCOPED (the player is not fresh-start-perfect in the ko-sensitive region: node's own V0 = −3, chosen child = −16) | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.GREEDY-BIAS` | CLAIMED | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.GTP-DEFECT` | PROVEN | External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+4 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.HISTPERF-CHEAP` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.REGR-CLIFF` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `4x4.REGR-SYM` | PROVEN | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL-INVSYM/proof-2026-07-30.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `CODE.GTP-LHSIDE` | PROVEN (reproduced at HEAD, four plies cross-checked; independently confirmed by T277) | External `docs/` citations: 5 (e.g. docs/evidence/ORACLE-V2/incompleteness-verify-T277.md, docs/evidence/ORACLE-V2/incompleteness-T266.md, docs/epistemic/PROGRESS.md (+2 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `CODE.UNDEF` | PROVEN | ⚑ SOLE `e:` evidence for live still-believed row(s) `4x4.B43` (MEASUREMENT). Retiring leaves that row with a dangling evidence edge — per the T318 bar this is **not a retirement candidate** until the live row's `depends-on` is re-pointed to other evidence. Other live dependents: `4x4.B43` (e:evidence); `4x4.B39` ((dependents-only, asymmetric)). External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/README.md (+4 more)) — historical narrative, not register edges. | |
| `GLOBAL.ADR0009-DTT` | PROVEN | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/claimlint-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ADR0014-DEAD` | CLAIMED | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL-S2/PROVENANCE.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.B-1` | FALSE-AS-SCOPED (as of the code at 2026-07-27) | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/research/corrections-2026-07-27.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H2` | UNTESTED | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.HYPOTHESES/PROVENANCE.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H3` | UNTESTED | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.HYPOTHESES/PROVENANCE.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H3-LOWERBOUND` | MEASUREMENT | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.HYPOTHESES/PROVENANCE.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H5` | CLAIMED | External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL-AUDITOR/PROVENANCE.md (+2 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H5a` | CLAIMED | External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+4 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H5a-CHILD` | CLAIMED | External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+3 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H5a-FALLBACK` | CLAIMED | External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.SESSION-CHOOSE/PROVENANCE.md (+3 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H5b` | CLAIMED | External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL-S2/PROVENANCE.md (+2 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.H5d` | CLAIMED | External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.HYPOTHESES/PROVENANCE.md (+4 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-002` | FALSE | External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+4 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-014` | UNTESTED | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/critique-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-020` | FALSE | External `docs/` citations: 11 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+8 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |

## §2.4 process — 9 rows

**Family reason:** Process rule, user decision, or superseded-status record; not a theorem requirement — no tree node.


| ID | register status | what is lost if retired | RULING |
|---|---|---|---|
| `CODE.STANDING-ABSORB` | PROVEN | External `docs/` citations: 1 (e.g. docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `CODE.STANDING-C3-DEAD` | PROVEN | External `docs/` citations: 1 (e.g. docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `CODE.STANDING-STATE-FRAGILE` | PROVEN | External `docs/` citations: 1 (e.g. docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `CODE.WZO2-UNRUN` | SUPERSEDED (2026-08-03, T269: true when written 2026-08-01 — the artifact was built (T192) and M4a ran (T193) the same day, so "no artifact exists and no acceptance has run" stopped being true within hours; superseded by `CODE.WZO2-PASSBIT`. The row's own prose said the register had no status for "true when written, obsolete now" — SUPERSEDED is that status) | Live register dependents: `4x4.G-CENSUS` ((dependents-only, asymmetric)); `4x4.D3` ((dependents-only, asymmetric)). External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+4 more)) — historical narrative, not register edges. | |
| `GLOBAL.ONEWRITER` | CLAIMED | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.RELEASEFAST` | PROVEN | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/claimlint-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.UD-1` | CLAIMED | External `docs/` citations: 8 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/README.md (+5 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.UD-2` | CLAIMED | Live register dependents: `4x4.S4` ((dependents-only, asymmetric)). External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/README.md (+1 more)) — historical narrative, not register edges. | |
| `GLOBAL.UD-3` | CLAIMED | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/README.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |

## §2.5 design — 14 rows

**Family reason:** Design rationale for the engine or a 5×N scaling projection; the theorem's requirements hold or fail independently of it — no tree node.


| ID | register status | what is lost if retired | RULING |
|---|---|---|---|
| `4x4.DRIVER` | MEASUREMENT | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ADR0002-SEQ` | UNTESTED | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ADR0005-SUBBOARD` | PROVEN | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/claimlint-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ADR0007-AB` | PROVEN | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/claimlint-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ADR0007-BACKEDGE` | PROVEN | Live register dependents: `GLOBAL.FP3` ((dependents-only, asymmetric)). External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+1 more)) — historical narrative, not register edges. | |
| `GLOBAL.ADR0009-SUCC` | PROVEN (design argument) | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/claimlint-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ADR0012-5X5` | CLAIMED (projection; ADR status is *proposed*, measurements pending) | External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+3 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ADR0012-LAYER` | PROVEN (arithmetic) | External `docs/` citations: 4 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.ADR0012-V1` | PROVEN | External `docs/` citations: 3 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/epistemic/claimlint-2026-07-28.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.F4-COST` | MEASUREMENT | External `docs/` citations: 5 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+2 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.FIN-BRACKET` | MEASUREMENT | ⚑ SOLE `e:` evidence for live still-believed row(s) `GLOBAL.H5c` (PROVEN (as an implication)). Retiring leaves that row with a dangling evidence edge — per the T318 bar this is **not a retirement candidate** until the live row's `depends-on` is re-pointed to other evidence. Other live dependents: `GLOBAL.H5c` (e:evidence). External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. | |
| `GLOBAL.FIN-NEARTERM` | MEASUREMENT | Live register dependents: `GLOBAL.ADR0010-CUT` ((dependents-only, asymmetric)). External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. | |
| `GLOBAL.FWD-INTRACT` | PROVEN | External `docs/` citations: 2 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `GLOBAL.SWEEPS` | MEASUREMENT | External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md (+3 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |

## §2.6 crisis-diagnostic — 3 rows

**Family reason:** Crisis-era diagnostic framing, refuted hypothesis, or withdrawn option; its role is historical — no tree node.


| ID | register status | what is lost if retired | RULING |
|---|---|---|---|
| `GLOBAL.ONEMISMATCH-DIAG` | CLAIMED | External `docs/` citations: 4 (e.g. docs/INDEX.md, docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md (+1 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-010` | CLAIMED | External `docs/` citations: 7 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/INDEX-claim-task.md (+4 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
| `QA-028` | FALSE | External `docs/` citations: 6 (e.g. docs/INDEX-claim-evidence.md, docs/INDEX-claim-deps.md, docs/infra/model-perf.md (+3 more)) — historical narrative, not register edges. No live register row depends on it (external citations are historical narrative only). | |
