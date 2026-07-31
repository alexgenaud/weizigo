# Orcha-tools — T159 build review (R1–R3)

```
Author:   DSFlash/T160 · 2026-07-31
Scope:    T159 orcha-tools sprint — managent suggest (R1), done deliverable
          check (R2), audit cross-citation flag (R3), vs
          docs/infra/orcha-tools/pass0/spec.md rev 1 (PROPOSED).
Method:   source review (src/managent/main.zig @ 4d70d0d), live binary
          probes (bin/managent, built 2026-07-31 04:45), kanban state
          (docs/infra/managent/tasks.json), git history.
Grade:    NEEDS-FIX — no implementation exists for any of R1–R3.
```

## 0. Verdict

**NEEDS-FIX.** T159 delivered no code, no spec update, and no git evidence.
All three acceptance criteria (A1–A3) fail on the live tool. The held file
`src/managent/main.zig` is byte-identical to the pre-task HEAD (0988e5a,
2026-07-31 01:49); the kanban shows T159 `dispatchable`, never claimed,
never done. There is nothing to re-audit yet — the sprint needs a real
build, then this review rerun.

## 1. Requirement-by-requirement

### R1 — `managent suggest <slug>` — NOT IMPLEMENTED

Spec: prints next T-ID, creates `untracked/T<id>-<slug>.md`, prints
`You are <model>/T<id>. ...` prompt line.

Evidence:

- Command dispatch table (`src/managent/main.zig:155–201`) has no `suggest`
  branch; `grep -n suggest src/managent/main.zig` → 0 hits.
- Live probe: `./bin/managent suggest my-task` → stderr `unknown command:
  suggest`, exit 1. **A1 FAILS.**

### R2 — `managent done <id>` verifies declared deliverables — NOT IMPLEMENTED

Spec: refuses (non-zero exit, task stays `in_progress`) when a declared
deliverable is missing on disk.

Evidence:

- `cmdDone` (`src/managent/main.zig:1269`) opens with `_ = repo_root;`
  (line 1270) — the repo root is discarded, so no path can be checked.
  The success path (lines 1341–1378) sets `.done` and unblocks dependents;
  the only refusals are status gating, missing agent, and `--fail`
  attribution. No deliverable existence check anywhere.
- The kanban schema has no deliverable field (only `holds`, which `done`
  never probes on disk); a task whose `holds` path does not exist closes
  cleanly. **A2 FAILS.**

### R3 — `managent audit` flags uncited deliverables — NOT IMPLEMENTED

Spec: flags done tasks whose deliverable paths are not cited in CLAIMS.md
or PROGRESS.md.

Evidence:

- `cmdAudit` (`src/managent/main.zig:2487`) runs eight check families —
  needs-gating, claim-before-dependency, unclaimed-done, GATED notes,
  heartbeats, holds-not-in-git, stale binary, uncommitted CLAIMS.md diff —
  none of which reads the *content* of `docs/epistemic/CLAIMS.md` or
  `docs/epistemic/PROGRESS.md` to cross-cite a done task's deliverables.
- Live probe: `./bin/managent audit` → `audit: clean — no discrepancies
  found`, exit 0, even though the A3 fixture (T129's QA-027 certified-
  fraction finding; PROGRESS.md:346 still says the measurement is
  *pending* the 4×4 re-run) is exactly the uncited case. **A3 FAILS.**

## 2. Process findings

- **No git evidence.** `git log --all -- src/managent/` top is 0988e5a
  (T122 final, 01:49). T159 registered 14:42:43Z (4d70d0d). Source mtime
  01:46, `bin/managent` 04:45 — every artifact predates the task. No
  branch, stash, or patch carries the work. This violates the standing
  rule "evidence in git, or the claim is not proven."
- **Kanban state contradicts a completed build.** `docs/infra/managent/
  tasks.json`: T159 `status: dispatchable`, `claimed: null`, `done: null`,
  `claim_count: 0`. The only file T159 owns on the kanban is its own
  brief. If the Orchestrator believes T159 built anything, that belief
  rests on a claim outside the kanban and outside git.
- **Interface contract not updated.** `docs/infra/managent/spec.md` (the
  spec *of the tool*) documents eighteen commands; `suggest` is not among
  them and `done`/`audit` are not amended for deliverable semantics. A
  correct build must update this contract in the same commit.
- **No sprint-1 artifact directory.** `docs/design/orcha-tools/` did not
  exist until this review created it — the other parallel sprints
  (argus, verify-battery, oracle-v2) each have one.

## 3. Why the review stopped there

Per AGENTS.md, an auditor traces one complete evaluation end-to-end. For
R1–R3 there is no evaluation to trace: the dispatch table, the source
grep, the live binary, and git history agree that the feature set does
not exist. Re-verifying absence in more ways (e.g. rebuilding from source)
would not change the grade and would manufacture ceremony where the honest
finding is a stopped build.

## 4. Recommended path

1. Dispatch T159 for real (it is still `dispatchable`; `claim` it, keep
   its hold on `src/managent/main.zig`), with a brief that enumerates the
   three requirements and A1–A3 verbatim.
2. Require, in one commit: (a) `suggest` + T-ID allocator, (b) `done`
   deliverable check against a declared deliverable list, (c) `audit`
   cross-citation check reading CLAIMS.md/PROGRESS.md, and (d) the
   `docs/infra/managent/spec.md` amendment for all three.
3. Rerun this review (review-2) against the committed diff; A1–A3 must
   pass on the live binary, with the A3 fixture exercised as specified.
