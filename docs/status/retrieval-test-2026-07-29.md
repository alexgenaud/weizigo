# Retrieval test — INDEX-RETRIEVAL acceptance criterion

Task: INDEX-RETRIEVAL · Role: worker · Model: DSPro · Date: 2026-07-29

Ten questions a new agent or the human would realistically ask. For each: the
exact path from `docs/INDEX.md` to the answer, and the **number of hops**.
Acceptance: every question resolves in **≤ 2 hops**.

---

## Q1: "Is the 4×4 +2 value trustworthy?"

**Path:** `docs/INDEX.md` → "Is the 4×4 +2 value trustworthy?" → `AGENTS.md` foreclosure: "The committed ko-sensitive values are NOT trustworthy."
**Hops: 1** — the index line points directly to the foreclosure in AGENTS.md. For detail, the same line names `docs/epistemic/CLAIMS.md` rows and `docs/status/leak-crisis.md` as secondary destinations.
**Result: ✅ PASS (1 hop)**

---

## Q2: "Why is PSK not the generation target?"

**Path:** `docs/INDEX.md` → "Why is PSK not the generation target?" → `AGENTS.md` foreclosure + `docs/research/ruleset-options.md`.
**Hops: 1** — the index line points to the AGENTS.md foreclosure (intractable even on empty 2×2) and the ruleset-options research for the full analysis.
**Result: ✅ PASS (1 hop)**

---

## Q3: "What is the eye-prune's status?"

**Path:** `docs/INDEX.md` → "What is the eye-prune's status?" → `docs/decisions/0006` (the ADR), `docs/epistemic/CLAIMS.md` row `GLOBAL.ADR0006-EYE` (CLAIMED), `docs/evidence/ADR-0006/` (committed falsification test).
**Hops: 1** — the index line names all authoritative destinations. A reader then opens any of them.
**Result: ✅ PASS (1 hop)**

---

## Q4: "Which claims have no committed evidence?"

**Path:** `docs/INDEX.md` → "Which claims have no committed evidence?" → `docs/epistemic/CLAIMS.md` §4.2 (load-bearing unknowns), §7 (evidence-integrity note), `docs/evidence/README.md` (inventory).
**Hops: 1** — the index line names the three destinations. CLAIMS.md §4.2 ranks unknowns by dependent count; §7 lists 9 missing `untracked/` files.
**Result: ✅ PASS (1 hop)**

---

## Q5: "What did 2B-4 conclude and does it still stand?"

**Path:** `docs/INDEX.md` → "What did 2B-4 conclude and does it still stand?" → the index names the brief (`docs/infra/dispatch/2B-4.md`), the audit (`docs/audits/2b-6-full-review-2026-07-29.md`), the defect report (`docs/evidence/QA-023/probe-defect-2026-07-29/README.md`), and the corrected re-run (`docs/evidence/QA-023/probe-fix-2026-07-29.md`).
**Hops: 1** — the index line gives the complete chain. A reader wanting the conclusion opens `probe-fix-2026-07-29.md` (hop 2) and finds the adjudication.
**Result: ✅ PASS (≤ 2 hops)**

---

## Q6: "What foreclosures cannot be relitigated? Where is the complete list?"

**Path:** `docs/INDEX.md` → "What foreclosures cannot be relitigated?" → `AGENTS.md` (repo root) §"Non-negotiable rules".
**Hops: 1** — the index line points to the single authoritative source.
**Result: ✅ PASS (1 hop)**

---

## Q7: "What is the F2-REMEDY and why does it exist?"

**Path:** `docs/INDEX.md` → "What is the F2-REMEDY and why does it exist?" → `docs/research/f2-remedy-design-2026-07-29.md` (the design) + ADRs 0015, 0017, 0018, 0019.
**Hops: 1** — the index line names the design doc and the chain of four ADRs that explain why it exists. The design doc itself states the premise in its opening.
**Result: ✅ PASS (1 hop; 2 to read the design)**

---

## Q8: "What is the current state of the project — what's in flight, what's blocked, what's done?"

**Path:** `docs/INDEX.md` → "What is the state right now?" → `docs/status/CURRENT.md` (in-flight tasks), `docs/epistemic/PROGRESS.md` (strategic truth).
Also: `docs/INDEX.md` → "What is in flight? What can I work on?" → `./bin/managent status` (the kanban).
**Hops: 1** — the index distinguishes tactical state (CURRENT.md) from strategic state (PROGRESS.md) from operational state (kanban).
**Result: ✅ PASS (1 hop)**

---

## Q9: "How do I execute a task I was handed? What rules bind me?"

**Path:** `docs/INDEX.md` → "How do I execute a task I was handed?" → `docs/infra/delegation/DELEGATEE.md`.
Then: `docs/INDEX.md` → "If I am an agent, what rules bind me?" → `AGENTS.md` (repo root) + `docs/infra/delegation/DELEGATEE.md`.
**Hops: 1** — the index answers both questions with one destination each. The DELEGATEE.md itself then tells you to read your brief next (hop 2 — within spec).
**Result: ✅ PASS (≤ 2 hops)**

---

## Q10: "Where is the evidence that T13 falsified C2 at 3×2? Can I reproduce it?"

**Path:** `docs/INDEX.md` → "Where are the research findings?" → `docs/research/c2-falsification-3x2.md` (the durable summary).
Then `docs/INDEX.md` → "Why was X decided?" / "What backs claim Y?" → `docs/epistemic/CLAIMS.md` row `3x2.T13` (PROVEN, with the ⚠ CANNOT REPRODUCE banner).
**Hops: 1** from index to the durable summary; the CLAIMS.md row is an alternative entry point at the same depth. The summary states the method and numbers; the CLAIMS.md row warns that the probe source is lost.
**Result: ✅ PASS (1 hop)**

---

## Summary

| question | hops | pass? |
|---|---|---|
| Q1: 4×4 +2 trustworthy? | 1 | ✅ |
| Q2: Why not PSK? | 1 | ✅ |
| Q3: Eye-prune status? | 1 | ✅ |
| Q4: Claims with no evidence? | 1 | ✅ |
| Q5: What did 2B-4 conclude? | 1–2 | ✅ |
| Q6: Complete foreclosure list? | 1 | ✅ |
| Q7: F2-REMEDY and why? | 1–2 | ✅ |
| Q8: Current project state? | 1 | ✅ |
| Q9: How to execute a task? | 1–2 | ✅ |
| Q10: T13 evidence? | 1 | ✅ |

**All 10 questions resolve in ≤ 2 hops.** No question required more than one
index lookup to find the authoritative destination.

---

## Notes

- **Q5** and **Q10** benefit from the INDEX-claim-evidence and INDEX-claim-task
  companion indices — a reader wanting to trace the full chain of tasks that
  produced or audited a claim can use those as hop 2.
- **Q8** exercises the distinction between tactical state (CURRENT.md),
  strategic state (PROGRESS.md), and operational state (kanban). The index
  separates these cleanly.
- **The `docs/INDEX.md` §"Files that are authoritative for exactly one thing"**
  prevents the most common failure mode: two files both appearing canonical.
  The anti-confusion table resolves the ambiguity in one row.
