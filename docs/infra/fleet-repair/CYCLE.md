# fleet-repair — the sprint's phase/audit ladder and model assignments

**Owner:** Orchestrator seat (commissioned it). **Protocol:** `docs/infra/sprint.md`
(phases, audit gates, two-round audit loop). **Worked example of the shape:**
`docs/infra/tool-consolidation/`.

**Operator direction, 2026-08-20, which this file exists to obey:** *"Dispatch sprints
with full proper development cycles — spec, audit loop, research, audit loop, scope and
acceptance tests, audit loop, plan, audit loop, test red then implement then test
green, audit loop, verify and smoke, audit loop, gather knowledge, absorb findings,
lessons learned, record performance stats, commit. NO EXCEPTIONS."*

## The ladder, one row per phase, one row per gate

Every phase is a separate dispatched row. Every gate is a separate row on a
**different model** from the phase it audits — which is both the independence
requirement (`sprint.md`: verification goes to a different party) and the mechanism
that generates the operator's model comparison as a side effect of doing the work
properly.

| # | phase | deliverable | gate instrument (`sprint.md`) | row |
|---|---|---|---|---|
| 1 | Spec | `pass1/spec.md` | document review, fresh session | `T549` → gate `T550` |
| 2 | Plan | `pass1/plan.md` | document review, fresh session | registered when spec ratifies |
| 3 | Scope | `pass1/scope.md` (MoSCoW) | document review | after plan |
| 4 | Design | `pass1/design.md` | **adversarial** — attempt refutation, state a verdict | after scope |
| 5 | Test | `pass1/test.md` — **written before implementation** | reviewed **without reading the implementation** | after design |
| 6 | Build | `pass1/build.md` + the code | **independent re-implementation of the core check, different model, ideally different language** | after test is green-gated red |
| 7 | Verify | smoke + suite + claimlint | numbers audit | after build |
| 8 | Accept | `pass1/accept.md` | numbers audit: denominators, calibration | bookend |

Absorption, lessons learned and model-performance stats are recorded at Accept, then
committed — the tail of the operator's list.

## Rules the Orchestrator binds itself to here

1. **The seat writes briefs and rules on verdicts. It does not write phase docs, code,
   tests or scripts.** Today's drift — hand-patching, running gates inline, writing an
   untested process-killer — is what this ladder replaces.
2. **One phase in flight at a time.** No parallel phases, no speculative next-phase
   dispatch. A gate must close before its successor is registered.
3. **Tests before implementation, red before green.** Non-negotiable; the 2B-5
   positive-control failure is the local scar.
4. **No new supervisory processes.** The fix is that the mechanism works, not that
   something watches it. The reaper/watchdog/monitor stack of 2026-08-20 is torn down
   and must not return as a deliverable.
5. **Discovery is closed** at the 17 items in `docs/status/tooling-defects-2026-08-20.md`.
   An 18th found in passing is recorded in a findings file, not added to scope.

## Model assignment, and why (recorded so the comparison is deliberate)

| row | phase | model | reason |
|---|---|---|---|
| `T549` | Spec | `dspro` | Long-form authoring (task type T-E) is where DeepSeek-Pro has the least data; the folklore says a Claude model should write specs, and this sprint tests that instead of assuming it. |
| `T550` | Spec gate | `fable` | Different family from the author (independence), and holistic document review is its claimed strength — a claim now under test. |

Later assignments follow the same rule: **author and auditor never the same model, and
never the same family where the roster allows**, with each choice's reason recorded
here at dispatch. The interim allocation default (`flash` unless a reason is stated —
`docs/infra/model-perf.md`) applies to mechanical phases; authoring and adversarial
phases state their reason.
