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
| 1 — acceptance battery before code | battery built and calibrated on **synthetic** defects first (DIRECTION Amendment 1, ratified 2026-08-03); live artifacts are regression inputs | **decomposed 2026-08-03: T290 spec → T291 mutants → T292 baselines+gate.** Carry-forward T266/T267/T270 closed |
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
kernel's shape; audit **prescription 3** is done (T286: `bin/managent resume`
composes the resume surface at read time; `docs/status/CURRENT.md` is deleted)
and **prescription 4**'s lying-generator half is open (the `ephemeral` symlink
half was retired by the human's 2026-08-03 ruling — `/tmp/weizigo` is the
location, no symlink).

## Phase 1, decomposed (Orchestrator, 2026-08-03)

Unblocked by two things: Phase 0's AXIOMS.md exists (so the requirement tree can say which
lemmas need checks), and DIRECTION Amendment 1 is ratified (so the calibration rule is
settled — synthetic mutants must fail, live artifacts must not *newly* fail). Three rows,
serialized because each is the next one's input:

| task | what it delivers | why it must come first |
|---|---|---|
| **T290** | `sprints/verify-battery/pass1/spec.md` — I1–I12 mapped onto the tree in both directions, every pass condition stated as violation-vs-measurement, A1–A6 re-based on Amendment 1, and each check marked runnable-now / needs-kernel | Prose only. Deciding *what fails* before writing code is the whole of "battery before code" — and T287 showed a wrong pass condition is itself a defect |
| **T291** | `pass1/mutants.md` — ten synthetic mutants, one per defect actually suffered, each with a named killer and a kill matrix; two of them attack the battery itself | Mutation testing is what makes the readings mean anything. Four instruments were found broken on 2026-08-02, all green beforehand |
| **T292** | `pass1/baselines.md` + suite wiring — a golden-master baseline per artifact per check, with v1's I7 failure baselined as *known-failing*, and the fast path inside `zig build test` | "Unchanged from baseline" is meaningless without a recorded baseline, and a gate nobody runs is prose |

Two consequences of Amendment 1 that these rows carry, so they are not re-litigated:
`0c3366f0`'s completeness checks must **pass** (its defect was refuted — T266/T277/T279),
and the v1 4×4 DTT fault becomes a **synthetic** mutant so it survives its own repair.

## The G3 gate is split (Orchestrator ruling, 2026-08-03)

G3 was one undifferentiated blocker on oracle-v2, so refuting `CODE.WZO2-INCOMPLETE`
reads as clearing far more than it does. T266 established **one** of the two things G3
was standing for. Split, and each half discharges separately:

| gate | what it asserts | state |
|---|---|---|
| **G3a — structural completeness** | The artifact holds the right *set* of entries: every reachable (position, side, ko, passes) present, none extra, all well-formed, group index and entry order consistent | **dischargeable now.** T266 measured it, T277 re-derived it independently, T279 absorbed it. `CODE.WZO2-PASS1-LAW:PROVEN` |
| **G3b — value correctness** | The L/H values *inside* those entries are the fixpoint values of ruleset R — closure under the Bellman operator, no fabricated or fallback rows | **untouched.** The real closure checks (C-A1/C-A2) are specified and unrun; they need the Phase 2 kernel. Two known defects sit in the way: `CODE.ACCEPT-KOKEY` (T273) and `CODE.GTP-LHSIDE` (T283) |

Nothing about G3a implies G3b. The artifact holding exactly the right *slots* says nothing
about the *numbers* in them, and the acceptance harness that was supposed to check the
numbers had its own divergent ko rule (`CODE.ACCEPT-KOKEY`) — so A1/A2/A8 were walking
off-manifold while reporting passes. **Do not describe the 4×4 as solved, verified, or
G3-clear on the strength of G3a.** The honest sentence is: structurally complete,
value-unverified.

## Standing constraints on this phase plan

- **Every gate is mechanized the day it is declared** (DIRECTION §5). A rule that
  stays prose is a rule we have chosen to re-learn.
- **All 282 register rows are presumed unverified**, falsifications included.
- **No re-audit.** The next audit is the ephemeral gate that runs once Phase 0/1
  deliverables exist.
- Briefs never name a model; the human assigns at dispatch.
