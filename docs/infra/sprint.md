# Sprint — phased delegated development

**For subagents building standalone tools or features.** Read before coding.

## Three required checkpoints

Every sprint has three non-negotiable checkpoints. Without them, there is
no evidence of understanding or delivery.

| Checkpoint | Written by | Ratified by |
|---|---|---|
| **Spec** | Human/Boss (or builder if not provided) | Human/Boss |
| **Strategy** | Builder | Human/Boss |
| **Acceptance** | Builder | Human/Boss |

**Spec** says *what* to build. **Strategy** says *how* to build it.
**Acceptance** proves it was built correctly.

## Passes and directories

A sprint has one or more passes (pass0 = MVP, pass1 = improvements, etc.).
Most sprints need only pass0.

Intentions live in `docs/`. Development artifacts live in `untracked/`.
After the sprint, distill what was learned back into `docs/` and prune
the pass artifacts. Do not leave implementation details in `docs/` —
replace them with pristine documentation.

```
docs/infra/<project>/spec.md        ← Spec (Boss or builder writes)
untracked/<project>/pass0/          ← All phase deliverables for this pass
  strategy.md                       ← REQUIRED
  scope.md                          ← if strategy calls for it
  design.md                         ← if strategy calls for it
  plan.md                           ← if strategy calls for it
  build.md                          ← if strategy calls for it
  test.md                           ← REQUIRED (acceptance tests)
  *-audit.md                        ← auditor writes these
```

## Spec

Written before anything else. Usually by the human or Boss. If the builder
receives no spec, it must write one. The spec is ratified — the human
confirms "yes, this is what I want" — before strategy begins.

## Strategy

The builder reads the spec, then writes `strategy.md`. This is the
"Understand" checkpoint. The builder stops. The human reads, confirms or
corrects, then says "proceed."

strategy.md answers:
- What are we building? (restate spec in own words)
- What phases does this pass need? Which can be skipped?
- Which phases get independent fresh audit?
- Can any phases run in parallel? Multiple subagents?
- Effort estimate per phase.

The strategy IS the builder's instructions to itself. Every phase listed
MUST produce a document. If the builder later wants to skip a phase it
promised, it must update strategy.md and get re-ratification.

## Phases within a pass

Work one phase at a time unless strategy.md explicitly parallelizes.
Each phase produces one file in the pass directory.

| Phase | File | When |
|---|---|---|
| Scope | `scope.md` | MoSCoW: what's in this pass, what's deferred |
| Design | `design.md` | Data structures, state machine, file format, errors |
| Plan | `plan.md` | Implementation order, which files to create |
| Build | `build.md` | Build log: decisions made, deviations from design |
| Test | `test.md` | Acceptance tests — written early, run after build |

### Audit gate (between phases, as needed)

After a phase deliverable, stop and announce readiness for independent
audit. The auditor must be a **fresh session** with no shared context.
Audit findings are graded (blocker, critical, must, should, could).
The builder addresses findings before proceeding.

```
Agent:   "pass0/design.md complete. Ready for Audit.
          Suggested prompt: DeepSeek 1m: ruthlessly audit
          untracked/<project>/pass0/design.md against
          docs/infra/<project>/spec.md. Grade findings
          (blocker/critical/must/should/could). Write to
          untracked/<project>/pass0/design-audit.md."

Human:   spawns fresh auditor

Auditor: writes audit with grades + PASS / NEEDS-FIX / REDO verdict

Human:   tells builder to continue

Builder: reads audit, addresses findings, records resolutions, proceeds
```

Highest-leverage audit points: **design.md** (catch architecture errors
before code) and **test.md** (catch untested criteria, missing edges).

### Final acceptance

When all phases complete, run the full acceptance suite:
1. All unit tests pass (`zig test`).
2. All acceptance tests from `test.md` pass.
3. Smoke test (manual or automated — does the thing work end-to-end?).
4. Human/Boss signs off.

The test.md was written early (during scope or design). Now it is
executed. Record results: pass/fail for each criterion. Report any
test that cannot be run.

## Engineering rules

1. **One state file.** If the tool needs mutable state, use a single JSON
   file in `untracked/<project>/`. Never write to `docs/`, `src/` (except
   the tool's own sources), `data/`, or `artifacts/`.
2. **Callable from anywhere.** The tool discovers its project root (walk
   up looking for `.git`) and resolves relative paths from there.
3. **Concurrency-safe.** Use `flock` on any state file. Multiple shells
   may invoke the tool simultaneously. No corruption, no races.
4. **Independent.** The tool is a standalone binary. It does not import
   unrelated project modules. `zig build-exe src/<project>/main.zig`.
5. **Shallow interface.** Few commands, few flags. Prefer parsing
   structured metadata from input files over requiring many CLI flags.
   If in doubt, collapse two flags into one smarter behavior.

## Acceptance test pattern

```
# Setup
$ rm -f untracked/<project>/state.json

# Test: register
$ ./<project> add <args>
  EXPECT: <output>

# Test: claim
$ ./<project> claim <args>
  EXPECT: <output>

# Test: status
$ ./<project>
  EXPECT: <pattern>
```

Each test: setup, command, expected output. Run in order, top to bottom.
Record pass/fail for each in `test.md`.
