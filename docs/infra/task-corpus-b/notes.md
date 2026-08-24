# T818 — corpus blind second pass: notes (method v6, complete)

Author: ox-alpha/T818 · 2026-08-23 · Landmark: advances L1 (the delegation-evidence lattice)

## Blind declaration

**I did not read T817's output.** I never opened `docs/infra/task-corpus.jsonl`,
`docs/infra/task-corpus.md`, or `findings/T817-*`, and I did not consult
`tools/model-profiles.py`. T817 the *task* appears as a row in my corpus (as every task must);
its row was derived only from the same sources every other row used.

## Universe and denominators

Universe = union of ids in `docs/infra/managent/tasks.json` + `archive.json`, minus `_sys`:
**579 tasks** (the brief said 573; the store grew by dispatch of T810–T818 between brief-writing
and claim time). 29 ids have **no brief on disk**; every such row is labelled accordingly.
All 12 production chunks were processed: **579/579 rows, no remainder.**

## Method v6 (stated for re-running; stamped on every row; source committed beside it)

The extractor/classifier is `derive.py` in this directory. It is deterministic: same inputs,
same rows. Sources (gitignored working-tree paths named inside fences, per the T424
fence exemption — a fenced path is an illustration of the query, not an
evidence citation):

```
briefs:    untracked/<id>-*.md   (else the record's bundle path)
runs:      untracked/runs/*.json       (<id>.json, <id>.<n>.json, <id>-*.json, bakeoff_<id>-*)
tokens:    untracked/tokens/tokens.jsonl
```

Per task it gathers: kanban record (live wins over archive on the 4 shared ids),
declared deliverables
parsed from the brief's `<!--managent … deliverables=…-->` comment unioned with `holds`,
run records and token rows as fenced above.

**task_type** — a priority cascade over case-folded title + first 4000 bytes of brief +
kanban note; first rule to fire wins, and its name is recorded verbatim in the row's
`task_type.basis`:

1. orchestration — seat handovers ("Orchestrator seat", ORCHA bundle), fleet-coordination
   vocabulary, sprint consoles;
2. battery — race lanes/batches (a lane is a compute run even when its brief discusses grading);
3. audit — audit/verify/grade/adjudicate/reproduce vocabulary in title or brief head;
4. spec — spec/proposal vocabulary in title, or a spec/design doc among deliverables;
5. integration — absorb/wire/smoke/deploy/migrate/GTP-compatibility vocabulary;
6. battery — exhaustive/sweep/golden-master/seeds vocabulary;
7. research — `?` in title, question-word openers, falsification/diagnosis/triage/decision
   vocabulary;
8. implement vs infra — code deliverables under `src/` → implement; `bin/`,`tools/`,`tests/unit`
   → infra; implementation verbs alone → implement at low confidence;
9. standing duties fall back on their verb (absorb → integration, run-a-checker → infra).

Confidence: high = title-level or structural signal; medium = single strong vocabulary hit;
low = verbs only or fallback.

**task_scope** — measured size: `brief_bytes`, unique declared paths, summed wall/cpu and max
RSS over run records, token totals. Class enumeration (proposed, defended below): `micro`
(≤2 paths, <1500-byte brief), `single-doc` (1–2 doc/findings paths), `code-touch` (source in
scope), `multi-artifact` (≥3 paths), `heavy-compute` (wall ≥1800 s or RSS ≥2000 MB). Precedence
heavy-compute > multi-artifact > code-touch > single-doc > micro. Defense: the classes partition
all 579 rows (no `unclassified`), each exceeds n=49 except micro (83) — none is degenerate — and
the precedence order reflects what actually dominates cost: compute > breadth > code > prose.

Distribution (m6): single-doc 279 · code-touch 118 · micro 83 · heavy-compute 53 ·
multi-artifact 50. Types: battery 135 · audit 134 · UNKNOWN 74 · integration 55 · infra 47 ·
implement 47 · orchestration 44 · research 24 · spec 19. Confidence: medium 270 · high 209 ·
low 100.

**capabilities** — inference all the way down (labelled as such in every row). Vocabulary
derived from recurring demands in the briefs; a tag fires when its rule matches the brief text
or declared paths. Ten tags:

| capability | rule (abridged) | examples |
|---|---|---|
| cross-agent-coordination | dispatch/delegate/relay/agreement-measurement content | ORCHA-FLASH, T203 (relocation sprint console), T253 (P0 spec+plan audit) |
| statistical-method | rates, denominators, sampling, agreement | DCLAIM, DRPLAY, T255 (P1 design audit) |
| schema-design | authors/amends a schema, ledger, manifest | T267 (key-agreement invariant row schema), T426 (assertion-ledger spec), DCLAIM |
| long-running-compute | runner/heartbeat/wall-budget, or wall ≥1800 s | T258 (V-13 verify-battery fleet run), T662 (16 attempts, 9521 s), T257 (agreement matrix) |
| evidence-and-claims | docs/evidence/, CLAIMS.md status changes | DCLAIM, T260/T261 (fleet-failure triage) |
| python-tooling | bin/, tools/, .py artifacts in scope | T272 (claimlint gate), T268 (deployment silently broken), T282 |
| zig-engine-code | src/*.zig in declared scope | T227 (acceptance-check defects), T252 (differential oracle harness), T239 |
| git-fleet-discipline | named staging, hooks, isolation | T278 (shared git index hazard), T280 (make the gate gate), T281 (install pre-commit gate) |
| test-first-mandate | brief mandates failing-test-first | T714 (controls before the fix), T790 (S09 module test contracts), T792 |
| operator-relay | copy/paste payload boundaries, relay formatting | T304 (phase-order ruling sync), T490 (worker concern channel), T685 |

Rows firing no rule carry `none-inferred` (107 rows) rather than an invented tag.

## Version history (append-only discipline)

m1 probe (chunk-00.jsonl, kept) → m2 full pass → m3 race/console/diagnosis rules → m4 `?`-titles
→ m5 case-folding → **m6 production** (= m5 classifier + run-record glob fixed for
`<id>.<n>.json` attempt files). Every generation's chunk files remain on disk with sha256 in
`manifest.json`; none was rewritten after writing.

## UNKNOWN counts (required, per field)

- `task_type`: **74/579 UNKNOWN** — 26 without any brief on disk, 48 with a brief too thin for
  any cascade rule to fire honestly (e.g. the five T228–T232 "T227-regtest-sigkill" stubs).
- `scope_class`: 0 UNKNOWN (classes partition by construction).
- `capabilities`: 0 UNKNOWN (empty tag set expressed as `none-inferred`).

## Anomalies and patterns, ranked by consequence

1. **Model attribution is hollow for most of the ledger's done tail.** Query:
   `done tasks where model=="" and agent==""` → **9 tasks** (T674, T679, T683, T685, T687, T690…);
   but `model==""` alone covers **269 done tasks** — attribution there rests entirely on the
   `agent` field. Any model-performance measurement inherits this gap. Denominator: 519 done tasks.
2. **61 run records have wall AND cpu AND rss all null** while occupying a slot in the runs
   directory. Query:

```
for p in glob('untracked/runs/*.json'): d=json.load(open(p))
select d where d['wall'] is None and d['cpu'] is None and d['rss_mb'] is None
```

   By model: deepseek-v4-pro 16, unset 24, deepseek-v4-flash 13, others small.
   Any wall/RSS statistic quoted from run records has ≤249 of ~579 tasks behind it, not 579.
3. **Token meter is majority-missing:** the token ledger has 1387 rows;
   **771 (55.6%) have `tokens_in: null`**. Cost-per-task analyses are built on the 45% minority.
   Query: `jq -s 'group_by(.tokens_in==null)' <token ledger>` (path in the fence above).
4. **44 done tasks have zero findings files** (query: kanban status done ∧
   `glob(findings/<id>*))==[]`; sample T203, T228–T236, ORCHA-FLASH). Some are legitimately
   finding-less (pure orchestration), but each is an uncheckable done.
5. **Retry storms concentrate cost:** T789 has **148 attempt records** (6319 s wall),
   T542 has 80 bakeoff records, T449 30. Query: count run-record files per id in the runs
   directory (fence above), sort descending.
   Three tasks hold more attempts than the bottom 400 tasks combined.
6. **Live/archive status conflicts on shared ids** (query: join on id, compare status):
   STANDING-ABSORB (live=dispatchable, arch=done) and T612, T749 (live=done, arch=dispatchable).
   Harmless if archive is write-once history, contradictory if archive is ever consulted first.
7. **13 tasks' `brief_bytes` disagree with the on-disk brief** (query: compare record field to
   `os.path.getsize(brief)`; e.g. T702 1508 vs 1524, T741 326 vs 455) — briefs edited after
   registration, so size-derived cost models drift from what the worker actually read.
8. **29 bundle paths point at missing files**, including absolute paths
   (query: exists(record.bundle)==False). Overlaps the 29 no-brief tasks but is not identical:
   some missing bundles are the *only* copy of the brief, i.e. the task is unreconstructible.

## What the corpus cannot support (UNKNOWN by necessity)

Per-goban epistemic independence applies here too: these are corpus-level descriptions, not
per-model verdicts. With 55% of token rows null and 61 null run records, no defensible
cost-per-model or accuracy-per-model ranking can be computed from this corpus alone; the
agreement measurement against T817's independent derivation (a third task) is the honest next
step, and it should compare *type distributions and per-row labels*, not cost figures.

## Resume command

```
python3 docs/infra/task-corpus-b/derive.py
```

Reads `manifest.json`, verifies each chunk's sha256, continues at `next_chunk`. As of
2026-08-23 all 12 chunks are complete (`next_chunk == 12`); a fresh id would extend chunks
mechanically. To change the method: bump `METHOD_VERSION` in `derive.py` and re-run — new
chunk files are written, old ones are never touched.
