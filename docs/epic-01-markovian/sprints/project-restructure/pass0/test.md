# project-restructure pass0 — TEST

```
Task: T200 · Role: sprint-manager · Model: DSPro · Date: 2026-08-01
Revision: 1
Status:   PROPOSED
Source:   design.md rev 1 · plan.md rev 2
Gate:     Review tests without reading implementation — fresh seat (per plan.md §1)
```

Baseline claimlint run, frozen-file enumeration, link-check strategy, and
calibration verification. Committed before any build actions so the
post-build comparison is against a pinned baseline.

---

## 1. Claimlint baseline

Captured 2026-08-01 from HEAD. Full output at `/tmp/claimlint-baseline.txt`
(attached below). Summary:

```
== SUMMARY ==
  rows parsed / unparsed        274 / 0
  C1a orphans / C1b alarms      10 / 0   (FAILS)
  C2 dangling evidence paths    12   (FAILS)
  C3 PROVEN w/o committed evid. 79   (debt only, does not fail yet)
  C4 dangling IDs / unreferenced 32 / 41   (report only, does not fail yet)
  C5 shadowed dependencies      4   (report only, does not fail yet)
  A  repeated-narrowing smells  5   (report only)
  C6 cite-tag mismatches         0   (FAILS)
  calibration                   PASS
```

### C1a orphans (must not increase)

```
ORPHAN  3x3.C1 (CLAIMED) ⟵d GLOBAL.F2 [CLAIMED] ⟵d GLOBAL.C3 [FALSE-AS-SCOPED]
ORPHAN  4x3.C1 (CLAIMED) ⟵d GLOBAL.F1 [FALSE-AS-SCOPED]
ORPHAN  GLOBAL.F2 (CLAIMED) ⟵d GLOBAL.C3 [FALSE-AS-SCOPED]
ORPHAN  GLOBAL.ADR0010-CUT (CLAIMED) ⟵d GLOBAL.C3 [FALSE-AS-SCOPED]
ORPHAN  GLOBAL.F3 (CLAIMED) ⟵d GLOBAL.C3 [FALSE-AS-SCOPED]
ORPHAN  GLOBAL.F4 (PROVEN (argument) + MEASUREMENT) ⟵d GLOBAL.F3 [CLAIMED] ⟵d GLOBAL.C3 [FALSE-AS-SCOPED]
ORPHAN  GLOBAL.H5c (PROVEN (as an implication)) ⟵d GLOBAL.C3 [FALSE-AS-SCOPED]
ORPHAN  GLOBAL.ADR0012-GATE (CLAIMED (orphaned...)) ⟵d 4x4.COMPLETE-2026-07-21 [FALSE-AS-SCOPED]
ORPHAN  GLOBAL.B15 (CLAIMED) ⟵d GLOBAL.F3 [CLAIMED] ⟵d GLOBAL.C3 [FALSE-AS-SCOPED]
ORPHAN  QA-018 (CLAIMED) ⟵d GLOBAL.F2 [CLAIMED] ⟵d GLOBAL.C3 [FALSE-AS-SCOPED]
```

### C2 dangling evidence (must not increase)

12 MISSING paths. The 9 `untracked/` paths are git-ignored by design (loss
inventory). The 2 `/tmp/` paths are ephemeral. The bulk `.wzo` artifacts are
informational.

### Calibration

8 tests, all pass. Known-bad cases all CAUGHT; known-good cases all SILENT.

---

## 2. Frozen provenance files

Per R2-2, these files under `docs/evidence/` and `docs/audits/` are NOT
rewritten. Any link break inside them from path changes (none in pass 0; pass 1
will document any) is recorded, not silently fixed.

### docs/evidence/ — 1 file, 10 references to docs/epistemic/

| file | refs |
|---|---|
| `docs/evidence/README.md` | 10 |

### docs/audits/ — 9 files, 29 references to docs/epistemic/

| file | refs |
|---|---|
| `docs/audits/2026-07-28-muhtasib-audit-chunk2.md` | 9 |
| `docs/audits/2026-07-29-AUDIT-REF-DSPro.md` | 6 |
| `docs/audits/2026-07-28-muhtasib-audit-chunk4.md` | 4 |
| `docs/audits/2026-07-28-muhtasib-audit-plan.md` | 3 |
| `docs/audits/2026-07-29-2b-2-census-audit-opus5.md` | 2 |
| `docs/audits/2026-07-29-qa023-kernel-audit.md` | 2 |
| `docs/audits/2026-07-29-2b-2-census-audit.md` | 1 |
| `docs/audits/2026-07-30-epistemic-trajectory-audit-fable.md` | 1 |
| `docs/audits/2026-07-28-muhtasib-audit-chunk1.md` | 1 |

### Rationale for freezing

These files are provenance records — they document what was observed at a
specific time. Rewriting their internal paths to keep links green would
falsify the record. The link checker exempts them; any breakage is documented
but not counted as a failure.

---

## 3. Link-check strategy

No file moves in pass 0 → no new broken links can be created by this sprint.
The link check verifies this trivially.

### Method

A script (`tools/linkcheck`) scans all tracked `.md` files for markdown links
(`[text](path)`) and bare path references. It checks:

1. **Internal links** — paths relative to repo root that resolve to existing
   files. Reports missing targets.
2. **Frozen-file exemption** — links originating from files in the frozen list
   (§2) are reported but not counted as failures.

### Pre-existing known breaks (C2 baseline)

The 12 C2 dangling paths from the claimlint baseline are pre-existing. The
link checker reports them but does not count them as new failures. They are
the C2 baseline.

### Post-build check

After build.md executes, re-run the link checker. **Expected result: zero new
broken links** (since no files moved). Pre-existing breaks unchanged.

If any new break is detected, the build is rolled back.

---

## 4. Calibration verification

claimlint calibration is PASS at baseline (8/8 tests). The design makes no
changes to `src/claimlint.zig` or any file claimlint reads. Post-build
calibration must still PASS — any regression is a build failure.

---

## 5. Test audit gate

Per plan.md §1: this test.md must be reviewed by a fresh seat before build.
The audit checks:
- Baseline captured from live run (not copied from a stale doc)
- Frozen-file list is complete (all files under docs/evidence/ and docs/audits/
  with refs to docs/epistemic/ are enumerated)
- Link-check strategy covers both internal links and the frozen-file exemption
- Calibration requirement is stated

**Auditor:** TBD (fresh seat). Findings written to
`untracked/T202-test-audit.md`.

---

**Next phase:** `build.md` — execution log. Depends on test.md audit PASS.
