# project-restructure — SPEC

```
Revision: 1
Status:   PROPOSED
Author:   Opus/Orcha (claude-opus-5[1m]) · 2026-07-31
Source:   untracked/msg/milestone-01-ko-reframe/068-dabir-to-orchestrator.md
Process:  docs/infra/sprint.md @ 45deb10 (Revision 4, RATIFIED G-human
          2026-07-31 c8d666a)
External approval beyond the human: NOT required. Dabir wrote the request
          (068) and is therefore not an independent approver of the spec that
          restates it. One fresh-seat spec audit per the sprint.md Spec gate.
```

The human wants the project tree reorganized. Three items, one sprint. **"Do
nothing, change nothing" is an acceptable — and for at least one item likely —
outcome**, provided this spec or a later phase document says so and says why.

This document answers only "what do we want?" It does not choose layouts. Item
2 explicitly has no prescription: designing the layout is the design phase's
job, and ratification of that design is a separate gate.

---

## 0. Why this sprint exists, in one line

Three separate retrieval failures share one cause: the tree records *when*
things were written, not *what question they answer*. An agent arriving cold
cannot find the epic's goal (there is no epic document), cannot find what backs
a claim in one hop (`docs/epistemic/` is flat, `docs/evidence/` is keyed by
claim ID but reached only through a generated index), and cannot tell which of
88 channel messages belong to the sprint it was handed.

## 1. Item 1 — epic/sprint directory hierarchy

### What we want

A tree where epic-level documents and sprint-level documents are distinguishable
by path, and where a sprint's phase documents sit under the epic that owns them.
068 proposes:

```
docs/epic-01-markovian/
    spec.md              ← epic-level: rules, method, goal, expected result
    decisions/           ← epic-scoped ADRs
    sprints/
        oracle-v2/pass0/{spec,scope,design*,test,plan,build,accept}.md
        verify-battery/pass0/...
```

Existing sprint artifacts under `docs/infra/oracle-v2/`,
`docs/infra/verify-battery/`, `docs/design/oracle-v2/` and
`docs/design/verify-battery/` migrate into it.

### What the spec requires of whatever design is chosen

- **R1-1 — one name for the epic.** The channel calls it
  `milestone-01-ko-reframe`; 068 calls it `epic-01-markovian`; `docs/INDEX.md`
  references `untracked/msg/<milestone>/`. Two names for one thing is itself a
  retrieval defect. The design picks one name and one word ("epic" or
  "milestone", not both) and the sweep applies it everywhere, channel included.
- **R1-2 — sprint.md must be amended in the same pass, or the item is
  rejected.** `docs/infra/sprint.md @ 45deb10` §"Passes, revisions, and
  directories" fixes the canonical layout as `docs/infra/<sprint>/passN/` with
  ephemera in `docs/design/<sprint>/`. That document is RATIFIED. Item 1
  contradicts it. Either this sprint produces sprint.md rev 5 and takes it
  through its own ratification gate, or item 1 resolves to "change nothing."
  Migrating the tree while leaving the ratified process document describing the
  old tree is the one outcome this spec forbids.
- **R1-3 — the epic `spec.md` must be written, not just filed.** The hierarchy's
  value is the epic-level document at its root. There is no such document today:
  `docs/INTENT.md`, `docs/epistemic/PROGRESS.md` and
  `docs/epistemic/roadmap-2026-07-28.md` each carry part of it. If the epic
  spec.md would be an empty directory placeholder, the hierarchy buys nothing
  this pass. Either write it (from those three sources, and say in it which
  parts were absorbed) or descope item 1.
- **R1-4 — this sprint's own documents move too.** `docs/infra/project-restructure/`
  is the current ratified location, so this spec was written there. If item 1
  lands, this sprint's pass0 directory migrates with the others, and this
  spec's own header path reference is updated in the same commit.
- **R1-5 — `passN/` semantics are inherited unchanged.** A pass is an iteration
  of the deliverable; a revision never mints a directory (sprint.md
  @ 45deb10). The migration must not create `pass0/` copies of documents that
  are revisions — the disease that document names.

### Cost known at spec time

400 `docs/infra/...` path references and 66 `docs/design/...` references across
tracked markdown (measured at 45deb10). Most are commit-pinned line references
in audit and evidence documents.

## 2. Item 2 — epistemic tree reorganization

### What we want

Optimize `docs/epistemic/`, `docs/evidence/` and `docs/epistemic/boards/` so an
agent can find **what backs a claim in one hop**. Today: `docs/epistemic/` is 12
flat files mixing register (`CLAIMS.md`), narrative (`PROGRESS.md`), glossary,
roadmap, dated critiques and dated adjudications; `docs/evidence/` is 178 files
in ~28 claim-ID-keyed directories; `docs/epistemic/boards/` holds six per-goban
`EPISTEMIC.md` trees and is described in 068 as a relic (note: 068 says
`docs/boards/`, which does not exist — the relic is `docs/epistemic/boards/`).

068 also asks for three products alongside the layout:

- re-link every reference after reorganization,
- an **orphan-claim report** (claims without evidence),
- a **backlog of claims needing re-verification**.

### What the spec requires

- **R2-1 — retrieval is the acceptance criterion, relocation is not.** The
  measurable want is hop count from "I have claim ID X" to "I am reading the
  probe source and output that back it," and from "I have a question" to the one
  document that answers it. A design that improves hop count by adding or
  regenerating index layers, without moving `docs/evidence/` or
  `docs/epistemic/CLAIMS.md`, satisfies this item completely. Movement is a
  means, and an expensive one — see R2-3.
- **R2-2 — provenance text is not re-linkable.** Committed evidence and audit
  documents record what a path was when the observation was made. Rewriting
  paths inside `docs/evidence/**` and `docs/audits/**` to keep links green would
  falsify provenance records. The design states, explicitly, which files are
  rewritten and which are frozen-with-a-pointer. Freezing is the default for
  anything under `docs/evidence/`.
- **R2-3 — moving these trees is a code change.** `src/claimlint.zig` hardcodes
  `docs/epistemic/CLAIMS.md` (:105), `docs/evidence/README.md` (:125),
  `docs/epistemic/PROGRESS.md` (:139) and a `docs/decisions/` prefix test
  (:394). `.gitignore` carries `!docs/evidence/` and `!docs/evidence/**` with a
  standing comment that they **must stay last**. Any relocation of these trees
  updates the linter source, its calibration fixtures, and the ignore rules in
  the same commit, and re-runs the calibration battery. 591 `docs/evidence/...`
  and 299 `docs/epistemic/...` references exist in tracked files at 45deb10.
- **R2-4 — the orphan and re-verification products are due even if the layout
  does not change.** These are the parts of item 2 with unconditional value.
  `bin/weizigo-claimlint` already computes most of the inputs: at 45deb10 it
  reports 10 C1a orphans, 13 C2 dangling evidence paths, 73 PROVEN rows without
  committed evidence, 28 dangling claim IDs, 4 shadowed dependencies and 5
  repeated-narrowing smells. Wanted: those counters turned into a dispositioned
  list — per row, an owner and one of *fix now / backlog with a task ID /
  demote the status / accept with reason*. A count is not a backlog.
- **R2-5 — `boards/` gets a verdict, not a silent move.** Either the six
  per-goban `EPISTEMIC.md` trees are live (say who reads them and keep them) or
  they are superseded by `CLAIMS.md` (say so and retire them). "Relic" is a
  claim in 068 that this sprint tests rather than inherits.
- **R2-6 — no status may change to improve a counter.** `CLAIMS.md` states this
  rule about itself and it binds this sprint: reorganization must not promote,
  demote, or delete a claim row. Status changes are adjudications and belong to
  the human and the epistemic seat, not to a restructuring sweep.

## 3. Item 3 — channel organization and pruning

### What we want

The channel stays out of git. Within that, 068 asks to split sprint-specific
traffic from epic-level traffic, put sprint traffic at
`docs/epic-01-markovian/sprints/<sprint>/channel/` while keeping it untracked,
allow a completed pass's channel to be archived or deleted, and consider
splitting agent-to-agent messages from broadcast messages.

Today: one directory, `untracked/msg/milestone-01-ko-reframe/`, 88 files —
numbered messages plus three live control documents (`STATE.md`,
`DECISIONS.md`, `DABIR-INTENT.md`).

### What the spec requires

- **R3-1 — a git-ignored directory inside `docs/` must be argued for against
  the failure it resembles.** `docs/evidence/README.md` exists because
  `untracked/` was cleaned and the primary evidence for the project's most
  load-bearing claims was destroyed. The invariant that bought back — *if it is
  under `docs/`, it is in git and retrievable* — is what `docs/**/channel/`
  inverts: a path that reads canonical and is not. This spec does not forbid it,
  but it wants the alternative (channel stays wholly under `untracked/msg/`,
  subdivided per sprint there) considered and the choice justified in
  `design.md`. If the argument does not hold, item 3's relocation is "change
  nothing" and only the split and pruning rule land.
- **R3-2 — the three control documents are load-bearing and must not move
  silently.** `sprint.md @ 45deb10` points twice at "the active milestone
  channel's `STATE.md`" (seats and role definitions; standing epistemic rules
  3–6), and `docs/INDEX.md` points at `untracked/msg/<milestone>/STATE.md` as
  the crash-recovery anchor. Any move updates both pointers in the same commit.
- **R3-3 — the pruning rule is written down and is opt-in per pass.** Wanted: a
  stated rule of the form "when pass N of sprint S closes, its channel may be
  archived or deleted, because the canonical record is the phase documents." The
  rule is what this sprint delivers. **Executing it against
  `milestone-01-ko-reframe` is out of scope for pass 0** — deletion of a live
  channel is not a restructuring side effect. Nothing is deleted in this pass.
- **R3-4 — the addressee split is optional and may be answered "no."** 068 says
  "consider." The filename convention already encodes addressees
  (`068-dabir-to-orchestrator.md`, `069-consul-to-all.md`) and a numbered
  sequence readable by every seat has value that per-pair directories would
  break. A one-paragraph "considered, rejected, here is why" satisfies this.

## 4. Acceptance criteria

Every criterion is satisfiable by "change nothing, and here is why" unless it
says otherwise.

- **A1-verdict** — each of the three items carries an explicit verdict in
  `accept.md`: *changed* (what moved), *changed in part* (what and what not), or
  *unchanged* (why). No item is silently dropped.
- **A2-no-regression** — `bin/weizigo-claimlint` is **no worse than the baseline
  pinned in this sprint's `test.md`**. It is not green today: exit 1 at 45deb10,
  with 10 C1a orphans, 13 C2 dangling paths and 0 C6 mismatches as the failing
  categories. 068's "claimlint green" is unachievable as literally written and
  is read here as *no new findings introduced by this sprint, and every
  pre-existing finding either fixed or dispositioned per R2-4*. The baseline run
  is committed under `docs/evidence/` before the first file moves, and its
  calibration section must still read `calibration: PASS` after.
- **A3-links** — no tracked markdown link or path reference is left dangling by
  a move this sprint performed. Enforced by a checker run before and after, not
  by inspection. Pre-existing dangling references are reported, not silently
  inherited; files frozen under R2-2 are listed with their rationale and are not
  counted as failures.
- **A4-process-coherence** — if the tree changes, `docs/infra/sprint.md` and
  `docs/INDEX.md` describe the tree that exists. Every path either document
  names resolves at the acceptance commit.
- **A5-history** — every move uses `git mv`, one logical move per commit group,
  so `git log --follow` survives. No file is deleted and re-added.
- **A6-backlog** — the orphan-claim report and the re-verification backlog exist
  as committed documents, every row dispositioned with an owner (R2-4). Due
  regardless of the layout verdicts.
- **A7-no-adjudication** — the diff changes zero claim statuses, zero numbers,
  and zero ADR conclusions. A reviewer can confirm this from the diff alone
  (R2-6).
- **A8-build** — `zig build` succeeds and the claimlint calibration battery
  passes after any source change made under R2-3.

## 5. Out of scope for pass 0

Named here so the boundary is a decision and not an oversight:

- Deleting or archiving the live `milestone-01-ko-reframe` channel (R3-3).
- Changing any claim's status, or fixing the substance behind the 10 C1a
  orphans and 73 uncommitted-evidence rows. This sprint *reports and backlogs*
  them (A6); repairing them is separate work.
- Rewriting `docs/epistemic/PROGRESS.md`, `CLAIMS.md` or `docs/INTENT.md`
  content. Their paths may change; their prose does not, except for the epic
  spec.md absorption explicitly permitted by R1-3.
- Renaming or reorganizing `src/`, `bin/`, `data/`, `artifacts/`.
- `docs/audits/`, `docs/research/`, `docs/status/` layout. If the item 2 design
  finds one of them belongs in the epistemic tree, that is a finding for
  `scope.md`, deferrable to pass 1.

## 6. Known risks

1. **Three items, one pass, and item 2 is the expensive one.** Items 1 and 3 are
   mechanical once named. Item 2 touches 890 references, a compiled linter and
   the git-ignore invariant that protects the evidence store. `strategy.md`
   should expect to sequence item 2 last, or scope it to indices-only and defer
   relocation to pass 1.
2. **A restructuring sweep is the ideal cover for a silent semantic edit.** A7
   exists because a 900-file path rewrite is unreviewable line by line;
   mechanical rewrites must be scripted and the script committed, so the
   reviewer audits the script rather than the diff.
3. **Ratified-document contradiction (R1-2).** Landing the tree before sprint.md
   rev 5 is ratified would leave the process document false for the window
   between — and this sprint's own phase documents would be in a location no
   ratified document sanctions.
4. **Migration hides the absence of content.** An epic directory whose `spec.md`
   is a stub, or a per-sprint channel directory that is empty because nobody
   routes messages there, both read as progress while changing nothing (R1-3).

---

**Next phase:** `strategy.md` — per sprint.md, the builder restates this spec in
its own words, declares which phases this pass needs, which get fresh audit and
with what instrument, and what may run in parallel. Spec ratification comes
first; the Spec gate is document review by a fresh seat against the human intent
recorded in 068.
