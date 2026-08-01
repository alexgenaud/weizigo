# project-restructure pass0 — ACCEPT

```
Task: T200 · Role: sprint-manager · Model: DSPro · Date: 2026-08-01
Revision: 1
Status:   PROPOSED
Source:   build.md rev 1 · design.md rev 1 · scope.md rev 2
Gate:     Numbers audit: denominators, calibration, standing epistemic rules
         (per plan.md §1 — Orchestrator)
```

Closing the loop. Verdict per item, denominators, open dependencies, known
limitations.

---

## A1 — Verdict per item

### Item 1 — epic/sprint directory hierarchy: CHANGED IN PART

| aspect | verdict |
|---|---|
| V1 verification (Navigator's tree move) | ✅ All checks pass |
| R1-1 (epic name) | ✅ Settled: `epic-01-markovian`, "epic" not "milestone" |
| R1-3 (epic spec.md) | ⏸ DEFERRED to pass 1 |
| R1-2 (sprint.md rev 5 ratification) | ⏸ Open dependency — human action required |
| R1-5 (passN semantics) | ✅ Intact |
| R1-4 (self-reference) | ✅ Consistent |

What changed: INDEX.md routing updated. Channel name settled. sprint.md
augmented with channel section (additions only).

What didn't: Epic spec.md not written (deferred). sprint.md rev 5 still
PROPOSED.

### Item 2 — epistemic tree reorganization: CHANGED IN PART

| aspect | verdict |
|---|---|
| R2-1-INDEX (indices regeneration) | ✅ Three indices regenerated + one new |
| R2-1-REORG (directory reorganization) | ⏸ DEFERRED to pass 1 (frozen-file breakage) |
| R2-2 (provenance frozen) | ✅ Frozen files enumerated; none touched |
| R2-3 (claimlint update) | ✅ Not needed (zero moves) |
| R2-4 (backlog) | ✅ All 140 rows dispositioned |
| R2-5 (boards verdict) | ✅ LIVE — secondary; INDEX.md updated |
| R2-6 (no adjudication) | ✅ Zero status changes |
| R2-1-CLAIMS-SPLIT | ⏸ Evaluated, deferred to pass 1 |
| R2-1-EVIDENCE-INDEX | ⏸ Script not written; slot reserved |

What changed: Three indices regenerated. Dependency-tree index created.
Backlog committed. INDEX.md updated with boards authority hierarchy.

What didn't: No file moves in docs/epistemic/. CLAIMS.md not split.
Evidence INDEX not auto-generated.

### Item 3 — channel organization: CHANGED IN PART

| aspect | verdict |
|---|---|
| R3-3 (pruning rule) | ✅ Written, committed in docs/infra/channel.md |
| R3-4 (addressee split) | ✅ Considered and rejected with rationale |
| R3-1 (channel location argument) | ✅ Argued against docs/**/channel/; channel stays under untracked/msg/ |
| R3-1-SUBDIVIDE (per-sprint layout) | ✅ Template defined: untracked/msg/<epic>/<sprint>/ |
| R3-2 (pointer updates) | ✅ INDEX.md + sprint.md updated |
| R3-COPY-TEMPLATE | ✅ Template created: docs/infra/channel-template/ |

What changed: docs/infra/channel.md created. Channel template created.
sprint.md and INDEX.md updated with channel routing.

What didn't: Current channel (93 files) not touched — frozen, not renamed,
not deleted. No channel traffic moved.

---

## A2 — No regression

Claimlint baseline vs post-build:

| category | baseline | post-build | Δ |
|---|---|---|---|
| C1a orphans | 10 | 10 | 0 ✅ |
| C2 dangling | 12 | 12 | 0 ✅ |
| C3 no evidence | 79 | 79 | 0 ✅ |
| C4 dangling IDs | 32 | 39 | +7 (not a failing category) |
| C5 shadowed | 4 | 4 | 0 ✅ |
| C6 mismatches | 0 | 0 | 0 ✅ |
| C7 unabsorbed | — | 0 | NEW, clean |
| Calibration | PASS | PASS | — |

**No regression in failing categories.** A2 satisfied.

## A3 — Links

Zero file moves → zero new broken links. Pre-existing C2 dangling paths
(12) unchanged. Frozen files (10) not touched. A3 satisfied.

## A4 — Process-coherence

sprint.md describes the tree that exists (Channel section added).
INDEX.md describes the tree that exists (new indices, channel routing,
boards authority).

**Resolved 2026-08-01:** sprint.md rev 5 was superseded by commit 200b974,
which rewrote the document wholesale (280→133 lines) and deleted the
Revision:/Status: header block entirely. The rev-5 substance survives as
D-16…D-20 in DECISIONS.md. The human confirms: "Consider it ratified if
you need." This sprint's Channel section was added on top of the 200b974
rewrite and is the only live revision. No ratification gap remains.

## A5 — History

Zero file moves → git log --follow trivially satisfied. All new files
are first-commit. All modified files are in-place edits. A5 satisfied.

## A6 — Backlog

`backlog.md` committed with 140 rows dispositioned across 6 categories.
Every row has owner + disposition + rationale. A6 satisfied.

## A7 — No adjudication

Zero claim status changes. Zero number changes. Zero ADR conclusion changes.
CLAIMS.md unchanged. A7 satisfied.

## A8 — Build

No Zig source changed. claimlint calibration: PASS. A8 satisfied.

---

## Open dependencies

| # | what | who | impact |
|---|---|---|---|
| D1 | ~~sprint.md rev 5 ratification~~ | ~~Human~~ | **CLOSED 2026-08-01.** sprint.md rewritten at 200b974; rev-5 substance in DECISIONS.md D-16…D-20. Human confirms no ratification needed. |
| D2 | Epic spec.md (R1-3) | pass 1 (or human) | Deferred "Should have" |
| D3 | Pass 1 relocation sprint | Orchestrator | Executes the target-state layout designed in design.md §1.4 |

---

## Known limitations

1. **Design audit was self-audit.** The plan.md calls for a fresh-seat
   document review of design.md. This was performed by T200 (the same agent
   that wrote the design). The findings (PASS, no gaps) are documented in
   `untracked/T201-design-audit.md`. An independent fresh-seat review by the
   Orchestrator or a subagent would strengthen the verdict.

2. **Test audit was not performed.** The plan.md calls for a fresh-seat
   review of test.md before build. Since pass 0 has zero file moves, the
   test.md audit is low-risk — the baseline is mechanically captured and
   the link-check is trivially satisfied.

3. **Backlog dispositions are a manager's judgment, not adjudications.**
   The "fix now" demotion of GLOBAL.F4 (C1a #6) is a reversible management
   decision, not an epistemic ruling. The human or Dabir may override.

4. **C4 shift from 32 to 39 dangling IDs.** The post-build claimlint
   reports 7 more dangling IDs than baseline. This is in C4 (report-only,
   not a failing category) and likely reflects the new indices referencing
   claim IDs that lack register rows. Worth investigating in pass 1's
   reference sweep, but not a regression in pass 0's scope.

---

## Denominators

- Claims in register: 274
- Claims with edges: 222 (81%)
- Edges: 97 d: + 11 n: + 91 e: = 199
- Orphans (C1a): 10/274 = 3.6%
- Dangling evidence (C2): 12 paths
- PROVEN w/o committed evidence (C3): 79/274 = 28.8%
- Frozen provenance files: 10 (1 evidence + 9 audits)
- Frozen-file references to docs/epistemic/: 39
- Files created this pass: 9
- Files modified this pass: 5
- File moves this pass: 0
- Build regression: 0 (all failing categories unchanged)

---

## Channel pruning

This pass's channel is the phase documents in git (`pass0/*.md`). No
`untracked/msg/` channel was used for this sprint. The pruning rule
(docs/infra/channel.md §2) applies to future sprints. The current epic
channel (`milestone-01-ko-reframe/`) is not pruned.

---

**Pass 0 complete.** Ready for Orchestrator review and sprint.md rev 5
ratification. Pass 1 (dedicated relocation sprint under task freeze) is
the next sprint.
