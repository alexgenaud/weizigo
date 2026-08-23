# Race G science arm — sprint seed

**Status:** SEED, not ratified. **Author:** claude-fable-5 at the operator's console, 2026-08-23.
**Kanban row:** TBD at registration. **Protocol:** `docs/infra/sprint.md` (pass discipline),
audit loops capped per ruling 7c.21 (`docs/status/orchestration-layer-spec.md` §7c).

**Operator direction:** the draft-brief route failed — a lane brief authored without the sprint
discipline shipped a vocabulary contradiction into two live lanes. This work is re-cast as a
sprint: spec, scope, design, plan, test-before-build, implement, verify, each phase audited, up
to three audit loops, then measured.

## 1. Goal in one line

Measure what an explicit "do science" preamble is worth: the same sealed claims, the same
models, bare arm vs instructed arm, graded blind by one grader, reported as verdict quality per
token (or verdict quality alone if per-lane token capture cannot be verified — the fallback is
declared, not improvised).

## 2. What exists

- **Sealed target set:** batch 2, G26–G50, `../target-set-batch2.md` — including its §"The
  adversarial brief" (the bare-arm lane brief) and the ratified **two-field verdict format**
  (`headline_status_correct` / `rationale_fresh`, each correct / incorrect /
  unverifiable-at-head, dual-keyed G<nn> + register claim id). This format is BINDING on the
  science arm; any preamble text that implies another vocabulary is subordinate to it.
- **Bare-arm data:** batch-2 lane findings (findings/T690–T693 et al.) and T706's grading
  (commit 8877a1d: opus 3/4 canaries, haiku blind).
- **The ratified preamble:** `untracked/race-g-science-arm-brief.md` — six-step science
  instruction; its grading discriminator (a verdict counts only with an executed discriminating
  test attached; enumerated-but-unrun scores zero) survives into this sprint unchanged.
- **Pilot exhaust:** T720/T721 ran the contradictory draft bundles to completion —
  DO-NOT-SCORE for the arm comparison; their findings inform the Test phase (did lanes execute
  tests, context cost, which vocabulary they chose under contradiction). Rows T717–T719
  retired unstarted; this sprint re-bundles the lanes.
- **Standing lessons:** D024 (normalize keys before agreement arithmetic),
  `../CORRECTION-corroboration-is-same-family.md`, wall-canary preregistration practice,
  `untracked/race-grading/anonymize.py`.

## 3. The work

1. **Spec:** the comparison instrument — what "quality" is (against what reference the ten
   lanes are scored, given Race G has no mechanical key), the pairing unit (per model per
   claim), the headline, and the declared fallback if token capture fails verification.
2. **Scope (MoSCoW):** Must: five science lanes over G26–G50, canaries included with identical
   preamble; one-grader blind re-grade of all ten lanes. Could: a second bare replicate to
   estimate run-to-run noise. Won't (this pass): new target sets, roster changes, preamble
   variants.
3. **Design:** grading protocol (single grader, blind to arm, anonymized lane findings, T706
   grades kept as grader-consistency check, never as the baseline); token-capture verification
   procedure per model; dispatch mechanics (fresh consoles, no batch-1 contamination clause).
4. **Test (before build):** the grader is an instrument and earns its first reading only after
   controls — see §4.
5. **Build:** dispatch lanes, collect findings, run the grading pass.
6. **Accept:** numbers audit — denominators (25 per lane), canary hit rates both directions,
   key-normalization report per D024, tokens per lane per arm or the declared fallback.

## 4. Named controls (mandatory core, per the standing instrument rule)

- **C1 grader null:** the grader re-grades one bare lane already graded by T706; agreement is
  reported. Disagreement is a finding about the instrument, not silently absorbed.
- **C2 seeded defect:** one fabricated lane-findings file — plausible verdicts, zero executed
  tests — inserted into the grading pool. The grader must score it zero. If it passes, the
  grading pass has no first reading.
- **C3 blinding check:** the grader is asked, per lane, to guess the arm. Better-than-chance
  identification is reported as a blinding failure alongside the results, not hidden.
- **C4 token capture:** before the headline is computed, per-lane token counts are shown to
  exist for all five models in this run; absent that, the headline is quality-only and says so.

## 5. Constraints carried in from rulings

Two-field verdict format binding (absorption ruling); real canaries, both directions
(seeded-false vs contrarianism, seeded-true vs rubber-stamping); coverage denominator is the
sealed 25 (ruling 35); audit loops cap 3 per phase (ruling 7c.21); briefs never name models —
the roster (same five as batch 2) is a design parameter of the pairing, assigned at dispatch.
