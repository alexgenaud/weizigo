# Roadmap — coherence-audit remediation and Orcha reactivation

```
Author: Fable (auditor seat) · Date: 2026-08-01 · HEAD: bb8029e (+2 uncommitted)
Source: docs/audits/coherence-audit-2026-08-01.md (CA-1…CA-19)
Status: ACTIVE — D-A…D-D ruled by the human 2026-08-01 (recorded below);
  D-E (dogfoods) still open.
Lifecycle: ephemeral planning doc; delete once Phase 3 closes (the durable
  record is the audit, DECISIONS.md, and the kanban history).
```

Committed together per D-B: `docs/audits/coherence-audit-2026-08-01.md`,
`docs/infra/managent/tasks.json` (next_id 203→204 mitigation), this file.

---

## Phase 0 — human rulings (nothing dispatches before D-A, D-B)

| ID | Decision | Ruling (2026-08-01) |
|----|----------|---------------------|
| D-A | Delegation shape | **RULED: five task bundles**, T204 serial then T205–T208 parallel. |
| D-B | Commit the audit + mitigation | **RULED: commit as-is** (audit + next_id fix + this roadmap). |
| D-C | Orcha seat + timing | **RULED: Opus or Fable**, seated after Phase 1 gate, with tolerance for instruction rough edges and an explicit **mandate to update, correct, and improve tooling, role descriptions, and infrastructure/orchestration/delegation files** as it works. Auditor's recommendation between the two: **Opus** — the seat is sustained coordination plus infra repair, squarely Opus-shaped under the allocation policy, and it avoids a second Fable sharing this session's git index. The deferred P2 items (CA-15, managent test coverage) fold into this mandate instead of pre-registered tasks. |
| D-D | T203 / pass1 | **RULED: green-light after Phase 2** — T203's needs become the Phase-2 bundles; prerequisite text reworded (the "rev 5 ratified" gate was unsatisfiable, superseded by D-16…D-20). |
| D-E | Dogfoods #1/#2 | **OPEN.** Audit §6 recommends closing both (PASS with minor finding; PASS-WITH-FINDINGS). |

## Phase 1 — substrate (serial; one task; gate below)

**T204 — managent integrity** (CA-1 root, CA-19) — src/managent/main.zig:
`parseStateJson` reconciles `sys_next_id = max(next_id, max(T<N>)+1)`;
`audit` gains a next_id-collision check; `sync` gets `--peek` (or documented
seat-assertion); regression test for the T196/A1 repro **written before the
fix** (delivery-pipeline rule). Suggested model: DSPro.

**Phase-1 gate (human or auditor verifies):** regression test red→green;
`managent audit` flags a hand-seeded collision; store round-trips. Until
this gate, `suggest` is single-writer-only (mitigation holds but the bug
is latent).

## Phase 2 — parallel bundles (set B; disjoint file sets; after gate)

| Task | Scope (audit refs) | Files | Model (suggested) |
|------|--------------------|-------|-------------------|
| T205 — status surfaces + handover | CA-2, CA-3, CA-14 | STATE.md, CURRENT.md, INDEX.md:223, docs/README.md:26, 6 sprint-doc headers, new docs/status/handover-dspro-2026-08-01.md | DSFlash |
| T206 — tooling seams (code) | CA-6, CA-9, CA-17 | tools/runner (returncode ~4 lines), tools/gen-indices:207 (+regen indices), build.zig/bin (absorb deploy + root-walk) | DSPro |
| T207 — process-doc sweep | CA-4, CA-10, CA-12, CA-13, CA-16, CA-18 (status lines) | subdelegation.md, manager-brief-template.md, channel.md, AGENTS.md, ORCHESTRATOR.md (+Argus step 0), DABIR.md, DELEGATOR.md, DECISIONS.md annotations, INDEX.md routing, SPEC-msgbus.md, agent-identity doc | DSFlash |
| T208 — evidence + Argus triage | CA-5, CA-11 | copy T172-blind-analysis → docs/evidence/CODE.VB-BLINDGAPS/ + repoint CLAIMS.md:503 + sprint.md exemption sentence; investigate oracle-3x2.wzo load FAIL (exit 124: artifact regression vs runner wall-clock?) | DSPro |

Brief rules (all four): self-contained; pin the post-Phase-1 sha; list exact
file:line edits from the audit (workers don't re-derive scope); findings to
`findings/T<id>-*.json` in the findings/README.md schema (harness docs point
wrong until T207 lands); no model names inside briefs — human assigns at
runtime. T205/T207 both touch docs/ — each brief carries its explicit file
list; touching outside it is a stop-and-report.

**Phase-2 exit:** all four absorbed; claimlint ≤ honest-debt floor
(C2=12/C1a=10 — T208 may lower C2 by one if the /tmp disposition is
codified); indices regenerated; Argus re-run clean or its CRITICAL ticketed.

## Phase 3 — Orcha reactivation (per D-C ruling)

Seat Opus (or Fable, human's call at dispatch) as Orcha after the Phase-1
gate, with the D-C mandate: beyond dispatching, it owns updating,
correcting, and improving tooling, role docs, and infra/orchestration/
delegation files as friction surfaces — rough edges in instructions are
expected and within its remit to fix, not blockers. First-shift brief =
audit §8: read msg 074 + audit + D-16…D-20; adopt Argus cadence step 0;
dispatch **T193** (M4a acceptance run — the oldest real deliverable still
parked); dispatch T203 once its Phase-2 needs clear (D-D); resume sprint
flow (verify-battery V-13 fleet run / V-14 absorption, oracle-v2 G3).

## Deferred (folded into the D-C mandate — not pre-registered)

CA-15 parser unification (claimlint imports claims_register.zig) and
managent test coverage (suggest/done/tell/inbox) — the seated Orcha
registers these under its improvement mandate when nothing else is in
flight against the register/lint pair.

## Standing risks while this runs

- Two Fable sessions have historically shared one git index — commit
  early, stage nothing you didn't write.
- `untracked/managent/tasks.json` is a dead EXP-era store (CA-18) — anyone
  reading it reconstructs July's board; tombstone it in T207.
- Human-owned and untouched by this roadmap: ADR-0020 fork, WZO1-brackets,
  rule-mismatch rulings.
