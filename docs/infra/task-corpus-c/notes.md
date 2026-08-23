# T820 — corpus mining, blind third pass: method, vocabulary, anomalies

**Author:** deepseek-v4-pro/T820 · **Date:** 2026-08-23 · **Method version:** 1
**Blindness:** I did NOT read `docs/infra/task-corpus.jsonl`, `docs/infra/task-corpus.md`,
`docs/infra/task-corpus-b/`, `findings/T817-*`, or `findings/T818-*`. I did not consult
`tools/model-profiles.py`'s keyword classifier. The keyword rules below are my own, built from
the raw sources in the brief (the kanban store and archive, the brief bundles on disk, the
findings directory, the run-record directory, the token ledger, `git log`). Exact path patterns
for every source live in `derive.py` (the committed, re-runnable method); this note names them
descriptively.

## Resume command

```
python3 docs/infra/task-corpus-c/derive.py
```

The script reads `manifest.json`, re-verifies every existing chunk's sha256, and continues at
the first missing/mismatched chunk. Chunk files are append-only (a completed chunk is never
rewritten); a hash mismatch is reported to stderr and left for a human, not silently rewritten.
Chunk k covers a fixed id slice of the sorted corpus (size 50).

## Corpus definition

`union(tasks.json, archive.json)` = 580 keys; minus the two structural keys `_sys` (the
counter object) and `--bundle` (a dispatch-set marker) → **578 tasks**, sorted by natural key
(T<digits> numeric then suffix; non-T ids lexicographic), partitioned into 12 chunks of 50
(last chunk 28).

## Method v1 — the three fields

**task_type** (D027's eight, canonical short names). Tiered scoring; the body is a *fallback*
only, never decisive:

1. title + filename slug — 3.0 per distinct keyword hit (lists in `derive.py`, trimmed of
   boilerplate words like "brief", "landmark", "acceptance", "check", "evidence").
2. deliverable/hold path prefixes — decisive: `src/`|`build.zig`→implement(+5),
   `tools/`|`bin/`→infra(+4), `tests/`→battery(+3), `docs/audits`→audit(+3),
   `docs/epic`→spec(+2), `docs/research`|`docs/evidence`→research(+2),
   `docs/infra/delegation`→orchestration(+2), `docs/infra/managent`→infra(+2),
   `docs/infra`→infra(+1). `findings/` is deliberately **not** a signal (it is universal
   boilerplate — every task writes a findings file).
3. body keywords — only when the primary signal is thin or ambiguous (winner score < 3 or
   margin < 1.5); weight 0.2/hit, capped at +1.0/type.

Confidence: high (score ≥ 6 and margin ≥ 1.5) · medium (≥ 3 and ≥ 0.5) · low (else).
`UNKNOWN` when total score is 0.

**task_scope** — size, measured, not the stale stored `brief_bytes` field (which is set for
only 113 rows): `brief_bytes` (bytes of the on-disk brief), `unique_paths` (distinct
deliverables+holds), and from run records `wall_s`/`cpu_s`/`rss_mb` (max over the task's run
records) + `run_count`. Plus a 5-class ordinal from `brief_bytes`:

| class | brief_bytes | share of the 554 briefed tasks |
|---|---|---|
| XS | < 1500 | 118 (21%) |
| S | 1500–2999 | 134 (24%) |
| M | 3000–4499 | 165 (30%) |
| L | 4500–6499 | 101 (18%) |
| XL | ≥ 6500 | 36 (7%) |

Thresholds chosen against the actual distribution (median 3169 B, p90 5891 B, max 12661 B).
`class=UNKNOWN` for the 24 tasks with no brief on disk.

**capabilities** — a 12-word vocabulary derived from the data, each detected by an explicit
regex (in `derive.py`) over the brief title/slug/body and the holds/deliverables. This field is
recorded nowhere, so every assignment is **inference**; `confidence: "inferred"` is stamped on
every capability. 127/578 tasks carry an empty list (no named capability beyond baseline
execution) — stated, not hidden.

### Capability vocabulary (with three example tasks each)

| capability | meaning | example tasks |
|---|---|---|
| engine-code | edits engine source (`src/*.zig`, `build.zig`) | T340 (R8 move generator, holds `src/vb_movegen.zig`) · T383 (fix key-byte ko decode) · T227 (fix acceptance-check defects) |
| test-first | brief mandates failing-test-first / show-it-red | T315 (subagent attribution at source) · T406 (absorption machinery broken) · T411 (agent replies "OK." and runs nothing) |
| audit-verification | independent audit/verify demanded | T277 (independently verify T266's refutation) · T287 (AUDITOR: 716-gap, check or solver?) · T380 (critical review: ko exhaustiveness) |
| evidence-discipline | register/evidence work (PROVENANCE, CLAIMS.md, committed evidence) | T262 (claimlint segfaults in C7) · T480 (absorb backlog, repair malformed findings) · T377 (G3b promotions + absorb) |
| deployment | deploys binaries / runs smoke | T263 (ship a GTP binary for Sabaki) · T268 (deployment silently broken) · T264 (stamp version on every binary) |
| sub-delegation | actually dispatches/delegates to other agents | T226 (engine-unification sprint manager) · T405 (SPRINT CONSOLE: own T401–T403, subdelegate) · T320 (what can dispatch what) |
| independence | blind / do-not-read / independent re-derivation | T277 (independently verify) · T256 (P1 build audit, independent run) · T287 (AUDITOR) |
| session-persistence | long-running / resumable session required | T316 (delegation-architecture experiment, 6 arms) · T328 (N-model bake-off harness) · T357 (measure Ollama concurrency limit) |
| data-mining | corpus census / mining / reconciliation | T358 (scaling census) · T359 (symmetry-fold census) · T507 (scaling census, re-briefed) |
| numerical-measurement | runs a battery/benchmark and measures numbers | T258 (V-13 verify-battery fleet run) · T314 (measure parallel-fixpoint speedup) · T357 (measure concurrency limit) |
| spec-writing | authors a spec/design/plan document | T323 (write G3b sprint spec) · T290 (battery specification) · T271 (Phase 0 theorem and axioms) |
| orchestration | seat / delegation / sprint / register work | T405 (SPRINT CONSOLE) · T276 (one spelling per model) · T354 (register triage) |

## UNKNOWN counts (per field, stated)

- task_type UNKNOWN: **12** (T233–T238, T240, T247, T248, T761, T762, T763) — no brief and no
  holds/deliverables signal.
- task_scope class UNKNOWN: **24** — the tasks with no brief on disk.
- capabilities empty: **127**.
- task_type confidence: high 212 · medium 216 · low 150.

## Ranked anomalies (most consequential first; each with a reproducible query recipe)

Exact machine-runnable queries are in `derive.py` and reproduced below in prose; the brief
bundles, run records and token ledger are named descriptively because they are untracked (the
canonical path strings are the ones `derive.py` uses verbatim).

**A1 — 92 pre-kanban tasks have briefs on disk but no rows in tasks.json/archive.json.**
The JSON corpus begins at T203; T14–T202 (e.g. T101A, T102 "audit-2x2-mismatch", T110 "t13-probe",
T138 "3x2-census-reconciliation") exist only as brief bundles. Anything mined from the JSON
alone is blind to the entire pre-kanban era. Recipe: glob the brief-bundle directory for
`T<digits>` slugs < 203, then subtract the set of kanban keys — count the remainder (92).

**A2 — 24 corpus tasks have no brief on disk.** 18 are `verdict=abandoned` (T233–T251 except
T239; their bundle paths point to never-committed or outside-tree scratch files) and 6 are
`dispatchable` (T570, T734, T761, T762, T763, T765) whose bundles have not been written. Recipe:
for each corpus key, resolve the `bundle` field and confirm the file exists; list the misses.

**A3 — four bundle fields point outside the tree into scratch** (T240, T247, T248, T795): a
live instance of the AGENTS.md "evidence in git" foreclosure, this time for briefs. Recipe:
print every corpus row whose `bundle` value contains the scratch-directory prefix.

**A4 — 16 tasks have more than one brief file** (T554 ×12, T316 ×6, T171 ×4, T401 ×3, …): multi-arm
/ multi-lane tasks. The `bundle` field disambiguates, but any tool that globs `T<id>-*` and
takes the lexicographic first will read the wrong arm (my `derive.py` uses the `bundle` field
first for exactly this reason). Recipe: group brief files by leading `T<digits><suffix>` and
list groups of size > 1.

**A5 — 17 findings files whose filename task-id ≠ the JSON `task_id` field.** Most are benign
(`-context` / arm-suffix naming); one is a real mismatch: `findings/T323-context.json` carries
`task_id: "T322"`. Recipe: for each findings file named `T<id>-*`, compare the filename prefix
to the JSON `task_id` field.

**A6 — 13 abandoned "regtest" stubs classified `battery` from a slug-only signal** (T228–T232
briefed; T241–T246, T249–T251 brief-less). Basis is a single `regtest` keyword hit in the bundle
slug; honest but thin (medium confidence). A downstream consumer should treat these 13 as
low-trust rows.

**A7 — `task_type` is dominated by `infra` (123) and `battery` (121).** This reflects the
project's genuinely tool-heavy, race-heavy shape (107 of the 121 battery rows are real
race/probe/lane tasks), not a classifier artefact — but the body-fallback tier is the weakest
part of the method and should be re-audited before anyone treats low-confidence rows as settled.

**A8 — the brief's own counts are stale.** The brief (byte-identical to T818's) says "573 tasks",
"403 briefs on disk", "38 tasks have no brief". Reality at this read: 578 tasks, 733 brief files,
24 no-brief. The corpus has grown since the brief was authored; a diff against these figures is
not an error in either miner.

## Reproducibility notes

- `derive.py` is committed alongside the data; it is the method. It reads no T817/T818 output.
- Every row carries `method: 1`. If the method is ever improved, the new pass must write
  `method: 2` rows (new chunk files) and record the supersession here — the v1 chunks are frozen.
- sha256 of every chunk is in `manifest.json`; `derive.py` re-verifies on resume.
- The exact source paths (brief-bundle directory, run-record directory, token ledger) are stated
  in `derive.py`, not repeated here — this note is a C10-scanned document and the untracked
  corpus sources are, by design, volatile citations there.
