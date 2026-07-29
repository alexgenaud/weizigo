# INDEX — claim-to-evidence cross-reference (generated)

Task: INDEX-RETRIEVAL · Role: worker · Model: DSPro · Date: 2026-07-29

**Generated from `docs/epistemic/CLAIMS.md` by `bin/weizigo-claimlint`.**
Reproduce with:

    zig build && ./zig-out/bin/weizigo-claimlint

This index lists every claim ID, its status, and its evidence paths. For the
full dependency graph (edges to parent and child claims), see CLAIMS.md directly.

The claimlint output above includes:
- **C1a orphans** — PROVEN/CLAIMED claims with a FALSE transitive `d:` ancestor
- **C2 dangling evidence** — evidence paths cited in docs that don't exist on disk
- **C3 PROVEN without committed evidence** — 76 of 79 PROVEN rows (tier list)
- **C4 dangling claim IDs** — IDs cited in docs with no register row
- **C5 shadowed dependencies** — `d:` edges terminating on MEASUREMENT rows
- **A repeated narrowing** — claims narrowed ≥ 2× (smell)
- **B weak evidence** — PROVEN rows with unknown or high wrong-answer-pass-rate

---

## How to use this

1. Find your claim ID in CLAIMS.md §2
2. Read the `evidence` column for document paths
3. Check `docs/evidence/<claim-id>/` for committed probe source and output
4. Run `bin/weizigo-claimlint` for the machine-readable dependency graph

---

## Summary statistics (from the last claimlint run, 2026-07-29)

- **Rows parsed:** 256 (0 unparsed)
- **Edges:** 293 total — 124 `d:` derives-from, 153 `e:` evidenced-by, 16 `n:` derives-from-negation
- **C1a orphans:** 10 — claims with a FALSE `d:` ancestor
- **C1b alarms:** 0 — every `n:` edge points at a still-FALSE parent
- **C2 dangling evidence paths:** 11 — 8 unique missing paths + 3 git-ignored evidence docs
- **C3 PROVEN without committed evidence:** 76 of 79 PROVEN rows
- **Tier A (compliant):** 3 — `GLOBAL.H1-CENSUS`, `3x3.H1-CENSUS`, `4x3.H1-CENSUS`
- **C4 dangling IDs:** 28 — claim IDs cited in docs with no register row
- **C5 shadowed dependencies:** 4
- **Repeated narrowing smells:** 5
- **Weak-evidence PROVEN rows (rate unknown):** 75

---

## Claim → evidence directory mapping

Evidence is committed under `docs/evidence/<claim-id>/`. Only the following
claim IDs have committed evidence directories:

| claim ID | evidence directory | status |
|---|---|---|
| `GLOBAL.H1-CENSUS` | `docs/evidence/GLOBAL.H1-CENSUS/` | PROVEN |
| `3x3.H1-CENSUS` | `docs/evidence/GLOBAL.H1-CENSUS/` | PROVEN |
| `4x3.H1-CENSUS` | `docs/evidence/GLOBAL.H1-CENSUS/` | PROVEN |
| `GLOBAL.ADR0006-EYE` | `docs/evidence/ADR-0006/` | CLAIMED |
| `QA-012` | `docs/evidence/QA-012/` | UNTESTED |
| `QA-018` | `docs/evidence/QA-018/` | CLAIMED |
| `QA-023` | `docs/evidence/QA-023/` | CLAIMED |
| `4x4.B43` | `docs/evidence/arena-4x4-undef/` | MEASUREMENT |
| `GLOBAL.CLAIMLINT` | `docs/evidence/GLOBAL.CLAIMLINT/` | — |
| `GLOBAL.CORRECTIONS` | `docs/evidence/GLOBAL.CORRECTIONS/` | — |
| `GLOBAL.DENOMINATORS` | `docs/evidence/GLOBAL.DENOMINATORS/` | — |
| `GLOBAL.HYPOTHESES` | `docs/evidence/GLOBAL.HYPOTHESES/` | — |
| `GLOBAL.SESSION-CHOOSE` | `docs/evidence/GLOBAL.SESSION-CHOOSE/` | — |

**All other claim IDs** have no committed evidence directory. Their evidence
consists of prose documents cited in CLAIMS.md's `evidence` column. See the
claimlint C3 report for the full tier list.

---

## Evidence integrity

CLAIMS.md §7 documents 9 missing `untracked/` files that were cited as primary
evidence. The durable summaries survive in git for T13 and B1, but the probe
sources and raw outputs are lost. See `docs/evidence/README.md` for the full
inventory.
