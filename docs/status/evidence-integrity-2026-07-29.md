# Evidence-integrity sweep — 2026-07-29

**Task:** EVIDENCE-INTEGRITY set N. **Agent:** DSPro. **Model:** not stated at dispatch.

Per `docs/infra/dispatch/EVIDENCE-INTEGRITY.md` and
`docs/audits/AUDIT-DSPro-2026-07-29.md` §2.4–§2.7, §3.2.

## What moved

### 1. Downgrades: PROVEN → CLAIMED (primary evidence lost)

| row | old status | new status | reason |
|---|---|---|---|
| `2x2.B1` | PROVEN | CLAIMED | Primary evidence (`untracked/T02-minimax.md`) lost. Only a prose summary survives at `leak-crisis.md:86-101`. |
| `3x2.B1` | PROVEN | CLAIMED | Same — `untracked/T02-minimax.md` missing. |
| `3x3.B1` | PROVEN | CLAIMED | Same. B1 ruled out failure mode (b); without it, the E2 verdict weakens from "the fixpoint itself doesn't bound" to "either the fixpoint is wrong or it doesn't bound." |

### 2. CANNOT REPRODUCE banner (evidence lost, claim stands)

| row | action | reason |
|---|---|---|
| `3x2.T13` | Stays PROVEN; reproduction block now carries `⚠ CANNOT REPRODUCE` | Probe source (`untracked/c2pilot_3x2.zig`) and raw output (`untracked/T13-minimax.md`) are gone. Durable summary at `docs/research/c2-falsification-3x2.md` preserves numbers and method. |

### 3. T07 basis unverifiable

`docs/epistemic/boards/4x4/EPISTEMIC.md` now carries a banner stating that its
rewrite basis (`untracked/T07-audit-hypotheses.md`, eight findings) cannot be
re-examined. The `[T07-N]` tags cite an audit whose primary source is lost.

### 4. D18 cross-check: dismissal unsupported

The BFS (`/tmp/test_census_pure.zig`) that resolved EXP-3's calibration-2
dispute does not exist on disk and could not be re-derived. The census numbers
are PROVEN without it; the **explanation for why the dispatch figures were
wrong** is now UNSUPPORTED. Recorded at
`docs/evidence/GLOBAL.H1-CENSUS/reconciliation/D18-BFS-UNSUPPORTED.md`.

### 5. Erratum banners on pre-crisis documents

| document | what it assumed | what falsified it |
|---|---|---|
| `docs/engine/ARCHITECTURE.md` | PSK fresh-start representation works; 5×5 is reachable | C2 (T13), C3 (E2), F2 orphaned (ADR-0015) |
| `docs/decisions/0012-ram-lean-engine-and-out-of-core-roadmap.md` | Same; ~53e9 slots, 4–6 day projection | Same. Projection predates all crisis falsifications. |
| `docs/research/retrograde-4x4.md` | "Complete, validated 4×4 oracle," writes-on guard sound, bracket-cut search sound, "under positional superko" anchor claim | `GLOBAL.F1` (writes-on unsound), C3 falsified (bracket cuts), `GLOBAL.MIGOS-RULE` (MIGOS II is NOT PSK) |

### 6. `4x4.ANCHOR` citation defect (HIGH, AUDIT-REF-DSPro-2026-07-29 §1)

Both sites corrected:
- **CLAIMS.md:401** — "under PSK" replaced with correct description: MIGOS II
  plays basic ko + long-cycle-ties, NOT PSK. Van der Werf 2005 PhD thesis §6.4
  added as canonical source.
- **retrograde-4x4.md:76** — same correction, with erratum note.

### 7. Corrections ledger: remediation column added

Each entry (A-1, A-2, A-3, B-1, C-1) in `docs/research/corrections-2026-07-27.md`
now carries a **Remediation** field:
- A-1: ✅ APPLIED (verified by CLAIMS.md §6-D17)
- A-2: ✅ APPLIED
- A-3: ✅ PARTIALLY APPLIED (`src/gtp.zig:42` corrected; old line citation stale)
- B-1: ❌ NOT APPLIED (ADR-0013 is append-only; no superseding ADR written)
- C-1: ✅ APPLIED by construction (methodological finding)

## Claimlint

**Before (baseline):** 254 rows, 293 edges, 10 C1a orphans, 10 C2 dangling paths, 79 C3 PROVEN-without-committed-evidence.

**After:** 254 rows, 293 edges, 10 C1a orphans, 10 C2 dangling paths, **76** C3 PROVEN-without-committed-evidence.

**C3 reduction (79→76):** the three B1 rows changed PROVEN→CLAIMED.

**C1a unchanged (10):** the orphans are all `d:`-chain orphans (`GLOBAL.C3 →
GLOBAL.F2` etc.) — none involve the rows changed in this task (B1 rows use
`e:` edges), so this was expected.

**C2 unchanged (10):** the MISSING files were already cited by the documents
our edits reference; the evidence-column additions for T13 and B1 simply
re-cite the same missing paths.

**The linter still exits 1** (FAILS on C1a and C2). These are pre-existing
debt — the 10 orphans trace through `GLOBAL.C3`/`GLOBAL.F1` and the 10
dangling paths are the same §7 inventory that motivated this task. Resolving
them is beyond the scope of the evidence-integrity sweep.

## No claim upgraded

Per the acceptance criteria, no claim was upgraded in this task. The B1
downgrades (PROVEN→CLAIMED) weaken the E2 verdict as documented in the audit;
this is recorded, not hidden.

## What was NOT done

- Other rows whose evidence paths are under `untracked/` (e.g. `GLOBAL.UD-1/2/3`,
  the reframe scope document) were NOT downgraded — the task brief specifically names
  `2x2.B1`, `3x2.B1`, `3x3.B1`, and T13's reproduction block. The remaining
  §7 inventory is already recorded as debt in CLAIMS.md.
- `3x2.EXACT` (8/114 and 68/600 roots) was NOT downgraded — the fresh-start
  sanity check (0/540 L==H slots) provides independent support.
- Any claim whose evidence was in `untracked/msg/` was NOT downgraded — those
  files still exist on disk (though git-ignored).
