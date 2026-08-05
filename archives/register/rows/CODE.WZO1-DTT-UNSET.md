# `CODE.WZO1-DTT-UNSET` — archived register row

**Class:** ARCHAEOLOGY · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** old-artifact

**Epitaph:** Found the WZO1 DTT column never computed (all 255 = DTT_FAR) — the initialiser hid 'never computed' from 'no finite distance' — the UNSET-sentinel lesson is the durable part; the artifacts are archived.

**Move reason (from the triage sheet):** [old-artifact] DTT column never computed on WZO1 (all 255) — old format

**Full register row (verbatim at the time of the move):**

```
| `CODE.WZO1-DTT-UNSET` | — | all | **The DTT column was never computed for the WZO1 artifacts produced by the PSK retrograde engine — every value is the `@memset(dtt, DTT_FAR)` initialiser (255).** Confirmed at 2×2, 3×2, 3×3 and 4×3 by battery invariant I7, and by Python spot-check of `data/oracle-4x4-basicko-tie-area.wzo` (first and last 10K entries: `unique == {255}`). Decisive contrast: `data/reuse-baseline/oracle-4x4.wzo`, also WZO1 format from a different build, carries **31 distinct DTT values including 0** — so the column is populable and simply was not populated. The battery's own test already asserted this artifact must fail I7. **The checker is correct; the artifacts are empty.** The initialiser is the defect: pre-filling with FAR makes "never computed" indistinguishable from the legitimate answer "no finite distance". Proposed remedy: a distinct UNSET sentinel, so an unpopulated cell identifies itself | PROVEN (I7 across four gobans + independent spot-check + positive contrast artifact) | `docs/evidence/BATTERY/triage-T260.md`; `docs/evidence/BATTERY/fleet.md` | — | any claim resting on WZO1 DTT, A8 | 0 | ? | RETIRED |
```
