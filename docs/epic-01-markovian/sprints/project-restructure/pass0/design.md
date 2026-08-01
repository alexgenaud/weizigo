# project-restructure pass0 — DESIGN

```
Task: T200 · Role: sprint-manager · Model: DSPro · Date: 2026-08-01
Revision: 1
Status:   PROPOSED
Source:   scope.md rev 2 · plan.md rev 2 · spec.md rev 1
Gate:     Document review by fresh seat (per plan.md §1)
```

Target-state layout for items 2 (epistemic tree) and 3 (channel). Item 1 is
verification + residue only — no new tree moves (Navigator pre-empted them).
This design is complete enough that pass 1's builder needs only to execute.

---

## 0. Summary of decisions

| # | decision | rationale |
|---|---|---|
| D1 | Item 2: index-only layout (zero file moves in docs/epistemic/) | ~39 frozen-file references would break; index improvements satisfy R2-1 with zero link damage |
| D2 | Item 2: boards/ are LIVE — secondary narrative summaries | They serve a distinct purpose (per-goban entry points) and are referenced by 102 CLAIMS.md rows |
| D3 | Item 2: CLAIMS.md not split in pass 0 | Would touch claimlint source; defer to pass 1 full sweep |
| D4 | Item 3: channel stays under untracked/msg/ | Git-ignored directory inside docs/ inverts the evidence-store invariant |
| D5 | Item 3: addressee split rejected | Numbered sequence + filename encoding has proven value |
| D6 | Item 3: pruning rule lives in new docs/infra/channel.md | sprint.md doesn't discuss channels; a dedicated doc is cleaner |

---

## 1. Item 2 — epistemic tree target-state layout

### 1.1 Design constraints

The spec's retrieval criterion (R2-1): hop count from "I have claim ID X" to
"the evidence that backs it." The current path is:

```
claim ID → CLAIMS.md evidence column → docs/evidence/<id>/
```

That is already 2 hops. The problem is not hop *count* but hop *quality*:
CLAIMS.md is 179 KB and flat; INDEX-claim-evidence.md was generated once and
may be stale; INDEX-claim-task.md maps claims to tasks but not claim→ancestor
→descendant relationships. An agent who wants "what backs claim X and what else
falls if X is false" must read CLAIMS.md's graph section manually.

### 1.2 Why reorganization is rejected for pass 0

A `docs/epistemic/` reorganization into functional subdirectories (register/,
narrative/, glossary/, critiques/, concepts/) would:

- Move 12 files
- Update ~367 references to `docs/epistemic/` across 138 files
- Break ~39 references inside frozen provenance files (docs/evidence/README.md:
  10 refs; docs/audits/: 29 refs across 9 files) — per R2-2 these CANNOT be
  fixed
- Require claimlint constant updates (DEFAULT_CLAIMS, NARRATIVE_FILE) +
  calibration re-run (R2-3)
- Break an unknown number of untracked/ references (out of git, cannot sweep)

The frozen-file breakage alone — 39 documented-but-unfixed broken links — is
worse than the current flat layout. A reorganization that makes the tree less
navigable for provenance readers is a regression.

**Verdict: reorganization deferred to pass 1**, when the full reference sweep
under task freeze makes it tractable. Pass 1 moves docs/evidence/ and sweeps
all references; the docs/epistemic/ reorganization can be a second commit in
the same freeze window.

### 1.3 What pass 0 DOES: index-only improvement

Three index products, zero file moves:

| product | path | description |
|---|---|---|
| **Claim→evidence index** (regenerated) | `docs/INDEX-claim-evidence.md` | Every claim ID → status → evidence paths. Regenerated from current CLAIMS.md by claimlint. Replaces the 2026-07-29 snapshot with a current one. |
| **Claim→task index** (regenerated) | `docs/INDEX-claim-task.md` | Every claim ID → tasks that close/bear on/produced it. Regenerated from dispatch briefs + kanban. |
| **Dependency-tree index** (new) | `docs/INDEX-claim-deps.md` | Claim→ancestor→descendant relationships extracted from CLAIMS.md's `d:` and `n:` edges. Answers "what else falls if X is false" in one hop. |

Together these reduce the effective hop count from claim ID → evidence to 1 hop
(claim ID → INDEX-claim-evidence → evidence path on same page), and from claim
ID → impact analysis to 1 hop (claim ID → INDEX-claim-deps → ancestor/descendant
list on same page).

INDEX.md already routes to INDEX-claim-evidence.md and INDEX-claim-task.md. The
new INDEX-claim-deps.md is added to INDEX.md's routing.

### 1.4 Target-state directory layout (for pass 1 execution)

This is the layout pass 1 will build. It is stated here so no open design
questions survive pass 0. Pass 0 does NOT execute these moves.

```
docs/epistemic/
├── register/             ← CLAIMS.md
│   └── CLAIMS.md
├── narrative/            ← "what we know, what we need"
│   ├── PROGRESS.md
│   └── roadmap-2026-07-28.md
├── glossary/             ← terms and names
│   ├── GLOSSARY.md
│   └── names.md
├── critiques/            ← dated critiques and adjudications
│   ├── critique-2026-07-28.md
│   └── qa023-c2-adjudication-2026-07-29.md
├── concepts/             ← concept documents (not dated, not critiques)
│   ├── innovations.md
│   ├── is-real-game-markovian.md
│   └── knowledge-ladder.md
├── boards/               ← per-goban EPISTEMIC.md (live, secondary)
│   ├── CONCEPTS.md
│   ├── 2x2/EPISTEMIC.md
│   ├── 3x2/EPISTEMIC.md
│   ├── 3x3/EPISTEMIC.md
│   ├── 4x3/EPISTEMIC.md
│   └── 4x4/EPISTEMIC.md
├── indices/              ← generated cross-reference indices
│   ├── INDEX-claim-evidence.md   (moved from docs/)
│   ├── INDEX-claim-task.md       (moved from docs/)
│   └── INDEX-claim-deps.md       (moved from docs/)
└── claimlint-2026-07-28.md  ← tool output, stays at root (not epistemic content)
```

**Claimlint constant updates required (pass 1):**

| constant | old value | new value |
|---|---|---|
| `DEFAULT_CLAIMS` (:105) | `docs/epistemic/CLAIMS.md` | `docs/epistemic/register/CLAIMS.md` |
| `NARRATIVE_FILE` (:139) | `docs/epistemic/PROGRESS.md` | `docs/epistemic/narrative/PROGRESS.md` |
| `LOSS_INVENTORY` (:125) | `docs/evidence/README.md` | *TBD — depends on pass 1 evidence/ relocation* |

**Slot reservations for future files:**

| future file | target slot |
|---|---|
| `docs/epic-01-markovian/spec.md` | outside epistemic tree; epic root |
| `docs/epic-01-markovian/decisions/` | outside epistemic tree; epic root |
| `docs/evidence/ORACLE-V2/` | under evidence/ (pass 1 decides evidence/ location) |
| Future evidence directories | under evidence/ |

The indices (`docs/INDEX-claim-*.md`) move into `docs/epistemic/indices/` in
pass 1 so the claim→evidence lookup chain is fully within the epistemic tree.
INDEX.md routing is updated accordingly.

### 1.5 Boards verdict (R2-5)

**Verdict: LIVE — secondary narrative summaries.**

The six per-goban `EPISTEMIC.md` files serve a purpose CLAIMS.md does not: a
narrative summary of what is known about a single goban size, readable by an
agent arriving cold. CLAIMS.md is the authoritative register and is referenced
as such in INDEX.md ("every claim's status → CLAIMS.md; per-goban EPISTEMIC
files may lag").

Evidence they are live:
- `4x4/EPISTEMIC.md` was rewritten 2026-07-26 (GLM-5.2, task T16) to address
  audit findings — not a stale relic
- `CONCEPTS.md` is a cross-size concept-inventory that `CLAIMS.md` does not
  replicate
- 102 rows in CLAIMS.md reference boards/ paths in their evidence columns
- INDEX.md currently routes to them

They are secondary: CLAIMS.md is authoritative. Any conflict between a board
EPISTEMIC.md and CLAIMS.md is resolved in favor of CLAIMS.md. This hierarchy
is already stated in INDEX.md and does not change.

**Action in build.md:** No changes to boards/. The INDEX.md routing is already
correct.

### 1.6 CLAIMS.md split evaluation (R2-1-CLAIMS-SPLIT)

**Evaluated, deferred to pass 1.**

Splitting CLAIMS.md (179 KB) into a multi-file register (one per scope:
GLOBAL.md, 2x2.md, 3x2.md, etc.) with a generated index would:
- Reduce single-file size and merge contention
- Require claimlint parser changes (it reads one file today)
- Require INDEX.md and all cross-reference updates
- Be a meaningful code change, not a restructuring sweep

The cost exceeds the pass 0 ceiling. It is a candidate for pass 1 alongside
the evidence relocation, or for a dedicated epistemic sprint.

### 1.7 Evidence INDEX auto-generation (R2-1-EVIDENCE-INDEX)

Included in build.md as a "could have." A script scans `docs/evidence/` and
generates `docs/evidence/INDEX.md` — one line per claim ID → its evidence
files. This improves the "what backs claim X" path without moving any files.

Script: `tools/gen-evidence-index` (new, committed in build.md). Output:
`docs/evidence/INDEX.md`. INDEX.md routing updated to point to it.

---

## 2. Item 3 — channel target-state layout

### 2.1 The pruning rule (R3-3)

The rule is written and committed in this sprint. It lives in a new file
`docs/infra/channel.md`, cited from `docs/infra/sprint.md`.

**Rule text** (the deliverable):

> When pass N of sprint S closes and its `accept.md` is ratified, the sprint's
> channel directory may be archived or deleted, because the canonical record is
> the phase documents in git. The channel is a working-space convenience, not a
> durable record. Pruning is opt-in per pass: the sprint's `accept.md` states
> whether the channel was archived or retained, and why. A retained channel
> carries a README stating its retention reason and the date its pass closed.
>
> The epic-level channel (`untracked/msg/<epic>/`) is pruned only when the epic
> closes, by human decision, because it holds cross-sprint DECISIONS.md and
> STATE.md that no single sprint owns.

This rule applies to future sprints. It explicitly does NOT authorize deletion
of `untracked/msg/milestone-01-ko-reframe/` — that is a human decision
post-epic (scope §"Won't have").

### 2.2 Channel location: argument against `docs/**/channel/` (R3-1)

068 proposed `docs/epic-01-markovian/sprints/<sprint>/channel/` — a
git-ignored directory inside the `docs/` tree.

**Rejected.** The invariant that saved the evidence store is: *if it is under
`docs/`, it is in git and retrievable.* `docs/evidence/README.md` exists
because `untracked/` was swept and the primary evidence for load-bearing claims
was destroyed (T13). A git-ignored directory inside `docs/` inverts this
invariant: a path that reads canonical (`docs/epic-01-markovian/sprints/
< sprint>/channel/`) but is not in git is the exact failure mode that
destroyed T13's evidence. An agent finding it would reasonably assume it is
versioned; it would not be.

The channel stays wholly under `untracked/msg/`. The subdivision (below)
achieves the organizational goal without violating the invariant. Pass 1 will
not reconsider this — the decision is final per scope.

### 2.3 Subdivision per sprint (R3-1-SUBDIVIDE)

**New sprints** use the template:

```
untracked/msg/epic-01-markovian/
├── <sprint>/
│   ├── STATE.md
│   ├── DECISIONS.md
│   └── NNN-<from>-to-<to>.md
```

The current channel (`untracked/msg/milestone-01-ko-reframe/`, 93 files) is
**not renamed, not moved, not archived, not deleted**. It stays as a frozen
historical record. Its directory name is a historical artifact and is
documented as an alias in `docs/infra/channel.md`.

**INDEX.md update:** The "crash-recovery anchor" routing changes from
`untracked/msg/<milestone>/STATE.md` to point at the new template location.
The old path is listed as "historical — milestone-01-ko-reframe only."

**sprint.md update:** §"Passes, revisions, and directories" gains a pointer to
`docs/infra/channel.md` for channel layout.

### 2.4 Addressee split: considered and rejected (R3-4)

068 proposed splitting agent-to-agent messages from broadcast messages into
separate directories (e.g., `to-agent/` and `broadcast/`).

**Rejected.** The filename convention already encodes addressees
(`068-dabir-to-orchestrator.md`, `069-consul-to-all.md`). A numbered sequence
readable by every seat has value that per-pair directories would break: an
agent catching up reads the sequence chronologically regardless of addressee.
Directory splitting would force agents to check multiple directories to
reconstruct the chronological record. The current convention is serving its
purpose; no change.

### 2.5 Template for future sprints (R3-COPY-TEMPLATE)

Copy the structure of STATE.md and DECISIONS.md from
`untracked/msg/milestone-01-ko-reframe/` into a template directory:

```
docs/infra/channel-template/
├── STATE.md
└── DECISIONS.md
```

The template files have placeholders (`<EPIC>`, `<SPRINT>`, `<DATE>`) instead
of live content. `docs/infra/channel.md` references the template. When a new
sprint initializes its channel, it copies the template into
`untracked/msg/<epic>/<sprint>/`.

The originals in `milestone-01-ko-reframe/` are not touched.

---

## 3. Item 1 — verification checklist

Navigator pre-empted the directory hierarchy. This sprint verifies and handles
residue. The design states what is checked, not how (build.md executes).

### V1 — Verification

| check | how |
|---|---|
| V1-SPRINTS | `ls docs/epic-01-markovian/sprints/` — confirm all seven sprints present |
| V1-NO-INFRA | Confirm `docs/infra/<sprint>/` and `docs/design/<sprint>/` absent |
| V1-PLAN | `grep -r "strategy.md" --include="*.md"` — zero live references |
| V1-FOLLOW | `git log --follow` sample of 5 files |
| V1-SPRINTMD | Diff sprint.md rev 5 against rev 4: additions only |
| R1-5-PASSN | Confirm no pass0/ copies of revision documents |
| R1-4-SELF | Verify spec.md header path matches actual location |

### V2 — Residue

| item | action |
|---|---|
| R1-1 (epic name) | Settle: the canonical name is `epic-01-markovian`. The word is "epic" (not "milestone"). The channel directory keeps its historical name (frozen). New documents use the canonical name. |
| R1-3 (epic spec.md) | Evaluate whether a useful epic spec.md can be written this pass. Sources: `docs/INTENT.md`, `docs/epistemic/PROGRESS.md`, `docs/epistemic/roadmap-2026-07-28.md`. If not achievable, defer to pass 1 with a written rationale. |
| R1-2 (sprint.md rev 5) | Flag ratification gap. If still PROPOSED at accept.md time, record as open dependency. |

---

## 4. R2-4 Backlog design

The orphan/re-verification backlog is a committed document at:

```
docs/epic-01-markovian/sprints/project-restructure/pass0/backlog.md
```

It takes the claimlint baseline (committed in test.md) and disposition every
row:

| category | count | disposition |
|---|---|---|
| C1a orphans (10) | 10 | Each row: owner, disposition, one-line rationale |
| C2 dangling evidence (12) | 12 | Each MISSING path: owner, whether recoverable, backlog task ID |
| C3 PROVEN w/o evidence (79) | — | Aggregate by dependency count (CLAIMS.md §4.2 already tiers them); top-20 dispositioned individually, remainder batched |
| C4 dangling IDs (32) | 32 | Sampled: 10 most-cited IDs dispositioned; remainder batched |
| C5 shadowed (4) | 4 | Each dispositioned individually |
| A repeated-narrowing (5) | 5 | Each dispositioned individually |

Each row gets: **owner** (human / Dabir / Orchestrator / Auditor / task ID),
**disposition** (*fix now / backlog with task ID / demote status / accept with
reason*), and a **one-line rationale**.

This satisfies R2-4 and the re-verification half of A6. The substance behind
these rows is not fixed in this sprint — only dispositioned.

---

## 5. Build sequence

The design commits to this execution order in build.md:

1. **Baseline** — run claimlint, capture output in test.md
2. **Freeze list** — enumerate frozen provenance files (docs/evidence/**,
   docs/audits/**)
3. **Boards verdict** — confirm live, no changes (document in build.md)
4. **Regenerate indices** — INDEX-claim-evidence.md, INDEX-claim-task.md
5. **New dependency-tree index** — INDEX-claim-deps.md (generated from
   CLAIMS.md edges)
6. **Backlog** — write backlog.md from baseline
7. **Channel** — write docs/infra/channel.md (pruning rule + argument),
   update sprint.md + INDEX.md pointers
8. **Template** — copy STATE.md + DECISIONS.md to
   docs/infra/channel-template/
9. **Item 1 verification** — execute checklist, record results
10. **Epic spec.md evaluation** — write or defer with rationale
11. **Post-build claimlint** — re-run, compare to baseline
12. **Link check** — run link checker, report pre-existing vs new breaks,
    exempt frozen files
13. **Evidence INDEX** — generate docs/evidence/INDEX.md (if script written)

---

## 6. Acceptance commitments

This design commits to satisfying these gates from scope.md:

| gate | how this design satisfies it |
|---|---|
| A1-verdict | Every item gets explicit verdict in accept.md |
| A2-no-regression | Baseline in test.md; post-build claimlint ≤ baseline on C1a, C2; calibration PASS |
| A3-links | Zero moves in docs/epistemic/ → zero new broken links. Frozen files listed. Pre-existing dangling references (C2) reported, not inherited silently |
| A4-process-coherence | sprint.md + INDEX.md describe the tree that exists at acceptance commit |
| A5-history | Zero file moves in pass 0 → git log --follow trivially satisfied |
| A6-backlog | backlog.md committed, every row dispositioned |
| A7-no-adjudication | Zero claim status changes, zero number changes, zero ADR conclusion changes |
| A8-build | zig build succeeds; claimlint calibration battery passes |

---

## 7. Design audit gate

Per plan.md §1: this design must be audited by a fresh seat (document review,
not adversarial). The audit verifies:

1. The target-state layout is complete (no open design questions for pass 1)
2. The index-only decision for pass 0 is justified against the frozen-file
   constraint (R2-2)
3. The boards verdict is supported by evidence of liveness
4. The channel argument (R3-1) properly invokes the evidence-store invariant
5. The pruning rule text is clear, actionable, and opt-in
6. The build sequence covers all must-have items

**Auditor:** DSPro/T201 (fresh seat, dispatched via subdelegation). Findings
written to `untracked/T201-design-audit.md`.

---

**Next phase:** `test.md` — claimlint baseline, frozen-file list, link-check
script. Depends on design ratification (audit PASS).
