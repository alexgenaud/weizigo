# project-restructure pass0 — SCOPE

```
Task: T197 · Role: worker · Model: DSPro · Date: 2026-08-01
Revision: 2
Status:   PROPOSED
Source:   plan.md rev 2 · spec.md rev 1 · Navigator msg 070 §3
         Human direction 2026-08-01: design for target-state layout including
         files that don't exist yet; pass 1 as dedicated relocation sprint
         under task freeze with reference audit as side value.
```

MoSCoW for all three items including item 1 residue. Every "won't" names the
pass or owner it defers to.

---

## Two-pass strategy

### Pass 0 (this pass) — design the target state, execute safe moves

Pass 0 **designs the full target-state layout** — including slots for files
that will exist but do not yet exist at scoping time (epic `spec.md`, epic
`decisions/`, WZO2 evidence, future sprint channels, etc.). It then executes
the subset of that design achievable without touching the high-risk boundary:

- **`docs/epistemic/` reorganization** — 269 references, claimlint constants
  (`DEFAULT_CLAIMS`, `NARRATIVE_FILE`) unchanged, no `.gitignore` change.
  If even this proves too expensive during design, fall back to index-only.
- **No `docs/evidence/` relocation in pass 0.** That touches 593 refs +
  claimlint source + `.gitignore` invariant. It belongs in pass 1.
- **No channel deletion or archival.** `untracked/msg/milestone-01-ko-reframe/`
  (92 files) stays as-is. The pruning rule is written; execution is out of
  scope (spec R3-3).

### Pass 1 (next sprint) — relocation under task freeze

Pass 1 is the dedicated relocation sprint. It runs as the **only sprint
executing** — no concurrent writers to `docs/`, `src/claimlint.zig`, or
`.gitignore`. Under that freeze:

- **Relocate `docs/evidence/`** to its target-state location.
- **Update `src/claimlint.zig`** constants and re-run calibration.
- **Update `.gitignore`** evidence-store rules.
- **Sweep all tracked references** (593 `docs/evidence/`, 269
  `docs/epistemic/`, plus any new paths introduced by the target-state
  layout). Every reference is resolved or flagged.
- **The reference sweep is itself an audit.** Broken links, stale paths,
  orphan citations — every one surfaces during the sweep. This is value
  beyond the restructure: a systematic link-rot audit of the entire doc
  tree. Findings feed back into the backlog (R2-4).

Pass 1's scope is stated here so pass 0's design makes commitments pass 1
can execute. The design.md must define the target-state layout completely
enough that pass 1's builder needs only to execute it — no open design
questions survive pass 0.

---

## Item 1 — epic/sprint directory hierarchy (verification + residue)

Navigator's tree move (d51a068 + 41000c6) pre-empted the directory hierarchy
work. Item 1 is now verification + residue only. No new tree moves.

### Must have

| ID | what | how verified |
|---|---|---|
| V1-SPRINTS | All seven sprints live at `docs/epic-01-markovian/sprints/<sprint>/` | `ls` + document in build.md |
| V1-NO-INFRA | `docs/infra/<sprint>/` and `docs/design/<sprint>/` are gone | `ls` + document in build.md |
| V1-PLAN | `strategy.md` → `plan.md` rename complete across tracked files | `grep strategy.md` returns zero live references |
| V1-FOLLOW | `git log --follow` works for every moved file | Sample 5 files spanning sprints; document in build.md |
| V1-SPRINTMD | sprint.md substance intact (phases, gates, halt conditions, bookends) | Diff against rev 4: additions only, no removals. Document in build.md |
| R1-1-NAME | **One name.** The epic is `epic-01-markovian`, the word is "epic" (not "milestone"). The channel directory may keep its historical name since it is frozen (item 3 won't), but new documents use the canonical name. Rationale recorded in design.md | `grep milestone-01` in tracked files: only historical citations remain; no live routing uses the old name |
| R1-5-PASSN | `passN/` semantics intact: no `pass0/` copies of revision documents | Verify canonical docs are unsuffixed, revisions are in-place with `Revision: N` header |
| R1-4-SELF | This sprint's own path references consistent | spec.md header path matches actual location |

### Should have

| ID | what | how verified |
|---|---|---|
| R1-3-EPICSPEC | Epic-level `spec.md` written at `docs/epic-01-markovian/spec.md`. Absorbs content from `docs/INTENT.md`, `docs/epistemic/PROGRESS.md`, `docs/epistemic/roadmap-2026-07-28.md`. States which parts were absorbed | Document exists, has absorption notes, is not a stub |

### Could have

| ID | what | how verified |
|---|---|---|
| R1-1-CHANNEL | Rename `untracked/msg/milestone-01-ko-reframe/` → `untracked/msg/epic-01-markovian/`. Only if the pruning rule (item 3) lands first and doing this in the same pass simplifies routing. Risk: 92 files, all in untracked/ (not git), so `mv` not `git mv` | Directory renamed, INDEX.md updated |

### Won't have (deferred)

| ID | what | deferral |
|---|---|---|
| — | Any new tree moves | Pre-empted by Navigator. Nothing to defer. |
| R1-1-CHANNEL-FORCE | Forcing the channel rename if it complicates item 3 | pass 1 — the historical directory name is frozen with the channel |

---

## Item 2 — epistemic tree reorganization

### Must have

| ID | what | how verified |
|---|---|---|
| R2-4-BACKLOG | **Dispositioned orphan/re-verification list.** Every row from the claimlint baseline (10 C1a, 12 C2, 79 C3, 30 C4, 4 C5, 5 repeated-narrowing) gets: owner, disposition (*fix now / backlog with task ID / demote status / accept with reason*), one-line rationale. Committed under this sprint's pass0 | Document exists; every row dispositioned; no row skipped |
| R2-5-BOARDS | **Verdict on per-goban EPISTEMIC.md trees.** Determine if `docs/epistemic/boards/` (6 directories) is live or dead. If dead: add superseded banner, update INDEX.md. If live: document who reads them | Verdict in design.md; executed in build.md; INDEX.md consistent |
| R2-6-NO-ADJUDICATION | **Zero claim status changes.** No promotion, demotion, or deletion | `diff CLAIMS.md` shows zero status-column changes |
| R2-2-FROZEN | **Provenance text frozen.** Files under `docs/evidence/` and `docs/audits/` are not rewritten. Any link break inside them is documented, not silently fixed | Frozen-file list in test.md; post-build link checker reports them as exempt |

### Should have

| ID | what | how verified |
|---|---|---|
| R2-1-INDEX | **Improved retrieval via indices.** Regenerate `docs/INDEX-claim-evidence.md` and `docs/INDEX-claim-task.md`. Add a dependency-tree index showing claim→ancestor→descendant relationships. Zero file moves required | Indices exist, are current, reduce hop count from "I have claim ID X" to evidence |
| R2-1-REORG | **Reorganize `docs/epistemic/` into functional subdirectories.** Group by function: register (`CLAIMS.md`), narrative (`PROGRESS.md`), glossary (`GLOSSARY.md`, `names.md`), dated-critiques (`critique-2026-07-28.md`, `qa023-c2-adjudication-2026-07-29.md`), concept-docs (`innovations.md`, `is-real-game-markovian.md`, `knowledge-ladder.md`). Claimlint constants (`DEFAULT_CLAIMS`, `NARRATIVE_FILE`) do NOT change — files move but the constants point to their new paths | Moves are `git mv`; claimlint calibration still PASS; link checker clean (excluding frozen files) |
| R2-3-CLAIMLINT | If paths move: update `src/claimlint.zig` constants, re-run calibration battery | Calibration PASS; `zig build` succeeds |

### Could have

| ID | what | how verified |
|---|---|---|
| R2-1-CLAIMS-SPLIT | Split `CLAIMS.md` into a multi-file register (one per scope) with a generated index. Reduces file size (179 KB) and merge contention | Design.md evaluates cost; if chosen, build.md executes |
| R2-1-EVIDENCE-INDEX | Auto-generate `docs/evidence/INDEX.md` from the directory tree, one line per claim ID → its evidence files | Script exists; index is current; claimlint can verify it |

### Won't have (deferred to pass 1)

| ID | what | deferral |
|---|---|---|
| — | **Relocate `docs/evidence/`** under `docs/epistemic/` or anywhere else | **pass 1** — the dedicated relocation sprint under task freeze. Design.md defines the target location; pass 1 executes the move, updates claimlint + .gitignore, and sweeps 593 references |
| — | **Rewrite CLAIMS.md prose.** Content changes are adjudications, not restructuring | Separate epistemic sprint or human adjudication |
| — | **Fix the substance behind C1a orphans or C3 uncommitted-evidence rows.** This sprint dispositions them; repair is separate work | To be registered as tasks in the kanban, referenced from the backlog |
| — | **Reorganize `docs/audits/`, `docs/research/`, `docs/status/`.** These are not in the epistemic tree proper (spec §5) | **pass 1** — design.md may find they belong in the target-state layout; if so, their relocation executes under the same freeze as `docs/evidence/` |

---

## Item 3 — channel organization and pruning

### Must have

| ID | what | how verified |
|---|---|---|
| R3-3-RULE | **The pruning rule, written and committed.** Form: "When pass N of sprint S closes and its `accept.md` is ratified, the sprint's channel directory may be archived or deleted, because the canonical record is the phase documents in git." The rule lives in `docs/infra/sprint.md` or a new `docs/infra/channel.md` cited from sprint.md | Rule exists; sprint.md or channel.md updated |
| R3-4-ADDRESSEE | **Addressee split: considered and rejected.** One paragraph in design.md. Rationale: the filename convention already encodes addressees (`068-dabir-to-orchestrator.md`); a numbered sequence readable by every seat has value that per-pair directories would break | Paragraph exists in design.md |
| R3-1-ARGUE | **Argument against `docs/**/channel/` git-ignored directory.** Design.md justifies keeping the channel under `untracked/msg/` rather than under `docs/`. The invariant that saved the evidence store — *if it is under `docs/`, it is in git* — is what a git-ignored channel directory inverts. A path that reads canonical and is not is the exact failure mode that destroyed T13's evidence | Argument in design.md; decision recorded |

### Should have

| ID | what | how verified |
|---|---|---|
| R3-1-SUBDIVIDE | **Subdivide `untracked/msg/` per sprint.** Template: `untracked/msg/epic-01-markovian/<sprint>/`. The current channel (`milestone-01-ko-reframe/`) stays in place as a frozen historical record; new sprints use the subdivided layout. `docs/INDEX.md` and `docs/infra/sprint.md` updated to point at the new layout | Template directory structure documented; INDEX.md + sprint.md pointers updated |
| R3-2-POINTERS | **Update STATE.md/DECISIONS.md pointers.** If the subdivision changes where `STATE.md` lives for future sprints, `docs/infra/sprint.md` and `docs/INDEX.md` reflect the new convention in the same commit | Pointers resolve at acceptance commit |

### Could have

| ID | what | how verified |
|---|---|---|
| R3-COPY-TEMPLATE | Copy `STATE.md` and `DECISIONS.md` structure to a template for future sprints, leaving the originals in place | Template exists; sprint.md references it |

### Won't have (deferred)

| ID | what | deferral |
|---|---|---|
| — | **Delete or archive `milestone-01-ko-reframe/`.** 92 files, live channel, out of scope (spec R3-3) | **Human decision, post-epic.** When the epic closes, the human decides whether to archive or delete |
| — | **Move channel under `docs/`.** Argued against in design.md (R3-1); relocation rejected on principle | **Never.** The invariant is load-bearing. Pass 1 will not reconsider |
| — | **Split addressee directories.** Considered and rejected (R3-4) | **Never.** Numbered sequence has proven value |

---

## Cross-item dependencies

| dependency | from | to | constraint |
|---|---|---|---|
| Epic name (R1-1) | item 1 | item 3 | If item 1 chooses to rename the channel directory, item 3's "won't delete" rule still applies — it's a rename, not a deletion. But per scope, channel rename is "could" at most |
| sprint.md rev 5 (R1-2) | item 1 | whole sprint | Ratification is external (human). If still PROPOSED at accept.md time, A4 is partially unsatisfied — recorded as an open dependency |
| Boards verdict (R2-5) | item 2 | INDEX.md | INDEX.md currently routes to per-goban EPISTEMIC.md. If boards are dead, INDEX.md must be updated |
| Pruning rule location (R3-3) | item 3 | sprint.md | If the rule lands in sprint.md, it must survive sprint.md rev 5 ratification |

---

## What is explicitly NOT in scope for pass 0

Repeating spec §5 with decisions from above. Items marked "pass 1" are
explicitly deferred to the dedicated relocation sprint (see §Two-pass
strategy above):

- Relocating `docs/evidence/` — **pass 1** (under task freeze)
- Deleting or archiving the live channel — **human decision, post-epic**
- Moving channel under `docs/` — **rejected on principle** (R3-1; pass 1 will not reconsider)
- Changing any claim's status — **adjudication, not restructuring** (R2-6)
- Fixing the substance behind orphans/uncommitted-evidence — **separate tasks**
- Rewriting CLAIMS.md, PROGRESS.md, or INTENT.md content — **adjudication** (epic spec.md absorption per R1-3 is the exception)
- Renaming or reorganizing `src/`, `bin/`, `data/`, `artifacts/` — **out of sprint scope**
- Reorganizing `docs/audits/`, `docs/research/`, `docs/status/` — **pass 1** if the target-state design pulls them in

---

## Acceptance gates for this scope

These are the gates scope.md commits to — the full list is in plan.md §4. This
scope guarantees:

| gate | scope commitment |
|---|---|
| A1-verdict | Every item gets explicit verdict in accept.md: Must-done / Should-done / Could-done / Won't-with-reason |
| A2-no-regression | claimlint baseline committed in test.md; post-build ≤ C1a, ≤ C2, calibration PASS |
| A3-links | No move breaks a live link; frozen files listed with rationale |
| A4-process-coherence | sprint.md + INDEX.md describe the tree that exists |
| A5-history | Every move is `git mv`; `git log --follow` verified |
| A6-backlog | Orphan/re-verification document committed, every row dispositioned |
| A7-no-adjudication | Zero claim status changes, zero number changes, zero ADR conclusion changes |
| A8-build | `zig build` succeeds; claimlint calibration battery passes |

---

## Design guidance — target-state layout

The design.md must define a layout that works for the **target state**, not
just the current disk. Files that do not exist yet but are committed in
project plans:

| future file/directory | source |
|---|---|
| `docs/epic-01-markovian/spec.md` | R1-3 (this sprint) |
| `docs/epic-01-markovian/decisions/` | sprint.md rev 5 |
| `docs/evidence/ORACLE-V2/` | oracle-v2 sprint (code-complete, unrun) |
| Future sprint channels | item 3 (this sprint) |
| Additional evidence directories | Track A regens, future sprints |

The design reserves slots for these. When pass 1 executes, new content created
between now and then lands in the right place from the start — the layout is
forward-compatible.

---

**Next phase:** `design.md` — target-state layout for items 2+3, boards
verdict, channel argument, pruning rule text. Must be complete enough that
pass 1's builder needs only to execute.
