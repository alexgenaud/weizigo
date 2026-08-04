# Sprint — phased development with audit loops

**For algorithm work: new state representations, verifier/format/rule changes,
and publishable numbers.** Lighter work uses `DELEGATOR.md` briefs.

A **sprint** has a defined goal but no predetermined plan, reached through one
or more passes. A **pass** is one iteration (pass0 = MVP, pass1 = deferred
scope). A **phase** is one document within a pass.

The intent: flexibility, transparency, accountability — not bureaucracy,
not ceremony. The phase documents exist so agents perform the phases their
plan promised. The audits exist because they demonstrably catch defects early.

## The ladder

- **Task** — a `DELEGATOR.md` brief. No sprint machinery.
- **Sprint** — a coherent collection of work with a defined goal, reached
  through passes. Has spec, plan, and accept bookends.
- **Epic** — an arena: `docs/epic-NN-slug/` with `spec.md`, `decisions/`,
  and `sprints/`. Its goal emerges from completed sprints. Never delegated
  as a unit.

A worker may escalate a rung on discovering the work is harder than
specified — that is a finding, not a failure. A worker may never de-escalate.

## Bookends

Every sprint has **spec**, **plan**, and **accept**. Usually a draft spec
goes to Orcha, who delegates to a builder — the builder writes the real
`spec.md` inside the sprint, audited, then ratified by the sprint owner
(whoever commissioned the sprint). The plan (`plan.md`) is the builder's
strategy for the pass: phases, gates, parallelism, effort. The accept
(`accept.md`) closes the loop: what was achieved, denominators, known
limitations.

**The sprint never halts for ceremonial sign-off.** It halts only on:

1. **Premise reversal** — a critical claim flips.
2. **Plan amendment** — scope balloons, or a promised phase is dropped.
3. **Audit-cap residue** — blocker findings that need the owner's ruling.

## Directories

```
docs/epic-NN-slug/
    spec.md                  ← epic-level: rules, method, goal shape
    decisions/               ← epic-scoped ADRs
    sprints/<sprint>/
        passN/
            spec.md plan.md scope.md design*.md test.md build.md accept.md
        archive/             ← audits, drafts — absorbed then deleted at gate
```

**Archive gate exemption:** a file in `archive/` that the register (CLAIMS.md) cites must be promoted to
`docs/evidence/<claim-id>/` before the gate deletes the archive — claimlint C2 enforces this. `archive/`
is deletable; `docs/evidence/` is not. (CA-5: `sprints/verify-battery/archive/T172-blind-analysis.md` is the
standing example.)

Canonical phase docs (passN/) are unsuffixed, revised in place, carrying `Revision: N` and
`Status: PROPOSED | RATIFIED (date, sha)` in the header. (The rule is for phase documents; process docs
like this one may carry a lighter header.) Everything lives in
git — `untracked/` is where evidence goes to die.

## Channel

Cross-agent traffic lives under `untracked/msg/<epic>/<sprint>/` — never
a git-ignored directory under `docs/` (the evidence-store invariant).
Layout, pruning rule, and addressee convention are in
`docs/infra/channel.md`. The pruning rule authorizes deletion of a sprint's
channel directory once its `accept.md` is ratified; the epic-level channel
is pruned only when the epic closes, by human decision.

## Phases

One-word imperatives. The plan may add, skip, merge, or resequence.

| phase | file | when |
|---|---|---|
| Spec | `spec.md` | Bookend. What do we want? |
| Plan | `plan.md` | Strategy: phases, gates, parallelism, effort |
| Scope | `scope.md` | MoSCoW: what's in this pass, what's deferred |
| Design | `design*.md` | Data structures, format, errors, alternatives rejected, implementation order |
| Test | `test.md` | Acceptance tests + known-bad fixtures. **Written before implementation** |
| Build | `build.md` | Build log: decisions made, deviations from design |
| Accept | `accept.md` | Bookend. Findings, denominators, calibration, known limitations |

Tests before implementation is TDD — the 2B-5 positive-control failure is the
local scar that proves the rule.

## Audit gates

Different instruments per phase. Document review has found zero of this
project's real defects.

| gate | instrument |
|---|---|
| Spec, Plan | Document review, fresh session |
| Design | **Adversarial** review — attempt refutation, state a verdict |
| Test (before build) | Review tests **without reading the implementation** |
| After build | **Independent re-implementation** of the core check — different model, ideally different language |
| Accept | Numbers audit: denominators, calibration, standing epistemic rules |

## Audit loop

Two-round cap for document review. Residue routes — it never loops:

| residue | route |
|---|---|
| New genuine blocker at any round | Escalates immediately |
| Editorial | PASS-WITH-EDITS, applied as a diff |
| Judgment | Gate-holder accepts with rationale or orders REDO |
| Structural (would balloon this pass) | Descoped to next pass's scope |

Every finding ID must be dispositioned: fixed / rejected-with-reason /
escalated. A skipped ID is a failed task.

## Grading

**blocker** (cannot proceed) · **critical** (will produce wrong results) ·
**must** (violates spec or rule) · **should** · **could**

**PASS** (no blocker/critical/must — zero findings is praised) ·
**PASS-WITH-EDITS** (exact diff supplied) · **NEEDS-FIX** · **REDO**

Auditor briefs are minimal: scope, grading scale, hygiene rules. Fresh
session, no channel access, no prior audits, no author framing. Every
finding cites file+line against current text.

## Subagents

Dispatch per `docs/infra/agents/subdelegation.md` — commands and model
mechanics live there. Max two concurrent **DeepSeek pi-subagents** (API rate
limit); analysis is otherwise unlimited and mutation serial per
`docs/infra/delegation/ROLES.md` §Concurrency — the concurrency authority.
Plan.md declares what runs in parallel.

## Acceptance

1. Tests pass, including known-bad calibration fixtures
2. Audit gates pass, every finding ID dispositioned
3. Consumer-load smoke test (non-negotiable — 058 F1–F4)
4. **Commit → deploy → smoke for every mutating commit, before anything else**
   touches the store.  managent-integrity (T268, wired by T337 S5) compares
   deployed bin/ stamps against committed source and FAILS the suite on
   staleness.  A red suite from staleness blocks every other agent until the
   committer deploys — the staleness gate that T295 §5 had turned into a
   warning is now load-bearing again.
4. Sprint owner ratifies accept.md

## Engineering rules for standalone tools

1. One state file under `untracked/`. Never write to `docs/`, `src/`, `data/`, `artifacts/`.
2. Discover project root by walking up for `.git`.
3. `flock` any state file. Concurrency-safe.
4. Standalone binary. No unrelated project imports.
5. Shallow interface. Few commands, few flags. Structured metadata over many CLI flags.
