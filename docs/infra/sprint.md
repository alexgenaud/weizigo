# Sprint — phased delegated development with subagent orchestration

```
Revision: 4
Status: RATIFIED (G-human, 2026-07-31, c8d666a)
Rev 2 per msg 064 §4 (eight edits), 067 §2 (per-pass layout), rulings D-9…D-15.
Rev 3 per T154 round-1 fresh-seat review of rev 2 @ 6f8a53b. Dispositions,
all fixed / none rejected / none escalated: F1 design-<milestone>.md
exception stated; F2 external approval declared at spec ratification;
F3 human checkpoints defined as pass boundaries; F4 strategy named in the
phase list; F5 default gate-holder named; F6 role pointer added.
Rev 4 per T154 round-2 review of rev 3 @ 1a231f0 (5/6 RESOLVED): residual
must finding fixed — interrupt 2 broadened from weight escalation to
strategy amendment, covering mid-pass phase-skip re-ratification. Two-round
cap reached; this fix rides the ratification diff to the human gate per the
routing ladder — no round three.
```

The intent, in one line: flexibility, transparency, and accountability,
leading efficiently to robust reliable results — not bureaucracy, not
ceremony, not manic hacking either. The phase documents exist so agents
actually perform the phases their own strategy promised; the audits exist
because they demonstrably catch defects early.

## The ladder: task, sprint, epic

A **task** is lightweight — a `DELEGATOR.md` brief, no sprint. A **sprint**
is a coherent collection of ideas, specs, tasks or a project vision with a
**defined goal but no predetermined plan**, reached through one or more
passes. An **epic** has no well-defined goal yet — its goal emerges from
completed sprints.

This paragraph is the scope boundary. A worker may escalate a rung on
discovering the work is harder than specified — a task that is really a
sprint — and that is a finding, not a failure. A worker may never
de-escalate. The human ratifies.

## Bookends and checkpoints

Every sprint has **spec**, **strategy**, and **acceptance**. The spec is
usually written or drafted before delegation. A large sprint is also
approved externally — human, Dabir, Grand Auditor, or an agent product
owner (seats and role definitions live in the active milestone channel's
`STATE.md`). There is no numeric threshold for "large": whether a sprint
needs external approval beyond the human is declared in `spec.md` and
settled when the spec is ratified. The bookends — `spec.md` ("what do we
want?") and `accept.md` ("did we achieve it?") — must always be
understandable, writable, and ratifiable by the human.

**Human checkpoint model.** The human's checkpoints sit at pass
boundaries: ratifying `spec.md` and `strategy.md` as a pass opens,
`accept.md` as it closes. Between those bookends the human observes and
redirects **between passes**, not between phases — within a pass, agents
decide when they have collected sufficient evidence. Dabir reads phase
documents and summarizes.
A closed interrupt list must reach the human immediately at any point, with
no copy/paste relay:

1. **Premise reversal** — the veracity of a critical claim flips.
2. **Strategy amendment** — a task turns out to be a sprint, a pass's
   scope balloons beyond its ratified strategy, or the builder wants to
   drop a phase the strategy promised. The ratified strategy is a
   contract; amending it in either direction reaches the human.
3. **Audit-cap residue** that needs a human ruling (see the routing ladder
   below).

## Passes, revisions, and directories

A **pass is an iteration of the deliverable**: pass0 ships the MVP; pass1
takes what pass0's spec ambitioned but its `scope.md` explicitly deferred,
or reacts to a failed smoke test. Passes are healthy and are the human's
observation points. A **revision is the same document changing in place**
inside an audit loop — it never mints a file or a directory. Frozen
revision snapshots wearing pass clothing are the disease the oracle-v2
process review diagnosed: copies drift, and agents re-fix resolved findings.

```
docs/infra/<sprint>/passN/     ← ALL canonical phase docs, unsuffixed:
                                 spec.md strategy.md scope.md design*.md
                                 test.md plan.md build.md accept.md
docs/design/<sprint>/          ← ephemera: audits, notes, drafts — numbered,
                                 absorbed at the gate, then deleted
```

Canonical docs are in git, never in `untracked/` — that is where evidence
goes to die (T13's probe source, `2x2.T12`'s census). "Unsuffixed" bans
revision and audit suffixes (`-rev2`, `-audit-1`), not deliverable names:
a pass whose design spans several milestones carries one canonical doc per
deliverable (`design-M1.md`, `design-M2a.md` — the `design*.md` in the tree
above), each revised in place. One canonical document per phase
deliverable: the unsuffixed file, revised in place, carrying
`Revision: N` and `Status: PROPOSED | RATIFIED (Gn, date, sha)` in its
header. Audits and drafts are numbered ephemera under
`docs/design/<sprint>/`, absorbed into the canonical doc's disposition log
and deleted at the gate commit. Line references pin commits
(`spec.md @ 7ba70b7:118`), never frozen copies.

## Phases within a pass

Phase documents are one-word imperatives — `spec`, `scope`, `design`,
`test`, `plan`, `build`, `accept` — plus `strategy`, the one noun.
Strategy may add, skip, merge, resequence,
expand or shrink phases — the bookends are the invariant. Work one phase
at a time unless `strategy.md` explicitly parallelizes.

| phase | file | when |
|---|---|---|
| Spec | `spec.md` | REQUIRED bookend. What do we want? Ratified before strategy begins |
| Strategy | `strategy.md` | REQUIRED (first phase after spec) |
| Scope | `scope.md` | MoSCoW: what's in this pass, what's deferred |
| Design | `design.md` | Data structures, state machine, file format, errors, alternatives rejected and why |
| Plan | `plan.md` | Implementation order, which files to create |
| Test | `test.md` | Acceptance tests + known-bad calibration fixtures. **Written before any implementation** |
| Build | `build.md` | Build log: decisions made, deviations from design |
| Accept | `accept.md` | REQUIRED bookend. Findings, denominators stated, calibration results, known limitations (descoped residue) |

## Strategy — the builder's instructions to itself

The builder reads the spec, then writes `strategy.md`. Answers:

- What are we building? (restate spec in own words)
- What phases does this pass need? Which are skipped or merged, and why?
- Which phases get independent fresh audit? What audit instrument?
- Can any phases run in parallel via subagents?
- Effort estimate per phase.

The builder stops. The human ratifies or corrects, then says "proceed." If
the builder later wants to skip a phase it promised, it must update
`strategy.md` and get re-ratification — a strategy amendment, interrupt 2
in the checkpoint model, which is how a human touchpoint can occur
mid-pass.

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
| **Test** (before build) | Review tests **without reading the implementation** | Ensures tests are shaped to the spec, not the code |
| **After build** | **Independent re-implementation** of the core check | Different model, ideally different language. This is the only instrument that has found every real defect here |
| **Accept** | Numbers audit | Denominators stated, known-bad fixture passes, standing epistemic rules 3–6 (carried today in the active milestone channel's `STATE.md`, §"Standing epistemic rules") |

The build gate is the expensive one and non-negotiable for a full-pipeline
sprint. After design freeze, the audit budget shifts from prose to code —
the acceptance harness and independent re-implementation, not another
reading.

## Audit loop — two-round cap and the routing ladder

For document review the loop is capped at **two rounds**. The oracle-v2
evidence: round one was sprint-saving, round two still positive, round
three net-negative (one typo, one phantom finding, re-verification tax).
If the audit returns blocker, critical, or MUST findings:

1. Author incorporates findings into the canonical doc (revision in place).
2. A **fresh** auditor (not the same instance) re-audits. That is round two.
3. After round two, residue **routes** — it does not loop:

| residue | route |
|---|---|
| **Premise reversal or new genuine blocker** | Escalates to the human immediately, **at any round** — the cap governs residue, not discoveries |
| **Editorial** | Rides PASS-WITH-EDITS into the gate as a diff |
| **Judgment** | Goes to the gate as a checklist; the gate-holder accepts with rationale or orders **REDO** — a fresh writer and fresh brief, a different instrument than round three of the same loop |
| **Structural** (real, but fixing it would balloon this pass) | **Descoped**: named in this pass's `accept.md` as a known limitation, first item in the next pass's `scope.md` |

Unless `strategy.md` names another seat, the gate-holder is the human.
Passes are the escape valve the audit cap needs; a sprint that can iterate
doesn't have to loop. The cap never forces acceptance of a broken document.

**Caveat:** the evidence base is spec and design phases of one sprint.
Build and accept gates use different instruments (re-implementation,
harnesses, smoke tests) whose loop behavior we have not observed. The
two-round cap is the default for *document review*; for other gates it is
provisional guidance.

**Disposition-log-as-acceptance.** A revision is incomplete unless every
open finding ID has a disposition — fixed / rejected-with-reason /
escalated. A skipped ID is a failed task.

## Audit-finding grades and verdicts

| grade | meaning |
|---|---|
| **blocker** | Cannot proceed — the deliverable is wrong or the premise is false |
| **critical** | Must fix before build — will produce wrong results |
| **must** | Must fix — violates a project rule or the spec |
| **should** | Should fix — improves quality, not blocking |
| **could** | Optional — nice to have |

Verdicts:

- **PASS** — no blocker/critical/must findings. Zero new findings is an
  acceptable — praised — PASS.
- **PASS-WITH-EDITS** — the auditor supplies exact edits for editorial
  findings; the author applies them; the gate ratifies the diff.
- **NEEDS-FIX** — reserved for findings requiring design judgment.
- **REDO** — fresh writer, fresh brief.

**Auditor briefs are minimal**, and state the hygiene rules explicitly:
scope (which directory or phase, against which spec), the grading scale,
and nothing more. A fresh auditor audits one phase or the pass so far —
never the global project. No channel access, no prior audits, no author
framing. Per DELEGATOR.md rule 5: give the reviewer less than you gave the
worker. Hygiene: every finding cites file+line verified against the
*current* text (the RV2-1 phantom rule); acceptance criteria are cited by
slug (`A1-refusal`) or verbatim quote, never bare number.

## Subagent orchestration

Dispatch per `docs/infra/agents/subdelegation.md` — model choice, provider
commands, and dispatch mechanics live there and only there; they are
model-specific and churn.

When `strategy.md` permits parallelism, the parent dispatches phase writers
simultaneously, collects results, and sequences audits — respecting
subdelegation.md's max-two-concurrent rule.

## Final acceptance

1. All tests from `test.md` pass, including known-bad calibration fixtures
2. All audit gates pass (no blocker/critical/must findings open; every
   finding ID dispositioned)
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
