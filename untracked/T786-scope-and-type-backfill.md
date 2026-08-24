<!--managent set=A type=infra deliverables=findings/T786-scope-and-type-backfill.json,docs/infra/task-taxonomy.md holds=docs/infra/task-taxonomy.md,src/managent/main.zig-->
# T786 — freeze the taxonomy

Short name (the question this row answers): *can a row carry its type, scope and capabilities
without anyone guessing?*

**Landmark:** advances L1 (the dashboard tells the truth).

**SEQUENCING: holds `src/managent/main.zig`.** Check `bin/managent show` for the current holder
before starting.

## Do not run another derivation. It has been run, and the result tells you what to do.

Three blind passes over **578 tasks** (T817 brief-aware, T818 and T820 blind) plus an adjudication
(T819) already exist, committed at `docs/infra/task-corpus.jsonl` (578 rows),
`docs/infra/task-corpus.md` and `docs/infra/task-corpus-agreement.md`. Read them first. Their
measured outcome, per field:

| field | state in the corpus | inter-model agreement | what it means |
|---|---|---|---|
| **type** | 578/578 populated; closed vocabulary of **9** (audit, infra, orchestration, implement, battery, integration, research, spec, UNKNOWN) | blind LLM passes **35.6%**; the **brief-aware deterministic classifier scored 27/27 (100%)** against ground truth, versus 19/27 (70%) for the legacy metadata heuristic | **solved. Harvest it.** |
| **scope** | 578/578 populated but as **219 distinct free-form strings** | **0 of 578** raw agreement; all 578 had to be adjudicated | **not a taxonomy yet. Compress it.** |
| **capabilities** | 477/578, and **88% derived at `confidence: low`** from "brief demand phrases" | **578/578 undecidable** — vocabularies were model-specific, so agreement could not even be computed | **wrong source. Replace it.** |

**The law these three lines teach, and the reason this row is not another race:** where the
vocabulary was closed, agreement was computable and a deterministic reader was perfect; where it
was open, two capable models produced answers that could not even be compared. **A classification
exercise without a closed, pre-registered vocabulary measures vocabulary invention, not
classification.** Running a fourth derivation would buy a fourth incomparable vocabulary.

## What this row does, one method per field

1. **Type — harvest, do not re-derive.** Freeze the 9-value vocabulary. Join the corpus's type
   onto the task store. Where the corpus and store disagree or the corpus says UNKNOWN, leave
   UNKNOWN — **do not guess to fill a column**; an honest UNKNOWN is the whole point of this
   landmark. Report the count left unknown.
2. **Scope — compress deterministically, do not judge.** The 219 strings are not opinions: they
   are already mechanical facts about each row (deliverable counts, files-in-scope, code-write
   counts, "no brief on disk"). Bin them into a **small finite set — aim for 4 to 6 — by a stated
   rule, computed from those facts.** Publish the rule; a scope that cannot be recomputed from the
   store is not a scope. If a residue will not bin, name it rather than forcing it.
3. **Capabilities — adopt, do not derive from briefs.** The brief-phrase source produced 88%
   low-confidence and zero comparability. `docs/infra/races/capability-metrics.md` (T900) derived a
   real dimension set **from race outcomes** — what actually distinguished good results from bad.
   Adopt that as the capability vocabulary, and **do not backfill capabilities onto unraced tasks**:
   a capability reading is earned by a graded task, not inferred from a brief's verbs. Rows with no
   graded evidence carry no capability values, and that is correct.
4. **Assert at registration.** `managent add` requires a type from the frozen list and computes
   scope from the row's own facts. A row cannot be created without a type; the error names the
   legal values. This is what makes the backfill a one-time job instead of a standing duty.

## Acceptance

1. `docs/infra/task-taxonomy.md`: the frozen type list, the scope binning rule with its arithmetic,
   the adopted capability vocabulary and its provenance. One page, no prose padding.
2. **Red test first**, wired into `build.zig`: `managent add` is refused without a legal type, and
   the scope of a fixture row is computed correctly. Must fail today. Paste the failure.
3. Backfill counts stated: rows typed, rows left UNKNOWN, rows binned, residue named.
4. **Null control on the binning rule:** two rows with materially different facts must not land in
   the same bin, and re-running the rule must reproduce the bins exactly. A taxonomy that puts
   everything in one bin has the glm failure — 0.17 discernment — and is worth nothing.
5. `zig build test` end-to-end; sweep superset per `untracked/greenup/SWEEP-CONTRACT.md`.

## Constraints

- Do not edit `docs/infra/task-corpus.jsonl` — it is the committed evidence this row reads.
- Stage by name via `tools/git-commit-mine`; never `git add -A`.
