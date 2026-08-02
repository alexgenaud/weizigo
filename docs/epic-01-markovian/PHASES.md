# PHASES — epic-01-markovian under DIRECTION.md

Canonical, unsuffixed, revised in place. Maintained by the Orchestrator.

**Authority.** `docs/audits/grand-audit-2026-08-02/DIRECTION.md`, ratified by the
human 2026-08-02, governs. This file is only the phase→task mapping: where each
registered task sits and why. **When this file or the kanban disagrees with
DIRECTION.md, DIRECTION.md wins and this file is the bug.** Task briefs live at
`untracked/T<N>-*.md` (untracked by convention); the reasoning below is the
tracked copy.

Opened 2026-08-02 by Orchestrator (Opus 5) at commit `2432d71`.

## The five phases

| phase | content (DIRECTION §5) | state |
|---|---|---|
| 0 — theorem and axioms | AXIOMS.md; requirement tree top-down from Z; old rows mapped onto it; MIGOS/tie adjudicated | **T271 open — gates everything below** |
| 1 — acceptance battery before code | battery built and calibrated on known-defective inputs first; `0c3366f0` must fail it | T266, T267, T270 open |
| 2 — kernel extraction | one function one owner, ko and state-key first; all harnesses in `zig build test` | T273 blocked (needs T271, T267) |
| 3 — A–Z reverification | ladder 2×2 → 3×2 → 3×3 → 4×4; kernel vs fixtures differentially; every register row re-derived, demoted or retired | not decomposed |
| 4 — the swap | kernel becomes production; legacy frozen as fixtures; engine/experiment boundary in `src/` | not decomposed |

**Phase 0 is a hard gate on decomposition.** Phases 1–4 get no new tasks until
AXIOMS.md exists — the requirement tree is the input that says which lemmas need
work. The Phase 1 tasks listed above are carry-forward rows that predate
DIRECTION and were re-scoped onto the phase structure, not a decomposition of
Phase 1.

## Where the carry-forward queue landed

Reconciled 2026-08-02. Each brief carries the same reasoning under a "Phase
placement" heading.

| task | placement | reasoning |
|---|---|---|
| **T271** (new) | Phase 0 | AXIOMS.md: theorem, ruleset R as axioms with claim IDs from birth, requirement tree from Z, MIGOS tie adjudication (audit prescription 5). Mapping all 282 register rows onto the tree is deferred — the tree is its input. |
| **T266** | Phase 1 | Artifact incompleteness. **Re-scoped: diagnosis only, the "minimal fix" withdrawn.** Repairing the builder before a check exists that fails today's artifact is code before battery. Adds a deliverable: the completeness check specified, such that it fails `0c3366f0` for the found reason. |
| **T267** | Phase 1 | Key-agreement invariant, **split from the extraction.** The test half stays (writes no production code) and absorbs two audit repairs: wire `differential.zig` into `zig build test`, and replace the tautological T265 test with one that imports `gtp.zig` (GRAND-AUDIT §1a). |
| **T270** | Phase 1 | I2 (colour inversion) against WZO2 — a battery invariant read against a certified-defective calibration input. Reported as a calibration reading, not a verdict; independent re-implementation (R8) is the Phase 1 requirement, not colour. |
| **T273** (new) | Phase 2 | The extraction split off T267: one production ko rule and one state-key in `rules.zig`, 17 hand-written copies demoted to frozen fixtures (audit prescription 1). `needs T271` (axiom + claim ID heads the code) and `needs T267` (the invariant must reproduce a known defect before anything moves). |
| **T272** (new) | infra | Audit prescription 2: pre-commit hook enforcing the recorded debt floor (not "green"), floor single-sourced machine-readably, hook tracked so it survives a clone, with null and seeded-defect controls; plus C7 absorbed-with-rejection (C7 4 → 3). |
| **T268** | infra | Deploy correctness. Epic-independent, so no phase gate — but a **precondition for Phase 1 gate readings**: a battery run against a stale `bin/` measures a binary nobody can reconstruct. |
| **T269** | infra | Register vocabulary. `needs T272` — same file (`src/claimlint.zig`, one writer per file) and it extends T272's disposition mechanism rather than inventing a second. Absorbs C7's silent skip of schema-non-conforming findings files. |
| **T203** | retired | `abandoned` 2026-08-02: DIRECTION §2 forecloses the migration that is its entire deliverable ("no migration of claims/decisions/docs"). Reopenable if the human overturns §2. |

Not registered, tracked here so it is not lost: engine-unification **pass1** (the
actual unification — delete `genericChainCaptured`, `genericIsLegal`,
`genericPosFromMove`, extend to 4×3/4×4) is Phase 2 work and waits on the
kernel's shape; audit **prescription 3** (generate the resume surface instead of
hand-refreshing `docs/status/CURRENT.md`) and **prescription 4** (the two lying
generators, the missing `ephemeral` symlink) are unregistered infra awaiting the
human's word on scope.

## Standing constraints on this phase plan

- **Every gate is mechanized the day it is declared** (DIRECTION §5). A rule that
  stays prose is a rule we have chosen to re-learn.
- **All 282 register rows are presumed unverified**, falsifications included.
- **No re-audit.** The next audit is the ephemeral gate that runs once Phase 0/1
  deliverables exist.
- Briefs never name a model; the human assigns at dispatch.
