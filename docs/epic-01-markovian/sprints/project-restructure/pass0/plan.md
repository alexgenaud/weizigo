# project-restructure pass0 — PLAN

```
Revision: 2
Status:   PROPOSED
Author:   DSPro/T190 (project-restructure builder) · 2026-08-01
Audit:    T191 (DSPro, fresh seat) · PASS-WITH-EDITS · 7 findings · 2026-08-01
Source:   spec.md (Revision 1, PROPOSED)
```

## 0. Restatement of the spec

The human wants the project tree reorganized so an agent arriving cold can
find what backs a claim in one hop. Three retrieval failures, one cause:
the tree records *when* things were written, not *what question they answer*.

Item 1 (epic/sprint directory hierarchy) was pre-empted by Navigator's tree
move (msg 070 §1, commits d51a068 + 41000c6). Item 2 (epistemic tree
reorganization) and item 3 (channel organization and pruning) are the
substance of this pass.

The spec's key constraint: "change nothing" is an acceptable outcome for any
item, provided this sprint says so and says why. No claim status may change
(R2-6). No file in `docs/evidence/` may have its prose rewritten to keep
links green — provenance text is frozen (R2-2). Every move uses `git mv`
(A5).

## 1. Phases for this pass

| phase | file | notes |
|---|---|---|
| Spec | `spec.md` | Done (Revision 1, PROPOSED). Audited by fresh seat; ratify before build. |
| **Plan** | `plan.md` | This document. |
| Scope | `scope.md` | MoSCoW across all three items, including item 1 residue. |
| Design | `design.md` | Layout decisions for items 2+3. Single design doc — items share a commit. |
| Test | `test.md` | Baseline claimlint run + link check scripts + known-bad calibration. |
| Build | `build.md` | Execution log: moves, rewrites, script runs. |
| Accept | `accept.md` | Verdict per item, denominators, claimlint comparison, calibration. |

**Halt conditions** per sprint.md §Bookends: the sprint halts only on premise
reversal, plan amendment, or audit-cap residue. The builder escalates if any
fires; otherwise work proceeds without ceremonial sign-off.

**What this pass does NOT need:**
- No adversarial design review (no algorithm change; the design is a layout
  choice, auditable by document review).
- No independent re-implementation audit gate (no logic changed).
- No consumer-load smoke test (no consumer-facing tool changed; claimlint
  is a linter, exercised by its own calibration battery).

**Audit gates for this pass:**

| gate | instrument | who |
|---|---|---|
| Spec | Document review, fresh seat | Done per sprint.md — ratify before build |
| Plan (this doc) | Document review | Orchestrator (or delegate); lightweight — plan is strategy, not code |
| Design | Document review (not adversarial) | Fresh seat — verify layout satisfies R2-1 through R2-6, R3-1 through R3-4 |
| Test (before build) | Review tests without reading implementation | Fresh seat |
| After build | Claimlint calibration battery + link checker | Automated — zero new findings, calibration still PASS |
| Accept | Numbers audit: denominators, calibration, standing epistemic rules | Orchestrator |

## 2. Parallelism

Items 2 and 3 are independent and can be designed in parallel — but only one
builder (this agent) exists for this sprint. Sequencing:

1. `scope.md` — serial (defines what's in/out for all items)
2. `design.md` — items 2 and 3 designed together (they share the commit and
   the git-ignore invariant)
3. `test.md` — serial (depends on design to know what will move)
4. `build.md` — serial (executes the design)
5. `accept.md` — serial (closes the loop)

No subagent parallelism. The entire pass is one builder, one sequence.

## 3. Item-by-item strategy

### Item 1 — verification & residue

Navigator's tree move (d51a068, 41000c6) executed the directory hierarchy. My job is:

**V1 — Verification (confirm what Navigator did):**
- Confirm all sprints live at `docs/epic-01-markovian/sprints/<sprint>/` (seven at plan-time: argus, knowledge-capture, oracle-v2, orcha-tools, project-restructure, subagent-harness, verify-battery)
- Confirm `docs/infra/<sprint>/` and `docs/design/<sprint>/` are gone
- Confirm `strategy.md` → `plan.md` rename is complete across tracked files
- Confirm sprint.md describes the tree that exists (note: sprint.md at HEAD has no revision header — rewritten 200b974; substance intact, header absent)
- Confirm `git log --follow` works for every moved file

**V2 — Residue (what the tree move deliberately left for this sprint):**
- R1-1: settle the epic name. The channel calls it `milestone-01-ko-reframe`;
  the tree calls it `epic-01-markovian`. Two names for one thing is a retrieval
  defect (spec §R1-1). Options: (a) rename the channel directory, (b) rename
  the epic tree directory, (c) document the alias and move on. The design
  chooses one and the sweep applies it. Also settle "epic" vs "milestone" —
  sprint.md uses "epic." The channel and INDEX.md use "milestone." Pick
  one word.
- R1-3: write the epic `spec.md`. This is the hierarchy's value — the document
  at its root. Content to absorb from `docs/INTENT.md`,
  `docs/epistemic/PROGRESS.md`, and `docs/epistemic/roadmap-2026-07-28.md`,
  stated explicitly with absorption notes. If I cannot write a useful one in
  this pass, I record that as a scope deferral to pass 1.
- R1-2: sprint.md rev 5 ratification. Navigator left it PROPOSED. The human
  must flip it to RATIFIED. This sprint's design.md flags the ratification gap;
  accept.md records whether it was closed.
- R1-5: verify `passN/` semantics are intact (no `pass0/` copies of revision
  documents).
- Update this sprint's `spec.md` header path reference (R1-4 — it already
  points to the right location since we're in it, but verify).

**Cost estimate:** low. Verification is mechanical (`ls`, `git log --follow`,
`grep`). Epic `spec.md` is the only writing task. Updating the channel
directory name (if chosen) is one `mv`.

### Item 2 — epistemic tree reorganization

The expensive item. Strategy: **start with the orphan/re-verification backlog
(R2-4) — it has unconditional value regardless of layout — then design the
layout, then execute.** The key principle from the spec: retrieval is the
acceptance criterion, relocation is a means (R2-1).

**Phase A — Backlog (due regardless of layout):**
- Take the claimlint output at HEAD: 10 C1a orphans, 12 C2 dangling paths, 79
  C3 PROVEN-without-evidence rows, 30 C4 dangling IDs, 4 C5 shadowed, 5
  repeated-narrowing smells. (Note: the spec, written at 45deb10, reported 13
  C2 and 73 C3. These counters are dynamic — the backlog uses the live run,
  not the spec's snapshot.) Produce a dispositioned list.
- Every row gets: owner, disposition (*fix now / backlog with task ID / demote
  status / accept with reason*), and a one-line rationale.
- Output: committed document(s) under this sprint's pass0 or archive.
- This satisfies R2-4 and the re-verification backlog half of A6.

**Phase B — `boards/` verdict (R2-5):**
- Determine whether the six per-goban `EPISTEMIC.md` trees are live or dead.
- INDEX.md still routes to them. CLAIMS.md is the authoritative register.
- If dead: add a banner to each stating they are superseded by CLAIMS.md, and
  update INDEX.md to point only to CLAIMS.md.
- If live: document who reads them and why they aren't folded into CLAIMS.md.

**Phase C — Layout design:**
- The measurable want (R2-1): hop count from claim ID → evidence, and from
  question → answer document.
- Current hop count: claim ID → CLAIMS.md (1 hop to find evidence column) →
  evidence path → `docs/evidence/<id>/` (1 more hop). That's already 2 hops
  for the primary path. The problem is the *quality* of those hops: CLAIMS.md
  is flat, `docs/evidence/` is a claim-ID-keyed directory whose index is
  generated, and nothing tells you why one claim depends on another without
  reading CLAIMS.md's graph.
- Options the design considers:
  a. **Index-only** — regenerate/improve `docs/INDEX-claim-evidence.md` and
     `docs/INDEX-claim-task.md`, add a dependency-tree index. Zero moves.
     Satisfies R2-1 by improving hop count without relocating.
  b. **Reorganize `docs/epistemic/`** — group by function (register, narrative,
     glossary, dated-critiques, dated-adjudications) under subdirectories.
     Moves ~12 files, updates ~299 references.
  c. **Move `docs/evidence/` under `docs/epistemic/`** — makes the evidence
     store a sub-tree of the epistemic tree. Touches `.gitignore`, claimlint
     source, ~591 references. Expensive.
  d. **Do nothing** — the current layout is serviceable; the real retrieval
     problem is the backlog and the per-goban relic, not the flat directories.

  The design picks one (or a combination) and justifies it against R2-1.
  Given the cost of c (~591 references + claimlint source + gitignore
  invariant), and the spec's explicit permission to satisfy R2-1 with indices
  alone, I expect the design to lean toward (a) or (b), and to defer (c) to
  pass 1 unless the index-only approach proves insufficient.

- R2-2: provenance text in `docs/evidence/**` and `docs/audits/**` is frozen.
  Any move that would break links inside those files leaves them as-is and
  documents the pointer.
- R2-3: any relocation updates `src/claimlint.zig` constants (lines 105, 125,
  139, 394), `.gitignore` rules (lines 29-33), and re-runs the calibration
  battery in the same commit.
- R2-6: zero claim status changes. The design states this as a build rule.

### Item 3 — channel organization

Lower cost, fewer unknowns. Strategy: **write the pruning rule, decide the
split question, and if relocation is chosen, execute it.**

**Phase A — The addressee split (R3-4):**
- The filename convention already encodes addressees
  (`068-dabir-to-orchestrator.md`). A numbered sequence readable by every seat
  has value.
- Recommendation: "considered, rejected." One paragraph. Satisfies R3-4.

**Phase B — The pruning rule (R3-3):**
- Write a rule of the form: "when pass N of sprint S closes, its channel may be
  archived or deleted, because the canonical record is the phase documents."
- Commit this rule — it's the deliverable.
- Explicitly do NOT execute it against `milestone-01-ko-reframe` (out of scope).

**Phase C — Relocation (R3-1, R3-2):**
- The spec asks to consider `docs/epic-01-markovian/sprints/<sprint>/channel/`
  (git-ignored, inside `docs/`) vs `untracked/msg/<sprint>/` (wholly in
  `untracked/`).
- The argument against `docs/**/channel/`: it inverts the `docs/evidence/`
  invariant (if it's under `docs/`, it's in git). A git-ignored directory
  inside `docs/` reads canonical and is not — the exact failure mode that
  destroyed T13's evidence.
- My recommendation: channel stays under `untracked/msg/`, subdivided per
  sprint there (`untracked/msg/epic-01-markovian/<sprint>/`). The design
  justifies this against the alternative explicitly (R3-1).
- R3-2: if `STATE.md` or `DECISIONS.md` move, update `sprint.md` and
  `INDEX.md` pointers in the same commit.
- The current channel (92 files) is NOT deleted or archived in this pass
  (R3-3). It may be *copied* to a new location as a template, leaving the
  original in place.

## 4. Acceptance criteria for this pass

| criterion | spec ref | how measured |
|---|---|---|
| A1-verdict | spec §4 | accept.md carries explicit verdict for each of 3 items |
| A2-no-regression | spec §4 | claimlint baseline committed in test.md; post-build run has ≤ C1a, ≤ C2, calibration PASS |
| A3-links | spec §4 | link checker script run before/after; frozen provenance files listed with rationale |
| A4-process-coherence | spec §4 | sprint.md + INDEX.md describe the tree that exists; every path resolves |
| A5-history | spec §4 | every move is `git mv`; `git log --follow` verified |
| A6-backlog | spec §4 | orphan/re-verification documents committed, every row dispositioned with owner |
| A7-no-adjudication | spec §4 | diff changes zero claim statuses, zero numbers, zero ADR conclusions |
| A8-build | spec §4 | `zig build` succeeds; claimlint calibration battery passes |

## 5. Risk assessment

1. **Item 2 layout design is open-ended.** The spec deliberately prescribes
   nothing. The design could land anywhere from "index-only, zero moves" to
   "full tree relocation." The scope.md should set a hard ceiling: moves that
   touch claimlint source *and* `.gitignore` *and* 500+ references in one
   commit are a pass-1 task. Pass 0 should be indices + backlog + boards
   verdict + `docs/epistemic/` reorganization only if the design can show a
   clear hop-count improvement with ≤ 50 file moves.

2. **claimlint is already failing (exit 1).** "No worse than baseline" means
   the 10 C1a and 12 C2 numbers must not increase. The baseline run must be
   committed before the first file move so no one can argue the move caused a
   pre-existing finding.

3. **Epic spec.md is a writing task, not a mechanical one.** If I cannot
   produce a useful one in this pass, I must defer to pass 1 rather than
   shipping a stub (spec risk 4). The spec explicitly says a stub "reads as
   progress while changing nothing."

4. **sprint.md rev 5 ratification is external.** The human must flip the
   status. If it remains PROPOSED at accept.md time, I record it as an
   open dependency — process-coherence (A4) is partially unsatisfied.
   Note: sprint.md at HEAD (200b974) has no revision header — the
   rewrite removed it. The substance (phases, gates, halt conditions)
   remains intact regardless.

5. **Channel directory rename touches 92 files.** If R1-1 chooses to rename
   the channel from `milestone-01-ko-reframe` to `epic-01-markovian`, that's
   a `git mv` of a directory tracked only in `untracked/` (which is git-ignored
   — so it's actually an `mv`, not `git mv`). Low risk mechanically, but every
   reference in live documents must be updated. If the channel directory is not
   in git (it's in `untracked/`), then A5 does not apply to it — there is no
   `git log --follow` to preserve.

## 6. Effort estimate

| phase | effort | notes |
|---|---|---|
| scope.md | small | MoSCoW across items; mostly decisions already made above |
| design.md | large | Item 2 layout is the open design problem; item 3 is mechanical |
| test.md | medium | Capture claimlint baseline, write link-check script, list frozen files |
| build.md | medium | Execute moves, update references, re-run claimlint |
| accept.md | small | Compile results, compare baselines, state verdicts |

The design phase is the fulcrum. If the design chooses index-only for item 2,
build is small. If it chooses `docs/epistemic/` reorganization, build is
medium. If it chooses `docs/evidence/` relocation, build is large and should
be deferred to pass 1.

---

**Next phase:** `scope.md` — MoSCoW for all three items, including explicit
deferral decisions for the expensive paths.
