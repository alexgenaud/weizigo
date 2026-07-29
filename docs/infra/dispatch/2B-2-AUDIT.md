<!--managent set=J needs=2B-2-->
# 2B-2-AUDIT — verify the 3×2 cycle census (read-only)

**Role:** Auditor (Kimi-k2.7, read-only — a second pair of eyes, ≠ the m3 author). **User order: audit 2B-2 regardless of its result** — m3 reported being surprised by findings in its own solution, and 2B-4's QA-023 falsification rests on this census.

**Verify, with `file:line` citations:**
- The **SCC / lowlink caveat** — m3's first implementation over-merged SCCs (lowlink vs index bug); the corrected version uses `lowlink[v]`. Is the 1,696-vertex SCC correct? Reproduce Tarjan's on the 3×2 graph independently if cheap.
- The **cycle count** — 143,760 distinct simple directed cycles at cap 14; grows with cap (37,376 @12, 3.3M @18 cap-hit). Is the cap-artifact understood and the "true count ≥ 3.3M" claim honest? Is "distinct simple directed cycles" the right object for the B-VACUITY claim?
- The **1,724 cycle-reachable** vertices (1,696 SCC + 28-vertex tail) — the set 2B-4 samples from.
- The **escalate decision** — 2B-2 returned PASS (cycles > 0, no escalate). Confirm non-vacuous.

**Deliverable:** `docs/audits/2b-2-census-audit-2026-07-29.md` — verdict (VERIFIED / PARTIAL / WRONG) per item, citations, and a one-line: does this census hold up enough that 2B-4's falsification can rest on it? **Do not edit** `src/`, `CLAIMS.md`, or any 2B-N deliverable.

**Read first:** `docs/infra/roles/AUDITOR.md`, `docs/evidence/QA-023/census-3x2-2026-07-29.md` (+ stdout + PROVENANCE), `src/qa023_probe.zig` (`run_census_3x2`, `run_cycle_census_3x2`).

**Hazard:** never run unfiltered `zig test src/qa023_probe.zig` (collects the brute's exponential tests). Use `--test-filter`.