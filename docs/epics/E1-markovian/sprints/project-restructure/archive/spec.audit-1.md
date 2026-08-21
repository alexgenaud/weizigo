# spec-audit-1 — project-restructure pass0 spec

```
Auditor:   DSPro/T162
Date:      2026-07-31
Instrument: document review, fresh session
Scope:     docs/infra/project-restructure/pass0/spec.md (Revision 1, PROPOSED)
           against untracked/msg/milestone-01-ko-reframe/068-dabir-to-orchestrator.md
           + sprint.md @ 45deb10 (Revision 4, RATIFIED) for R1-2 contradiction check
Gate:      Spec audit per sprint.md §"Audit gates" — document review, fresh session
Verdict:   PASS
```

---

## Audit summary

The spec accurately restates 068's three items, adds appropriate structure
(requirements, risks, acceptance criteria, scope boundaries), and correctly
handles the sprint.md contradiction (item 1). One should-fix finding (F1) and
two observations (O1, O2) below. No blocker, critical, or must findings.

---

## Item-by-item verification

### Item 1 — epic/sprint directory hierarchy

| 068 element | spec coverage |
|---|---|
| New layout with `docs/epics/E1-markovian/sprints/<sprint>/passN/` | Verbatim in §1 "What we want" |
| Migrate from `docs/infra/oracle-v2/` and `docs/design/oracle-v2/` | Named in §1 preamble |
| "Do nothing" is acceptable | Preserved: "Do nothing, change nothing" in preamble, R1-2 alternative path |

**R1-2 — sprint.md contradiction:** HANDLED. The spec:

1. Cites the exact sprint.md section (`§"Passes, revisions, and directories"`) that fixes the current canonical layout as `docs/infra/<sprint>/passN/`.
2. Notes sprint.md's RATIFIED status and the commit (c8d666a) that ratified it.
3. Provides two resolution paths: amend sprint.md to rev 5 with ratification, or item 1 resolves to "change nothing."
4. States the forbidden outcome: "Migrating the tree while leaving the ratified process document describing the old tree is the one outcome this spec forbids."
5. Links this to acceptance criterion A4-process-coherence: "if the tree changes, `docs/infra/sprint.md` and `docs/INDEX.md` describe the tree that exists."
6. Lists it as risk #3.

This is thorough. The contradiction is not swept under the rug, resolved
unilaterally, or deferred to a later phase without acknowledgment. It is
promoted to a binding requirement with teeth (the item is rejected if
unresolved).

**Other R1 checks:**

- R1-1 (one name for the epic): correctly identifies the naming
  inconsistency between channel (`milestone-01-ko-reframe`), 068
  (`E1-markovian`), and INDEX.md (`untracked/msg/<milestone>/`).
- R1-3 (epic spec.md must be written): guards against empty directory
  placeholder. Identifies three existing documents that carry parts of the
  epic narrative.
- R1-4 (self-migration): ensures this sprint's own documents move
  consistently if item 1 lands.
- R1-5 (pass semantics): correctly cites sprint.md's pass/revision
  distinction.

### Item 2 — epistemic tree reorganization

| 068 element | spec coverage |
|---|---|
| Reorganize for retrieval, one-hop claim-to-evidence | R2-1 (retrieval is acceptance criterion, relocation is not) |
| Re-link references after reorganization | R2-2 (provenance text frozen-with-a-pointer), R2-3 (code change: claimlint.zig hardcodes) |
| Orphan-claim report | R2-4 (dispositioned list, not just counters) |
| Re-verification backlog | R2-4 |
| No prescription — design the layout | R2-1 preserves this ("Movement is a means, and an expensive one") |
| `docs/boards/` is a relic | R2-5 correctly notes 068's error: `docs/boards/` does not exist; the relic is `docs/epistemic/boards/` |

R2-6 (no status changes to improve counters) correctly gates against the
temptation to clean up CLAIMS.md as part of a restructuring sweep.

### Item 3 — channel organization and pruning

| 068 element | spec coverage |
|---|---|
| Channel stays in `untracked/msg/` | Affirmed in preamble |
| Split sprint-specific from epic-level | R3-1 raises the `docs/**/channel/` invariant concern; R3-4 covers addressee split |
| Sprint messages under epic/sprints dir, still untracked | Captured, challenged in R3-1 |
| Pruning rule: archive/delete completed passes | R3-3 (rule written down, opt-in per pass; deletion out of scope for pass 0) |
| Split agent-to-agent vs broadcast | R3-4 ("considered, rejected, here is why" satisfies) |

R3-1 is a genuine addition: it identifies the tension between the
`docs/`-in-git invariant (bought with T13's evidence loss) and a
`docs/**/channel/` that looks canonical but is untracked. The spec does
not forbid it but requires the design to argue for it against the failure
mode it resembles. This is a proper spec requirement, not scope creep.

---

## Acceptance criteria — coherence check

| criterion | assessment |
|---|---|
| A1-verdict | Each item must have an explicit verdict in accept.md. Consistent with 068's "If any item is best left unchanged, the spec says so and why." |
| A2-no-regression | claimlint no worse than baseline. Correctly notes 068's "claimlint green" is unachievable as literally written (10 C1a orphans, 13 C2 dangling paths at 45deb10) and re-scopes it to "no new findings." |
| A3-links | No dangling tracked links. Enforced by checker, not inspection. Pre-existing danglers reported, not silently inherited. |
| A4-process-coherence | sprint.md and INDEX.md describe the tree that exists. Directly derived from R1-2. |
| A5-history | git mv, one logical move per commit. Mechanical quality. |
| A6-backlog | Orphan report + re-verification backlog, every row dispositioned. Due regardless of layout verdicts. |
| A7-no-adjudication | Zero claim status changes, zero number changes, zero ADR conclusion changes. |
| A8-build | zig build succeeds after source changes under R2-3. |

All criteria are satisfiable as written, none contradict 068 or sprint.md.

---

## Scope boundaries — check

§5 "Out of scope for pass 0" explicitly lists:
- No channel deletion
- No claim status changes or substance fixes
- No rewrite of PROGRESS.md/CLAIMS.md/INTENT.md content
- No `src/`, `bin/`, `data/`, `artifacts/` reorganization
- `docs/audits/`, `docs/research/`, `docs/status/` layout deferred

These are consistent with 068's scope (three items, nothing more) and are
stated affirmatively so the boundary is a decision, not an oversight.
ADRs are in `docs/decisions/`, which is under item 1 (epic-level ADRs
under `docs/epics/E1-markovian/decisions/`). That is in scope; the omission
from §5 is not a gap — item 1 covers it.

---

## Findings

### F1 — INDEX.md attic entry stale (should fix)

`docs/INDEX.md` §"Attic" lists:

```
| `docs/infra/sprint.md` | RETIRED 2026-07-28 | `docs/infra/dispatch/README.md` |
```

But `docs/infra/sprint.md` is Revision 4, RATIFIED (G-human, 2026-07-31, c8d666a).
The INDEX.md entry predates the un-retirement (the RETIRED tag is 2026-07-28,
three days before ratification). The spec correctly cites sprint.md as
authoritative at 45deb10 (the ratification commit).

This does not affect the spec's correctness, but the attic entry would
mislead an agent who reads INDEX.md alone. The sprint itself should fix
this; it is squarely a "process coherence" item under A4.

**Disposition for this audit:** report to the builder. Not a spec defect.

### O1 — reference count is approximate (observation, not a finding)

The spec states "400 `docs/infra/...` path references and 66
`docs/design/...` references across tracked markdown (measured at
45deb10)." A fresh count at the current tree yields ~381 `docs/infra/`
references in tracked markdown. The difference is within measurement noise
(commits between 45deb10 and now, false positives from code blocks). This
is not material to the spec's correctness and does not affect its
requirements.

### O2 — "epic" vs. sprint.md definition (observation, not a finding)

sprint.md @ 45deb10 defines an epic as having "no well-defined goal yet —
its goal emerges from completed sprints." The proposed epic
`E1-markovian` (or `milestone-01-ko-reframe`) has a defined goal (the
ko reframe). R1-1 requires settling one name and one word, which gives the
design phase authority to pick whichever term fits. The spec does not
explicitly flag the definitional tension, but R1-1's resolution will
settle it — if the design keeps "epic," it should reconcile with
sprint.md's definition; if it picks "milestone," there is no tension. The
spec is not defective for leaving this to design.

---

## Verdict: PASS

No blocker / critical / must findings. The spec:

- Accurately captures all three items from 068 with no omissions
- Correctly handles the sprint.md contradiction (R1-2) — names it, cites
  the exact source, provides resolution paths, forbids the wrong outcome,
  ties it to a gating acceptance criterion
- Adds value beyond 068: explicit requirements (R1-1 through R3-4),
  acceptance criteria (A1-A8), risk assessment, scope boundaries
- Preserves 068's "do nothing, change nothing" escape hatch for every item
- Is internally consistent and follows sprint.md's own format (Revision,
  Status, Author, Source headers)

One should-fix finding (F1) reported: INDEX.md attic marks sprint.md as
RETIRED despite current RATIFIED status. This is not a spec defect but
should be fixed in this sprint under A4-process-coherence.
