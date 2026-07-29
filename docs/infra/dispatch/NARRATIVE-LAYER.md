<!--managent set=U-->
# NARRATIVE-LAYER — a human-readable through-line that is a verified projection of the tree, not an agent's invention

**Opened by:** the Orchestrator's retirement assessment (2026-07-29) and the user's question "is the tree human-friendly? can narratives be generated without hallucination?" Answer to both today: **no**, and **yes but only with cite-back discipline**. This task builds the discipline.

## The problem, stated precisely

`CLAIMS.md` is 254 rows of claim + status + edges + orphan analysis + inheritance audit + discrepancy list. It is thorough, auditable, and machine-checkable — and it is **not a narrative a human can read for the through-line**. `PROGRESS.md` is closer (the "living spec") but it is **stale** through all of 2026-07-29 and is not a guided tour. `CURRENT.md` and the handovers are tactical. So the project's actual finding — *provably perfect 4×4 is out of reach under tractable means, and here is the chain of foreclosures that shows it* — **is told nowhere**. The pieces are scattered across ADR-0018, ADR-0019, the F2-REMEDY design, the knowledge ladder, and closed consoles' Q&A.

A narrative written freehand by an agent would be hallucination-prone precisely where it matters most. The fix is not "write carefully" — it is **make the narrative a projection of the tree, mechanically verified**.

## The task

**1. A cite-tag discipline.** Every load-bearing sentence in the narrative carries an inline citation to a claim ID **and** its status, e.g. `[GLOBAL.R1:PROVEN]`, `[QA-026:FALSE-AS-SCOPED]`. Statuses are quoted from the register, never restated from memory.

**2. A linter check.** Extend `bin/weizigo-claimlint` (or add a sibling) with a check that, for every `[ID:STATUS]` tag in the narrative: the ID exists, and the status **matches the register exactly**. Exit non-zero on mismatch. This is what makes the narrative hallucination-resistant: the moment a claim's status changes, the narrative fails the lint until it is updated. **Ship a calibration case** (a deliberately wrong tag that must be caught, and a right one that must stay silent) — the project rule is that a checker without calibration is not evidence.

**3. The narrative itself — "what we tried, what failed, what's open, what it means."** Told **once**, in order, cite-tagged. The spine, as of 2026-07-29:

- PSK is intractable for exact solve `[GLOBAL.R1]`
- score-on-cycle is equivalent in hardness `[GLOBAL.R2]`
- RETRO_PLY likewise `[GLOBAL.RPLY]`; kill-X% made it worse `[GLOBAL.R3]`
- the shipped oracle is not a real-game oracle `[GLOBAL.C2]`, `[GLOBAL.C3]`
- the bracket premise is orphaned `[GLOBAL.F2]`, `[QA-018]`, ADR-0015/0017/0018
- basic ko + fixed tie was the **first unforeclosed** candidate — and its tie-pinned fixpoint does **not** compute the truncation value `[QA-026:FALSE-AS-SCOPED]`, `[GLOBAL.LONGCYCLE:FALSE-AS-SCOPED]`, ADR-0019
- state-sufficiency itself is **untested, not refuted** `[QA-023:CLAIMED]` — and the distinction is the roadmap

**Say once, plainly, that the negative result is a contribution.** Every bounded-history representation tried was foreclosed *by measurement*, not by lack of imagination (`AUDIT-DSPro` §2.2 is right about this). That is a result about the problem.

**4. Fold in the two axes.** `docs/epistemic/knowledge-ladder.md` (PROPOSED) separates epistemic strength from **rule fidelity**, and the project's characteristic error is a high score on the first reported as settling the second. If the user ratifies it, the narrative states each result as *(rung, rule)* — and the candidate `CLAIMS.md` **rung** and **rule** columns would let the linter catch the `4x4.ANCHOR` class mechanically, which today is invisible because it lives in prose.

**5. Where it lives.** `PROGRESS.md` becomes the durable narrative hub (currently stale — bring it current as part of this task); `CLAIMS.md` stays the ledger; `CURRENT.md` and handovers stay tactical. Say explicitly which file is which, at the top of each.

## Acceptance

- Every load-bearing sentence cite-tagged; **zero** untagged load-bearing claims.
- The lint check implemented, **with calibration**, and green.
- `PROGRESS.md` current through 2026-07-29 (ADR-0018, ADR-0019, the probe defect, the C1/C2 split, the 14 orphans).
- A reader who knows nothing can read one file and learn what is known, what was tried, what failed, what is open, and what it means.
- **No claim status changed by this task**, and no new claim invented. If the narrative cannot be told without a claim that does not exist, that gap **is** the finding — report it.

## Deliverable

`PROGRESS.md` (rewritten as the narrative hub), the linter extension, and its calibration cases. **Coordinate with `EVIDENCE-INTEGRITY`**, which holds `CLAIMS.md` — this task should not need to edit the register, and if it does, hand the edit over rather than taking the file.

**Read first:** GLM's assessment in the 2026-07-29 channel, `docs/epistemic/knowledge-ladder.md`, `docs/decisions/0019-*.md`, `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`, `CLAIMS.md` §4-§7, and `bin/weizigo-claimlint`'s existing check structure.
