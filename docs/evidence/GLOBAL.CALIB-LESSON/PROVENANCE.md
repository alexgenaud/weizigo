# PROVENANCE — `GLOBAL.CALIB-LESSON` · self-consistency with no passing calibration cannot distinguish bug from definition

**Author:** minimax-m3/T825 (C3 buckets reconciliation wave)
**Date:** 2026-08-25
**Claim closed:** `GLOBAL.CALIB-LESSON` — "A self-consistency check with no *passing*
calibration case cannot distinguish 'bug' from 'definition' — every input looks guilty."
**Status:** PROVEN (methodological — a statement about the argument) — **unchanged by this
repoint.**
**Repointed from:** `corrections:197-201` (claimlint C3 flagged: no path under `docs/evidence/`).

---

## 1. The lesson, with the worked example that establishes it

`docs/research/corrections-2026-07-27.md:217-221` ("**Lesson worth keeping.** A self-consistency
check with no *passing* calibration case cannot distinguish 'bug' from 'definition' — every
input looks guilty. Always calibrate an auditor against a known-good artifact before quoting its
verdict."):

The lesson is established by the worked example immediately above it (lines 197-216). The chain
of reasoning is in three numbered statements:

- **Transient claim (lines 197-201):** the chainability violations in the committed 4×4 artifact
  were first read as the ADR-0013 `ko_ref >= d` GHI bug resurfacing in the committed generation.
- **Why it is wrong (lines 203-208):** the same sweep was run on `artifacts/oracle-2x2.wzo` and
  `artifacts/oracle-3x2.wzo` — the PROVEN, Track-A-regenerated artifacts, which the suspected
  bug never touched — and they produced violations of exactly the same character: **19.51%**
  and **19.05%** misprice within the ko-sensitive region, **zero violations outside it**. A bug
  present in the clean artifacts is not a bug.
- **Corrected statement (lines 210-215):** the violations are **definitional**, not a generation
  error: a ko-sensitive slot stores an independent fresh-start solve, so it is under no
  obligation to agree with its parent across a history-free edge (the C2 falsification
  restated per slot).

The methodological claim — "calibrate an auditor against a known-good artifact before quoting its
verdict" — is exactly what the worked example demonstrates and what its worked numbers prove.

## 2. Where the lesson is applied (the proof of utility)

- **EXP-3 calibration** — the per-goban H1 census (`GLOBAL.H1-CENSUS` and the 3×3 / 4×3 children)
  was added with a known-good arm (standard) and a known-bad arm (`4x4-broken-every_capture.txt`)
  so the auditor could not be tricked by the same class of bug (`docs/evidence/GLOBAL.H1-CENSUS/`).
- **The #2 self-consistency auditor** — applied to `src/audit_2x2_mismatch.zig` and the rest of
  the consistency-audit chain, with `4x4.checkpoint.wzo` (known-bad — ko-ref artifact) and the
  Track-A-regenerated 2×2 / 3×2 (known-good) as the two calibration arms.
- **Methodological footprint in `AGENTS.md:63-67`** — the standing pre-commit gate quotes the
  lesson (necessary-not-sufficient) directly.

## 3. What this note does NOT establish

This note does not run a probe; the lesson is a methodological principle, established by the
worked example and its measured counts. A probe would not add evidence — the lesson is true by
the logical argument, and the worked example numbers (19.51%, 19.05%, 0 outside ko-sensitive)
are the empirical witness.

## 4. Scope limit

The claim is a methodological lesson about auditor design. It is **not** a claim about any
specific auditor's correct verdict on any specific artifact — those are individual
`GLOBAL.AUDITOR` / `3x2.F1` / `4x4.F1` rows with their own evidence. The lesson is the principle
that any of those auditors must be calibrated against a known-good arm before the verdict can be
quoted.
