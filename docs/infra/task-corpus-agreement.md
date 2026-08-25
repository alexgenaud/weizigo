# T819 — Task-corpus agreement audit

**Worker:** kimi-k2.7/T819 · **Date:** 2026-08-24 · **Status:** pass-with-findings  
**Deliverables:** `docs/infra/task-corpus-agreement.md`, `findings/T819-corpus-agreement.json`, `findings/T819-ruling.json`  
**Landmark:** advances L1 (measurement integrity) — the lattice’s three axes get a confidence number before anything is built on them.

## Executive summary

Two blind derivations of the same three axes (`task_type`, `task_scope`, `capabilities`) were run over the same 578-task corpus:

| lane | model | brief | method | corpus file |
|---|---|---|---|---|
| T817 | `deepseek-v4-flash` | seed from `tools/model-profiles.py`, then beat it | brief-aware five-stage classifier + legacy comparison | `docs/infra/task-corpus.jsonl` |
| T818 | `oxalpha` | build its own method | deterministic cascade over title/brief/deliverables/runs | `docs/infra/task-corpus-b/` |
| T820 | `deepseek-v4-pro` | byte-identical to T818’s | tiered scoring over title/slug, paths, body fallback | `docs/infra/task-corpus-c/` |

The amendment from the orchestration seat (2026-08-24) split the original single comparison into **two separate experiments**:

1. **T817 is the seeded-classifier experiment.** Its headline claim is that a brief-aware classifier scores **100%** on the 27-task self-declared+race-organizer holdout, versus the legacy classifier’s **78%**.
2. **T818 vs T820 is the clean two-model experiment.** Both had the identical brief; the only intended difference is the model.

**Headline results:**

- The T817 100% claim **reproduces on live data** (27/27). The legacy 78% claim **does not reproduce on live data**: the current `tools/model-profiles.py:classify_type` scores **19/27 = 70.4%** against the same holdout. The discrepancy is store drift/code drift between the committed snapshot and the live store.
- T818 vs T820 `task_type` exact agreement is **206/578 = 35.6%**. Against an independent third-party adjudicator (the T817 brief-aware rules applied to current briefs), T818 matches **176/578 = 30.4%** and T820 matches **210/578 = 36.3%**.
- `task_scope` raw class agreement is **0/578** because the two miners invented different taxonomies. The underlying size measurements agree well on `brief_bytes` (**564/578 = 97.6%**) but poorly on `unique_paths` (**283/578 = 49.0%**). The path disagreements are driven by a deterministic parse bug in T818 and by different brief-file disambiguation when multiple bundles exist.
- `capabilities` exact match is meaningless because the two vocabularies were derived independently. A semantic mapping shows only partial overlap; many high-frequency tags are unique to one miner.
- The `confidence` stamps are weakly predictive: the only reliable signal is when **both** miners mark `high` (84.4% agreement). A single `high` stamp is not enough — T818 `high` rows still disagree 27.3% of the time.

**Bottom line:** `task_scope` size (`brief_bytes`) is measurable and mostly reproducible once the brief file is pinned. `task_type` is not yet stable enough to build a model-delegation lattice on — two competent miners with the same brief agree only about one third of the time, and neither matches an independent adjudicator well. `capabilities` is the least settled axis: the vocabularies do not line up, so any cell-level claim built on them is currently a model-specific artifact.

---

## 1. The T819 adjudicator

Because the brief requires forming my own judgement before tallying scores, I built an independent third classifier that reads only the primary sources for each task:

- the bundle path from the kanban record,
- the brief title and body,
- the `<!--managent deliverables=… holds=… -->` comment,
- the run-record and findings presence counts.

The rules are the T817 brief-aware classifier as committed in `docs/evidence/T817-task-corpus/classify.py`, applied to the **live** briefs. It was calibrated by its author at 100% on the 24-task self-declared set, so it is a defensible, reproducible benchmark. Its main weakness is the same as any keyword classifier: it can over-read incidental vocabulary. I therefore treat its output as a *ruling*, not as ground truth.

For scope, I used the S07/T817 scope rules in `docs/evidence/T817-task-corpus/mine.py:scope_class`, which map deliverable/hold paths to `S1`–`S5` plus `S-unknown`.

The per-task rulings are stored in `findings/T819-ruling.json`.

---

## 2. Experiment 1 — T817: does seeding from the legacy classifier help?

### 2.1 The calibration set

The 27-task holdout is defined in `docs/evidence/T817-task-corpus/calib.py`:

- 24 self-declared types: `T323, T443, T776, T785, T803` (spec); `T382, T471, T592` (research); `T408` (infra); `T270` (battery); `T615–T624, T674, T683, T685, T687` (audit).
- 3 protocol-known race organizers added as audit: `T447, T529, T626`.

### 2.2 Verification on live data

Re-running both classifiers against the live store and the current `tools/model-profiles.py`:

| classifier | right / total | accuracy | vs. T817 report |
|---|---|---|---|
| brief-aware (T817) | 27/27 | **100.0%** | matches claimed 100% |
| legacy (`model-profiles.py`) | 19/27 | **70.4%** | **does not match** claimed 78% |

Legacy misses on live data: `T443 spec→research`, `T776 spec→audit`, `T785 spec→audit`, `T803 spec→audit`, `T471 research→audit`, `T408 infra→implement`, `T270 battery→infra`, `T626 audit→infra`.

### 2.3 Why the legacy number shifted

T817 reported the legacy classifier at 21/27 = 78% and the brief classifier at 27/27 = 100%. On the live store the brief classifier still scores 27/27, but the legacy classifier scores 19/27 = 70%. The difference is not in the keyword rules (the legacy code is unchanged) but in the store fields the legacy classifier reads: it uses only the bundle slug, `note`, and `verdict_note`. Those fields have drifted for several calibration tasks since the T817 snapshot was taken (`docs/infra/task-corpus.md §0`). The 100% claim for the brief-aware classifier is robust to that drift because it reads the full brief; the 78% legacy claim is not.

**Consequence:** published model-suitability arguments that depend on the legacy 78% baseline should be re-keyed to the current store, or the brief-aware 100% baseline should be used instead. The two numbers are not interchangeable.

---

## 3. Experiment 2 — T818 vs T820: clean two-model comparison

### 3.1 Coverage and honesty

| | T818 (`oxalpha`) | T820 (`deepseek-v4-pro`) |
|---|---|---|
| universe | 579 ids (`_sys` excluded, `--bundle` included) | 578 ids (`_sys` and `--bundle` excluded) |
| rows processed | 579/579 | 578/578 |
| remainder declared | none | none |
| `task_type UNKNOWN` | 73 (12.6% of tasks) | 12 (2.1% of tasks) |
| `task_scope UNKNOWN` | 0 (own taxonomy has no UNKNOWN) | 24 (brief-less tasks) |
| blind claim | source code contains no read of T817/T820 outputs; notes declare blindness | source code contains no read of T817/T818 outputs; notes declare blindness |

Both miners declared their gaps honestly. T818’s larger UNKNOWN count is a direct consequence of its cascade stopping when no rule fires; T820 falls back to body keywords and therefore produces fewer UNKNOWNs.

### 3.2 `task_type` agreement

**Exact agreement: 206/578 = 35.6%.**

Confusion matrix (rows = T818, columns = T820):

| T818 \\ T820 | UNKNOWN | audit | battery | implement | infra | integration | orchestration | research | spec | row total |
|---|---|---|---|---|---|---|---|---|---|---|
| UNKNOWN | 12 | 4 | 38 | 2 | 7 | 1 | 3 | 4 | 2 | 73 |
| audit | 0 | 39 | 15 | 20 | 24 | 3 | 4 | 7 | 22 | 134 |
| battery | 0 | 5 | 55 | 25 | 19 | 5 | 6 | 17 | 3 | 135 |
| implement | 0 | 1 | 2 | 25 | 14 | 0 | 1 | 2 | 2 | 47 |
| infra | 0 | 2 | 3 | 0 | 41 | 0 | 1 | 0 | 0 | 47 |
| integration | 0 | 3 | 1 | 17 | 20 | 5 | 3 | 3 | 3 | 55 |
| orchestration | 0 | 1 | 0 | 14 | 9 | 0 | 15 | 1 | 4 | 44 |
| research | 0 | 2 | 2 | 7 | 9 | 0 | 2 | 1 | 1 | 24 |
| spec | 0 | 0 | 5 | 1 | 0 | 0 | 0 | 0 | 13 | 19 |
| **column total** | 12 | 57 | 121 | 111 | 143 | 14 | 35 | 35 | 50 | **578** |

**Key pattern:** T818’s “battery” label collapses into almost every T820 class, and T820’s “infra” label collapses into many T818 classes. The two miners disagree on what the dominant type of work is in this project: T818 sees many battery/race tasks, T820 sees many tooling/infra tasks.

### 3.3 Adjudicated type accuracy

Against the T819 ruling:

| miner | matches / total | accuracy |
|---|---|---|
| T818 (`oxalpha`) | 176/578 | 30.4% |
| T820 (`deepseek-v4-pro`) | 210/578 | 36.3% |

T820 is modestly better overall. The per-class shape is more informative than the single score:

**T818 precision / recall vs. T819 ruling:**

| class | predicted | gold | precision | recall |
|---|---|---|---|---|
| audit | 134 | 207 | 55.2% | 35.8% |
| battery | 135 | 44 | 14.1% | 43.2% |
| implement | 47 | 55 | 10.6% | 9.1% |
| infra | 47 | 132 | 51.1% | 18.2% |
| integration | 55 | 18 | 23.6% | 72.2% |
| orchestration | 44 | 55 | 47.7% | 38.2% |
| research | 24 | 23 | 4.2% | 4.3% |
| spec | 19 | 23 | 52.6% | 43.5% |
| UNKNOWN | 73 | 21 | 12.3% | 42.9% |

**T820 precision / recall vs. T819 ruling:**

| class | predicted | gold | precision | recall |
|---|---|---|---|---|
| audit | 57 | 207 | 82.5% | 22.7% |
| battery | 121 | 44 | 2.5% | 6.8% |
| implement | 111 | 55 | 21.6% | 43.6% |
| infra | 143 | 132 | 53.1% | 57.6% |
| integration | 14 | 18 | 57.1% | 44.4% |
| orchestration | 35 | 55 | 65.7% | 41.8% |
| research | 35 | 23 | 22.9% | 34.8% |
| spec | 50 | 23 | 38.0% | 82.6% |
| UNKNOWN | 12 | 21 | 16.7% | 9.5% |

**Findings from the shapes:**

- T820 is much better at `infra`, `spec`, and `orchestration` (the classes where deliverable-path prefixes are decisive), but it massively overcalls `battery` (121 predictions vs. 44 gold) and `infra`.
- T818 overcalls `battery` and `audit`, and undercalls `infra`. Its `integration` recall is high (72.2%) because it routes many “absorb/wire” tasks there, but its `integration` precision is low.
- Both miners perform poorly on `research`: T818 recalls only 4.3%, T820 recalls 34.8% but with low precision.

### 3.4 `task_scope` agreement

**Raw class agreement: 0/578.** The two miners used different taxonomies:

- T818: `micro`, `single-doc`, `code-touch`, `multi-artifact`, `heavy-compute`.
- T820: `XS`, `S`, `M`, `L`, `XL` by `brief_bytes`.

Mapped to the T819 S07 classes:

- T818 `single-doc` → mostly `S4` (205) and `S-unknown` (30).
- T818 `code-touch` → mostly `S2` (80) and `S4` (18).
- T820 `M` → mostly `S4` (95) and `S2` (49).
- T820 `S` → mostly `S4` (80) and `S2` (23).

**Size measurement agreement:**

| measurement | exact matches | rate |
|---|---|---|
| `brief_bytes` | 564/578 | 97.6% |
| `unique_paths` | 283/578 | 49.0% |

**Causes of the 14 `brief_bytes` mismatches:**

T818 selects the brief file by globbing the bundle directory and taking the first sorted match. T820 uses the `bundle` field from the kanban record. For tasks with multiple brief arms, T818 reads a different arm than the canonical one:

- `T316`: T818 reads the `-arm-A-review.md` variant (2,441 B); T820 reads the canonical delegation-architecture experiment bundle (6,474 B).
- `T403`: T818 reads the correction-audit follow-up; T820 reads the `gtp-boardsize-desync` bundle.
- `T441`: T818 reads the `AUDIT-audit` arm; T820 reads the observation-layer bundle.
- `T554`: T818 reads the `consolidate-spec` arm; T820 reads the `fable-owns-pass1` bundle.
- `T723`: T818 reads the `design-audit` arm; T820 reads the `science-arm-sprint` bundle.
- `T746`: T818 reads a later handover document under `docs/status/` (20,452 B); T820 reads the console-measurement bundle (2,198 B).
- `T795`: the canonical bundle points outside the working tree into disposable scratch; T818 cannot find it, while T820 follows the bundle field.

**Cause of the 295 `unique_paths` mismatches:**

T818 parses the `<!--managent … -->` line with a regex that captures `deliverables=([^->]*)`. This stops at the first `-` character, so any deliverable path containing a hyphen is truncated. Example: `T226` has deliverable paths beginning `docs/epic-01-markovian/…`; T818 records only `docs/epic` and undercounts the path count, while T820 counts both paths correctly. This is a deterministic parse bug, not a model error.

### 3.5 `capabilities` agreement

Exact name match per task is impossible because the two miners derived independent vocabularies. The semantic mapping is:

| T817 tag | nearest T818 tag(s) | nearest T820 tag(s) | shared? |
|---|---|---|---|
| `code-writing` | `zig-engine-code`, `python-tooling` | `engine-code` | partial |
| `test-authoring` | `test-first-mandate` | `test-first` | yes |
| `citation-verification` | `evidence-and-claims` | `evidence-discipline` | partial |
| `census-counting` | `schema-design`? | `data-mining` | weak |
| `arithmetic-over-corpus` | `statistical-method` | `numerical-measurement` | yes |
| `adversarial-refutation` | — | `audit-verification` | weak |
| `long-horizon-execution` | `long-running-compute` | `session-persistence` | yes |
| `discrimination-saying-no` | — | `independence` | weak |
| `long-document-coherence` | — | — | no |

**Tags found by only one miner (frequency > 10):**

- T818 only: `cross-agent-coordination` (252), `statistical-method` (210), `schema-design` (181), `long-running-compute` (173), `git-fleet-discipline` (41).
- T820 only: `independence` (157), `deployment` (149), `sub-delegation` (49), `spec-writing` (61), `orchestration` (56).
- T817 only: `discrimination-saying-no` (282), `citation-verification` (143), `adversarial-refutation` (95), `long-document-coherence` (6).

Because each vocabulary is tied to its miner’s keyword rules, a capability cell in the lattice cannot yet be compared across models. The axis needs a shared, committed vocabulary before it supports delegation decisions.

### 3.6 Confidence calibration

Both miners stamped `high`/`medium`/`low` confidence per row. The question is whether the stamp predicts agreement with the other miner or with the T819 ruling.

**Agreement by joint confidence (T818 row, T820 column):**

| T818 \\ T820 | high | medium | low |
|---|---|---|---|
| high | 103/122 = 84.4% | 35/60 = 58.3% | 14/27 = 51.9% |
| medium | 6/83 = 7.2% | 8/107 = 7.5% | 20/80 = 25.0% |
| low | 1/7 = 14.3% | 1/49 = 2.0% | 18/43 = 41.9% |

**Disagreement rate by single-miner confidence:**

| miner | high | medium | low |
|---|---|---|---|
| T818 | 57/209 = 27.3% | 236/270 = 87.4% | 79/99 = 79.8% |
| T820 | 102/212 = 48.1% | 172/216 = 79.6% | 98/150 = 65.3% |

**Interpretation:**

- The only reliable signal is when **both** stamp `high`: agreement jumps to 84.4%.
- A single `high` is weak: T818 `high` rows disagree 27% of the time; T820 `high` rows disagree 48%.
- `medium` and `low` from either miner are essentially uninformative — both have disagreement rates above 65%.
- Neither confidence field correlates cleanly with correctness against the T819 ruling.

---

## 4. Merged corpus recommendation

For each task and each field, the merged corpus should record the level of certainty:

| field | agreement 2/2 | adjudicated (T819 ruling) | UNDECIDABLE | note |
|---|---|---|---|---|
| `task_type` | 206 tasks | 372 tasks | 0 tasks | T819 ruling used where miners disagree |
| `task_scope.class` | 0 tasks | 578 tasks | 0 tasks | different taxonomies; map both to S07/T819 S-class |
| `task_scope.brief_bytes` | 564 tasks | 14 tasks | 0 tasks | 14 mismatches caused by brief-file disambiguation |
| `task_scope.unique_paths` | 283 tasks | 295 tasks | 0 tasks | 295 mismatches caused by T818 hyphen parse bug + hold/deliverable counting |
| `capabilities` | N/A | N/A | 578 tasks | vocabularies are not aligned; no merged value yet |

**Recommendation:**

- **Do not build the model-delegation lattice on `capabilities` yet.** The vocabularies are model-specific.
- **Use `task_scope.brief_bytes` as the most reproducible size signal**, after fixing brief-file disambiguation to use the kanban `bundle` field.
- **Use `task_type` only with `agreement` and `adjudicated` flags attached.** A 35.6% inter-miner agreement is too low for a hard cell assignment. The 206 2/2 rows can be treated as relatively stable; the other 372 should carry uncertainty.

---

## 5. Conclusion: which axis is ready?

- **`task_scope` size (`brief_bytes`)** is almost ready. The 97.6% exact match shows the measurement is mostly mechanical once the right file is read. The remaining 2.4% is a tooling issue (brief disambiguation), not a conceptual issue.
- **`task_type`** is not ready. Two blind derivations from the same briefs agree only 35.6% of the time, and neither matches an independent adjudicator well. The axis needs either a shared, test-first classifier with a larger, operator-ratified ground-truth set, or it should be represented as a distribution rather than a single label.
- **`capabilities`** is the least ready. The vocabularies are independent coinages; a capability claimed by only one miner is the most common case. Before the lattice can use this axis, the project must adopt a single, committed capability taxonomy and re-tag all tasks through it.

---

## 6. Model-perf ledger rows

The three intended `audit`/derivation ledger rows were prepared but **not committed** because `docs/infra/model-task-metrics.jsonl` is currently held by `T843` (`claude-sonnet-5`). The rows are recorded in `findings/T819-corpus-agreement.json` under `proposed_model_task_metrics_rows` and should be appended once T843 clears its hold:

- `deepseek-v4-flash` / T817: holdout brief accuracy 27/27; live legacy accuracy 19/27.
- `oxalpha` / T818: adjudicated type match 176/578.
- `deepseek-v4-pro` / T820: adjudicated type match 210/578.

---

## 7. Evidence and reproducibility

- Primary corpora: `docs/infra/task-corpus.jsonl`, `docs/infra/task-corpus-b/chunk-*-m6.jsonl`, `docs/infra/task-corpus-c/chunk-*.jsonl`.
- Adjudicator code: `docs/evidence/T817-task-corpus/classify.py` and `mine.py` (re-used as the T819 ruling instrument).
- Calibration script: `docs/evidence/T817-task-corpus/calib.py`.
- Findings: `findings/T819-corpus-agreement.json`, `findings/T819-ruling.json`.
- T818/T820 method descriptions: `docs/infra/task-corpus-b/notes.md`, `docs/infra/task-corpus-c/notes.md`.
- T818 parse bug: `docs/infra/task-corpus-b/derive.py:parse_deliverables` uses `deliverables=([^->]*)`, which truncates at hyphens.
