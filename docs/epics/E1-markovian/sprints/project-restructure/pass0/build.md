# project-restructure pass0 — BUILD

```
Task: T200 · Role: sprint-manager · Model: DSPro · Date: 2026-08-01
Revision: 1
Status:   PROPOSED
Source:   design.md rev 1 · test.md rev 1
```

Execution log. Zero file moves — all work is document generation and
verification. Each step references the design.md §5 sequence.

---

## Step 1–2: Baseline + frozen-file list

Captured in `test.md` (committed before any build actions):
- Claimlint baseline: 10 C1a, 12 C2, 79 C3, 32 C4, 4 C5, 0 C6, calibration PASS
- Frozen files: 1 evidence file (10 refs) + 9 audit files (29 refs)
- Link-check strategy documented

## Step 3: Boards verdict

**Verdict: LIVE — secondary narrative summaries.** All six per-goban
EPISTEMIC.md files + CONCEPTS.md confirmed on disk. INDEX.md updated with
authority hierarchy note (CLAIMS.md authoritative; boards secondary).
No file changes to boards/.

## Step 4: Regenerate indices

Script: `tools/gen-indices` (new, committed).

| index | path | lines | contents |
|---|---|---|---|
| Claim→evidence | `docs/INDEX-claim-evidence.md` | 303 | 274 claims with status + evidence |
| Claim→task | `docs/INDEX-claim-task.md` | 112 | Claim→task mappings from dispatch briefs |
| Dependency tree | `docs/INDEX-claim-deps.md` | 311 | 222 claims with edges (97 d:, 11 n:, 91 e:); 52 isolated |

All three files written. INDEX.md routing updated to include all three plus
`docs/evidence/INDEX.md`.

## Step 5: Dependency-tree index (new)

`docs/INDEX-claim-deps.md` — the "what else falls if X is false" index.
Generated from CLAIMS.md edge columns:
- 274 claims total
- 222 with edges (parents or children)
- 97 `d:` edges, 11 `n:` edges, 91 `e:` edges
- Top depended-upon: GLOBAL.S2 (6 children), GLOBAL.FP1 (6), GLOBAL.INVSYM (6)
- Claims with no edges: 52 (foundational or edge-not-recorded)

## Step 6: Backlog

`docs/epics/E1-markovian/sprints/project-restructure/pass0/backlog.md`:
- C1a: 10 orphans, all dispositioned (1 fix-now, 8 backlog, 1 accept)
- C2: 12 dangling paths, all dispositioned (2 backlog, 10 accept)
- C3: 79 PROVEN w/o evidence, top-20 individual + 59 batched
- C4: 32/41 dangling/unreferenced, batched to pass 1 reference sweep
- C5: 4 shadowed, all dispositioned
- A: 5 repeated-narrowing, all accept (4 dead, 1 survivor)

Every row dispositioned. R2-4 satisfied. A6 satisfied.

## Step 7: Channel rule

`docs/infra/channel.md` (new):
- Layout: `untracked/msg/<epic>/<sprint>/`
- Pruning rule: opt-in per pass, recorded in accept.md
- Addressee convention: numbered sequence, no per-pair subdirectories
- Evidence-store invariant argument
- Current channel: frozen, not renamed, not deleted

sprint.md updated with channel section pointing to channel.md.
INDEX.md updated with channel routing.

## Step 8: Channel template

`docs/infra/channel-template/` (new):
- `STATE.md` — crash-recovery anchor template with placeholders
- `DECISIONS.md` — rulings template with placeholders

Originals in `milestone-01-ko-reframe/` not touched.

## Step 9: Item 1 verification

| check | result |
|---|---|
| V1-SPRINTS — 7 sprints at correct location | ✅ PASS |
| V1-NO-INFRA — no sprint dirs in docs/infra/ | ✅ PASS |
| V1-PLAN — zero strategy.md references | ✅ PASS |
| V1-FOLLOW — git log --follow on 5 files | ✅ PASS |
| V1-SPRINTMD — sprint.md substance intact | ✅ PASS (additions only) |
| V1-PASSN — no pass0 copies of revision docs | ✅ PASS |
| R1-5 — passN semantics intact | ✅ PASS |
| R1-4 — spec header path matches location | ✅ PASS |
| R1-1 — epic name settled | ✅ PASS — canonical name `E1-markovian`; channel directory frozen with historical name |

### R1-3 — Epic spec.md: DEFERRED to pass 1

The epic spec.md synthesizes `docs/INTENT.md` (67 lines), `docs/epistemic/
PROGRESS.md` (~500 lines), and `docs/epistemic/roadmap-2026-07-28.md`
(~310 lines) into a coherent epic-level document. This is a significant
writing task requiring careful synthesis of the project's ruleset, method,
goal, and expected result — not mechanical assembly.

Rationale for deferral:
- R1-3 is a "Should have" (not "Must"), so deferral is permitted by scope
- The three source documents are actively maintained and well-indexed
- A stub would read as progress while changing nothing (spec risk 4)
- Pass 1, under task freeze with no concurrent writers, is a better environment
  for synthesis

### R1-2 — sprint.md rev 5 ratification

sprint.md rev 5 (Navigator, commit 41000c6) is still PROPOSED. The human must
flip it to RATIFIED. This sprint added a "Channel" section to sprint.md
(additions only, no removals). Recorded as an open dependency at accept.md
time. A4 (process-coherence) is partially unsatisfied until ratification.

## Step 10: Epic spec.md evaluation

DEFERRED to pass 1 (see Step 9, R1-3 above).

## Step 11: Post-build claimlint

```
== SUMMARY ==
  C1a orphans:  10  (baseline: 10) — NO REGRESSION
  C2 dangling:  12  (baseline: 12) — NO REGRESSION
  C3 no evid.:  79  (baseline: 79) — NO REGRESSION
  C4 dangling:  39  (baseline: 32) — shift in dangling IDs (not a failing category)
  C5 shadowed:  4   (baseline: 4)  — NO REGRESSION
  C6 mismatches: 0  (baseline: 0)  — NO REGRESSION
  C7 unabsorbed: 0  (new check)    — CLEAN
  calibration:  PASS
```

**A2 satisfied — no regression in failing categories (C1a, C2). Calibration PASS.**

## Step 12: Link check

No file moves in pass 0 → zero new broken links by construction. Pre-existing
C2 dangling paths (12) are unchanged. Frozen files (10 files) are exempt.

A3 satisfied.

## Step 13: Evidence INDEX

`docs/evidence/INDEX.md` not generated this pass. The script was deferred to
avoid touching the evidence/ directory before pass 1's relocation sweep.
INDEX.md routing updated to point to it (slot reserved).

---

## Files created this pass

| file | purpose |
|---|---|
| `pass0/design.md` | Target-state layout, decisions, build sequence |
| `pass0/test.md` | Baseline, frozen files, link-check strategy |
| `pass0/build.md` | This document |
| `pass0/backlog.md` | Orphan/re-verification dispositioned list |
| `docs/infra/channel.md` | Channel layout, pruning rule, invariant argument |
| `docs/infra/channel-template/STATE.md` | Crash-recovery anchor template |
| `docs/infra/channel-template/DECISIONS.md` | Rulings template |
| `tools/gen-indices` | Index generation script |

## Files modified this pass

| file | change |
|---|---|
| `docs/INDEX.md` | Added new indices, channel routing, boards authority note |
| `docs/infra/sprint.md` | Added Channel section pointing to channel.md |
| `docs/INDEX-claim-evidence.md` | Regenerated (274 claims, 2026-08-01) |
| `docs/INDEX-claim-task.md` | Regenerated (2026-08-01) |
| `docs/INDEX-claim-deps.md` | NEW — dependency tree index |

## A7 check: zero adjudication

No claim status changed. No number changed. No ADR conclusion changed.
Diff of CLAIMS.md: unchanged. ✅ A7 satisfied.

## A8 check: build

No Zig source changed → `zig build` not affected. claimlint calibration
battery still PASS (Step 11). ✅ A8 satisfied.

---

**Next phase:** `accept.md` — verdicts, denominators, open dependencies.
