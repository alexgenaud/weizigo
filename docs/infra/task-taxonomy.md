# task-taxonomy — the frozen type / scope / capability vocabulary (T786)

**Status:** frozen by T786 (2026-08-24). **Landmark:** advances L1 (the dashboard tells the truth).
**Why frozen, not derived:** the corpus run (T817 brief-aware, T818/T820 blind, T819 adjudication,
`docs/infra/task-corpus.jsonl`) measured the law: where the vocabulary was closed, agreement was
computable and a deterministic reader was perfect (27/27 on the self-declared hold-out); where it
was open, two models produced answers that could not even be compared. A classification without a
closed, pre-registered vocabulary measures vocabulary invention, not classification.

## 1. type — 9 legal values, required at registration

```
audit · infra · orchestration · implement · battery · integration · research · spec · UNKNOWN
```
- `managent add` and `managent suggest` **refuse** a row without one of these; the error names the
  legal values. `--type` supplies or overrides the bundle's `type=` key (a legacy bundle predating
  the key may be typed by the flag alone).
- **UNKNOWN is a legal value, never a fill** — a dispatcher who genuinely cannot classify declares
  it; the corpus backfill propagates corpus-UNKNOWN as absence (renders UNKNOWN).
- Stored as `task_type` on the row; `show` and `status --json` render it (null = UNKNOWN).

## 2. scope — the S1–S5 binning rule (mechanical, recomputable)

Inputs are the row's own facts only: D = unique declared deliverables (bundle `deliverables=` /
`Deliverables:` body), H = declared holds, T = stored type, id+title words. Precedence, top wins:

```
if D = ∅                       → UNKNOWN   (residue R1: no declared deliverables)
if T = orchestration ∧ id|title has console|seat|triage|inbox|landmark
                               → S5 (console)
if |{p∈D: src/}| ≥ 2
  ∨ |{p∈D: code}| ≥ 3          → S3 (feature)
  ∨ |{p∈H: engine file}| ≥ 2   (engine = src/{retro,oracle,rules,solve}.zig)
if |{p∈D: code}| ≥ 1           → S2 (leaf)
if ∀p∈D: read-only:            (read-only = findings/ | docs/ | root non-code)
    |D| = 1 ∧ D[0] ∉ findings/ → S1 (atom)      else → S4 (sweep)
else                           → UNKNOWN   (residue R2: mixed facts fit no bin)
```

code = `src/` | `tools/` | `bin/` | `tests/` | `build.zig` (S07 amendment 1: non-src code counts).
The classes are the S07 delegation lattice adopted by the corpus (task-corpus.md §3); the rule is
the store-recomputable compression of it (corpus-calibrated at 91.7% where facts are comparable).
Stored as `scope_class` at `add`; recomputed by `backfill-taxonomy` — a scope that cannot be
recomputed from the store is not a scope.

## 3. capabilities — adopted from T900, earned not inferred

Vocabulary: the eight dimensions of `docs/infra/races/capability-metrics.md` (T900, derived from
race outcomes — what actually distinguished good results from bad):
Tier-1 screening `investigative-effort · discernment · fabrication · canary-recall`;
Tier-2 judged `category-fidelity · control-design · self-reported-limits · substance-accuracy`.
**Not backfilled onto unraced tasks**: a capability reading is earned by a graded task (recorded in
`docs/infra/model-task-metrics.jsonl` with grader provenance), never inferred from a brief's verbs —
the brief-phrase source produced 88% low-confidence and zero comparability. The kanban `caps` field
is a different thing (ROLES.md §4 dispatch tokens) and is untouched.

## 4. Enforcement & backfill

- **At registration:** `add`/`suggest` require `type=` (or `--type`); `add` computes `scope_class`
  from the row's own facts. A row cannot be created without a type — the one-time backfill is not a
  standing duty.
- **`managent backfill-taxonomy`** joins the committed corpus's `type.brief` onto store rows that
  carry none: bundle-declared real type wins, then corpus real type; UNKNOWN propagates (never
  guessed); a stored type is never overwritten or blanked on corpus disagreement (reported). Then
  recomputes `scope_class` for every row. Idempotent — re-running reproduces every bin exactly.

## 5. Backfill census (live store, 2026-08-24, 532 rows)

| column | filled | left UNKNOWN | residue (named) |
|---|---|---|---|
| type | 447 (440 corpus, 3 bundle, 4 already) | 85 (6 corpus-UNKNOWN, 79 absent from snapshot) | 2 stored-vs-corpus disagreements reported (STANDING-* declared infra vs classifier) |
| scope | 503 (S1 4, S2 135, S3 27, S4 310, S5 27) | — | 29 (R1 no-deliverables 5, R2 mixed 24) |

## 6. Null controls (wired into `zig build test`, `tools/regression-task-taxonomy.sh`)

1. **Discrimination:** materially different facts land in different bins — findings-only S4 vs lone
   docs S1 vs two-src S3 vs docs+findings S4 vs orchestration+seat S5 vs empty-facts UNKNOWN.
2. **Stability:** re-running `backfill-taxonomy` reproduces every row's type and scope exactly
   (asserted on the live store and in the regression).
3. **Refusal:** `add`/`suggest` without a legal type exit non-zero naming the legal values; no row
   is registered.
