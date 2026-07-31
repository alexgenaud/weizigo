# Sprint — phased delegated development with subagent orchestration

**For algorithmic work: new state representations, verifier/format/rule changes,
and anything producing a publishable number.** Everything else uses the
`DELEGATOR.md` brief header. The strategy phase decides the intensity.

A **sprint** is one or more passes to complete a deliverable. A **pass** is a
single iteration (pass0 = MVP, pass1 = improvements). A **phase** is one unit
within a pass producing a single finalized document (`spec.md`, `design.md`,
etc.). Each phase has a writer and independent auditor subagents.

## When to sprint

| tier | trigger | intensity |
|---|---|---|
| **Heavy** | new algorithm, new state representation, change to a verifier/format contract/rule | full pipeline, all audit gates |
| **Light** | extending a reviewed instrument to a new goban size | spec + design note + tests + eval; one audit at eval |
| **Custom** | anything else the builder judges needs more than a brief | decided in strategy, ratified by human |

The builder declares the tier in `strategy.md`. A worker may escalate a tier
on discovering the work is harder than specified — that is a finding. A worker
may never de-escalate. The human ratifies.

## Three required checkpoints

| checkpoint | written by | ratified by |
|---|---|---|
| **Spec** | Human or Dabir (or builder if not provided) | Human |
| **Strategy** | Builder | Human |
| **Acceptance** | Builder | Human |

## Passes and directories

A sprint has one or more passes. Pass artifacts live in git under
`docs/design/<sprint>/pass0/`. They are not in `untracked/` — that is
where evidence goes to die (T13's probe source, `2x2.T12`'s census).

```
docs/design/<sprint>/spec.md          ← Spec (human, Dabir, or builder)
docs/design/<sprint>/pass0/           ← All phase deliverables
  strategy.md                         ← REQUIRED (first phase)
  scope.md                            ← if strategy calls for it
  design.md                           ← if strategy calls for it
  plan.md                             ← if strategy calls for it
  tests.md                            ← REQUIRED (written before implementation)
  build.md                            ← build log
  eval.md                             ← findings, denominators, known-bad pass
  *-audit.md                          ← auditor writes these
```

## Spec

Written before anything else. Ratified by the human before strategy begins.

## Strategy — the builder's instructions to itself

The builder reads the spec, then writes `strategy.md`. Answers:

- What are we building? (restate spec in own words)
- What tier: heavy, light, or custom?
- What phases does this pass need? Which can be skipped?
- Which phases get independent fresh audit? What audit instrument?
- Can any phases run in parallel via subagents?
- Effort estimate per phase.

The builder stops. The human ratifies or corrects, then says "proceed." If the
builder later wants to skip a phase it promised, it must update `strategy.md`
and get re-ratification.

## Phases within a pass

Work one phase at a time unless `strategy.md` explicitly parallelizes.

| phase | file | when |
|---|---|---|
| Scope | `scope.md` | MoSCoW: what's in this pass, what's deferred |
| Design | `design.md` | Data structures, state machine, file format, errors, alternatives rejected and why |
| Plan | `plan.md` | Implementation order, which files to create |
| Tests | `tests.md` | Acceptance tests + known-bad calibration fixtures. **Written before any implementation.** |
| Build | `build.md` | Build log: decisions made, deviations from design |
| Eval | `eval.md` | Findings, denominators stated, calibration results, wrong-answer pass rate |

### Why tests are written before implementation

`2B-5`'s positive control ran PSK through a *separate* code path, passed, and
gave zero coverage of the defective call site while reading as proof the
instrument was sensitive. A test written after the code is shaped by the code.
A test written first cannot be.

## Audit gates — different instruments per phase

Document review has found **zero** of the five real defects this project has
paid for (061 §0). The audit instrument must match the risk.

| gate | instrument | rule |
|---|---|---|
| **Spec** | Document review, fresh session | Different seat reads spec against human intent |
| **Strategy** | Document review, fresh session | Strategy is the builder's contract — an auditor checks it for completeness and soundness |
| **Design** | **Adversarial** review | The auditor must attempt refutation and state a verdict. Per the EXP-2A precedent |
| **Tests** (before build) | Review tests **without reading the implementation** | Ensures tests are shaped to the spec, not the code |
| **After build** | **Independent re-implementation** of the core check | Different model, ideally different language. This is the only instrument that has found every real defect here |
| **Eval** | Numbers audit | Denominators stated, known-bad fixture passes, standing rules 3–6 |

The build gate is the expensive one and non-negotiable for heavy tier.

## Subagent orchestration

The parent agent uses shell commands to dispatch phase writers and auditors.
See `docs/infra/agents/subdelegation.md` for the command reference.

### Pattern: write a phase with audit loop

```
# Parent dispatches the phase writer
pi --provider deepseek --model deepseek-v4-pro -p "You are DSPro/sprint-id. Read docs/design/<sprint>/pass0/spec.md and strategy.md. Write docs/design/<sprint>/pass0/design.md. Do not edit any other file."

# Parent dispatches an independent auditor
pi --provider deepseek --model deepseek-v4-pro -p "You are DSPro/sprint-id-audit. Read docs/design/<sprint>/pass0/design.md and spec.md. Audit for blockers, critical, must, should, could. Write findings to docs/design/<sprint>/pass0/design-audit.md. You are a fresh instance — do not read any prior audit of this file."
```

### Audit loop (up to three rounds)

If the audit returns blockers, critical, or MUST findings:

1. Parent reads the audit, incorporates findings into the phase document
2. Parent dispatches a **fresh** subagent auditor (not the same instance)
3. Repeat until no blockers, critical, or MUST findings remain
4. Maximum three rounds — if findings persist after three, escalate to human

### Parallel phases

When strategy.md permits parallelism, the parent dispatches writers
simultaneously. Example: scope and design can sometimes run in parallel if
the spec is tight. The parent collects results and sequences audits.

### Pattern: parallel audits of the same phase

```
# Two independent auditors, different models, run in parallel
pi --provider deepseek --model deepseek-v4-pro -p "Audit design.md..." &
pi --provider deepseek --model deepseek-v4-flash -p "Audit design.md..." &
wait
```

## Audit-finding grades

| grade | meaning |
|---|---|
| **blocker** | Cannot proceed — the deliverable is wrong or the premise is false |
| **critical** | Must fix before build — will produce wrong results |
| **must** | Must fix — violates a project rule or the spec |
| **should** | Should fix — improves quality, not blocking |
| **could** | Optional — nice to have |

Verdict: **PASS** (no blocker/critical/must) / **NEEDS-FIX** / **REDO**.

The auditor is a **fresh session with no shared context**. Per DELEGATOR.md
rule 5: give the reviewer less than you gave the worker.

## Final acceptance

1. All tests from `tests.md` pass, including known-bad calibration fixtures
2. All audit gates pass (no blocker/critical/must findings open)
3. End-to-end smoke test: the consumer loads the artifact
4. Human ratifies

The consumer-load test is non-negotiable. 058 F1–F4 all passed artifact-level
checks and failed the first time the engine tried to use the table. Four
seconds of end-to-end testing would have caught all four.

## Engineering rules for standalone tools

1. **One state file.** Use a single JSON file under `untracked/<project>/`.
   Never write to `docs/`, `src/` (except the tool's own sources), `data/`,
   or `artifacts/`.
2. **Callable from anywhere.** Discover project root by walking up for `.git`.
3. **Concurrency-safe.** `flock` any state file. Multiple shells may invoke it.
4. **Independent.** Standalone binary. Does not import unrelated project modules.
5. **Shallow interface.** Few commands, few flags. Parse structured metadata over
   many CLI flags.
