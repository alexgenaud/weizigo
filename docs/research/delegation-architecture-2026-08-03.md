# Delegation Architecture Experiment — 2026-08-03

**Task:** T316 · **Model:** deepseek-v4-pro · **Date:** 2026-08-03

## Question

Does a worker-run audit loop, or a sprint, beat one bounded row for defect
detection on a review task? Every task tonight (T292–T315) was one bounded
deliverable to one worker. Two alternatives were tested:

- **Audit loop:** a worker reviews, then an independent blind auditor reviews
  the same corpus, iterating until no new defects found.
- **Sprint:** one worker reviews three deliverables in sequence (findings file,
  prose file, combined report).

## Design

**Seeded corpus** under `untracked/T316-seeded/` with 6 planted defects drawn
from tonight's real failure classes (2 each):

| Class | Description | Tonight's precedent |
|---|---|---|
| 1 — Unmet bar as pass | PROVEN status on a claim whose primary bar (speedup table) was unmet | T312 |
| 2 — Denominator/label dishonesty | "exhaustive: all 99,133,036 checked" when only 512 states tested | T292, T309 |
| 3 — Cite-tag mismatch | Claim ID stated as PROVEN when register says CLAIMED | Every prose row's obligation |

**Answer key** written before first dispatch, timestamped by commit `74423db`
(manifest at `docs/evidence/T316/corpus-manifest.sha256`).

**Model:** `deepseek-v4-pro` for all arms — strongest epistemic discipline
per model-perf.md composite evaluation; constant model isolates architecture.

**Three arms, identical review brief, n=1 per arm.**

## Results

### Arm A — Single Worker (control)

| Metric | Value |
|---|---|
| Defects found | **6/6** |
| False positives | 0 |
| Wall clock | 126 s |
| Dispatch count | 1 |

Found all six planted defects plus two genuine consequences (internal
contradictions). The reference architecture performed at ceiling — there was
nothing left for the other arms to add.

### Arm B — Audit Loop

| Metric | Value |
|---|---|
| R1 defects found | 6/6 (same as Arm A) |
| R2 new defects | **0** |
| Wall clock | 126 s + 151 s = 277 s |
| Dispatch count | 2 |

The blind auditor (R2) found the same 6 defects. It added one nuance (wrong
claim ID cited: GLOBAL.F2 for Knaster-Tarski instead of GLOBAL.FP1) but
discovered no new planted defect. **The audit loop doubled dispatch count and
wall clock for zero incremental finds.**

### Arm C — Sprint

| Metric | Value |
|---|---|
| Defects found | **~4.5–5/6** |
| False positives | 2–3 |
| Wall clock | 283 s |
| Dispatch count | 1 |

D1 (findings file review): found 5 defects, caught D5 and D2 clearly, D1/D3
partially (structural-dependency and field-semantics angles).

D2 (prose file review): found 6 defects, caught D6 and D4 clearly, plus 2 false
positives (false-mathematical-claim about unique fixpoint — present in original;
missing-provenance for Files Changed section — overly strict).

D3 (combined): strongest deliverable. Cross-file comparison caught one pattern
(4-vs-5 test count discrepancy) invisible to single-file review. But overall hit
rate was lower than the single worker, and false positives were higher.

## Answers

### 1. Does the audit loop find defects the single worker misses?

**No — on this corpus, it only restates them.** Arm A found all 6 planted
defects. Arm B-R2 found the same 6. The audit loop cost 2× the dispatches for
zero incremental finds.

Specific defect IDs only Arm B found: **none.**

**Null result is valuable:** it confirms the standing one-row rule on a task
class where the single-worker architecture was already adequate. The audit
loop should be reserved for cases where the first worker is known or suspected
to have incomplete coverage — it is not a default.

### 2. Does the sprint hold quality across three deliverables?

**Quality did not decay — but per-deliverable quality was lower than the
single worker's single report.** D3 was the strongest deliverable (cross-file
insight), but D1 and D2 each missed defects that the single worker caught in
one pass. The sprint cost 2.2× the wall time (283 s vs 126 s) for a lower
hit rate (4.5–5/6 vs 6/6) with false positives.

The sprint structure worked as designed — the rule against back-editing earlier
deliverables preserved the signal that D1 and D2 were incomplete. But on this
task class, three bounded deliverables on one console was less efficient than
one.

### 3. The honest limit and T317

**Tonight's real failures were orchestration errors** — file collisions
invisible in declared deliverables, stale brief facts, deliverable lists that
named artifacts instead of touched files. **None of the three arms can catch
those**, because all three receive the brief as given.

**Recommendation for T317: pre-dispatch brief audit.** A fourth architecture
where a worker audits the brief itself before execution — checking
deliverables= paths exist and are not stale, verifying dependencies are
satisfied, catching wrong paths or missing facts. This addresses the actual
failure mode of tonight's tasks, which this experiment could not address by
design.

## Cost note

Arm B doubled token spend (2 full context windows) for zero incremental finds.
If this result generalizes, the audit loop is cost-disproportionate on review
tasks where a single competent worker already finds everything.

## Caveats

- **n=1 per arm.** This is a pilot that can show a large effect, not measure a
  small one. The planted defects were relatively straightforward (cite-tag
  mismatches are a CLAIMS.md grep away; speedup fabrication is obvious against
  the committed original). A harder corpus might differentiate the arms more.
- **Arm A had an advantage:** it referenced the committed T312 files despite
  the brief saying not to — it could diff against the originals. The other arms
  were truly blind to the originals. This may inflate Arm A's apparent
  performance.
- **Arm C model misidentification:** findings files report `claude-opus-4-5`
  but dispatch was `--dspro`. The model field in deliverables is unreliable.
- **Defect class overlap:** D2 (fabricated speedup table) is both class 1
  (unmet bar) and class 2 (missing provenance). The classes are not perfectly
  orthogonal.

## Agents dispatched

| Arm | Round | Agent | Model | Outcome |
|-----|-------|-------|-------|---------|
| A | 1 | T316-arm-A | deepseek-v4-pro | 6/6, 126s |
| B | 1 | (same as Arm A) | deepseek-v4-pro | 6/6 |
| B | 2 | T316-arm-B-r2 | deepseek-v4-pro | 0 new, 151s |
| C | 1 | T316-arm-C | deepseek-v4-pro (reported as claude-opus-4-5) | ~4.5-5/6, 283s |
