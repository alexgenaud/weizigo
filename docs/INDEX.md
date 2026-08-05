# INDEX — the single retrieval layer for weizigo docs

Task: INDEX-RETRIEVAL · Role: worker · Model: DSPro · Date: 2026-07-29

**This is the authoritative index.** Every question a reader or agent arrives
with has one line and one destination. No two files both look canonical for the
same question. If you need something not listed here, the index is incomplete —
file a bug.

---

## What is this project?

→ `AGENTS.md` (repo root) — the project pitch and non-negotiable rules
→ `docs/epistemic/PROGRESS.md` — the living specification (read this first for substance)
→ `docs/INTENT.md` — the human's own statement of purpose

## What is the state right now?

→ `bin/managent resume` — the composed resume surface (in flight, what landed, gate status; read at invocation, nothing stored)
→ `docs/status/HANDOVER.md` — tactical session-continuity snapshot
→ `docs/epistemic/PROGRESS.md` — strategic truth: what we know, what we need to know
→ `untracked/msg/<epic>/<sprint>/STATE.md` — crash-recovery anchor for live cross-agent traffic
→ `docs/infra/channel.md` — channel layout, pruning rule, and addressee convention

## What is known / what failed / what's open?

→ `docs/epistemic/PROGRESS.md` — the narrative hub (what we know → what we need)
→ `docs/epistemic/CLAIMS.md` — the full claim register (253+ rows, every claim ID with status and edges)
→ `docs/status/leak-crisis.md` — the crisis narrative: how C2/C3/C4 fell and what it means
→ `docs/epistemic/critique-2026-07-28.md` — what is known-wrong (§4 especially)
→ `docs/epistemic/roadmap-2026-07-28.md` — which ruleset we solve and how

## Why was X decided?

→ `docs/decisions/0001`–`0019` — Architecture Decision Records, append-only, by number
→ `docs/decisions/` — scan filenames for topic (each ADR states its topic in the filename)
→ `docs/epistemic/CLAIMS.md` §6 — 17+ discrepancies between documents, unresolved

## What backs claim Y? Where is the evidence?

→ `docs/epistemic/CLAIMS.md` — find the claim row; its `evidence` column lists source documents
→ `docs/evidence/<claim-id>/` — committed probe source and output (if it exists)
→ `docs/evidence/INDEX.md` — generated directory listing (**not yet generated** — deferred, project-restructure pass0 accept.md R2-1-EVIDENCE-INDEX; use INDEX-claim-evidence.md)
→ `docs/INDEX-claim-evidence.md` — generated claim→evidence cross-reference (regenerated 2026-08-01)
→ `docs/INDEX-claim-deps.md` — claim dependency tree: "what else falls if X is false" (new 2026-08-01)
→ `docs/INDEX-claim-task.md` — claim→task cross-reference
→ `bin/weizigo-claimlint` — parses CLAIMS.md and reports dangling evidence paths (C2 check)
→ `findings/` — machine-readable task findings (knowledge capture; claimlint C7 gate; schema in `findings/README.md`)

## What did model Z / task T produce? Is it still standing?

→ `docs/infra/model-perf.md` — model performance ledger
→ `docs/infra/dispatch/<TASK-ID>.md` — the dispatch brief (what was asked)
→ `docs/evidence/<claim-id>/` — the outputs
→ `docs/audits/` — independent audit reports (verify-then-promote gate)
→ `./bin/managent status` — the kanban: which tasks are done, in-progress, blocked, dispatchable

## What is in flight? What can I work on?

→ `./bin/managent status` — the kanban (dispatchable / in-progress / blocked / done / failed)
→ `bin/managent resume` — held files and live tasks (the old CURRENT.md declarations)
→ `docs/infra/dispatch/README.md` — the dependency graph and concurrency rules

## What do terms mean?

→ `docs/epistemic/GLOSSARY.md` — terms and abbreviations; project coinages marked `[project term]`
→ `docs/epistemic/names.md` — canonical names register

## What does each module / engine file do?

→ `docs/engine/ARCHITECTURE.md` — module map, ~6,200 lines of Zig across 16 modules

## How do I write a task for another agent?

→ `docs/infra/delegation/DELEGATOR.md`

## How do I execute a task I was handed?

→ `docs/infra/delegation/DELEGATEE.md` — read this, then your brief

## How do I dispatch / run an experiment from a console?

→ `docs/infra/dispatch/README.md` — the read order, dependency graph, concurrency rules

## What are the roles and who does what?

→ `docs/infra/delegation/ROLES.md` — Overseer, Advisor, Theorist, Orchestrator, Auditor, Dabir
→ `docs/infra/roles/ORCHESTRATOR.md` — Orchestrator-specific protocol
→ `docs/infra/roles/AUDITOR.md` — Auditor-specific protocol
→ `docs/infra/roles/DABIR.md` — Dabir-specific protocol

## How do I build / test / run?

→ `AGENTS.md` (repo root) §"Build / test / run"
→ `docs/infra/runner.md` — the memory-guard runner (`tools/runner`)
→ `docs/infra/host/incident-2026-07-29.md` — why builds must go through `tools/runner`

## How do I use the kanban?

→ `docs/infra/managent/spec.md` — managent schema
→ `./bin/managent` — run it directly (compiled binary, not Python)

## If I am an agent, what rules bind me?

→ `AGENTS.md` (repo root) — foreclosures (non-negotiable) and behaviour rules
→ `docs/infra/delegation/DELEGATEE.md` — worker principles (scope, report-don't-adapt, durability)
→ `docs/infra/agent-identity-and-worker-channel.md` — identity scheme and channel protocol

## What are the canonical names for things?

→ `docs/epistemic/names.md` — the table, the values, the two regions, ko-sensitive, chainable

## Is the 4×4 +2 value trustworthy? Is the checkpoint trustworthy?

→ `docs/epistemic/CLAIMS.md` rows `4x4.ANCHOR`, `4x4.COMPLETE-2026-07-21`, `4x4.F1`, `4x4.M6`
→ `AGENTS.md` foreclosures: "The committed ko-sensitive values are NOT trustworthy"
→ `docs/status/leak-crisis.md` — the crisis that makes them untrustworthy
→ `docs/research/retrograde-4x4.md` — has an erratum banner; the original claim is retracted

## Why is PSK (positional superko) not the generation target?

→ `AGENTS.md` foreclosure: "PSK exact-solve is intractable even on the EMPTY 2×2"
→ `docs/decisions/0013` — ADR-0013, the unsound finisher
→ `docs/research/ruleset-options.md` — the full ruleset analysis and state counts

## What is the eye-prune's status?

→ `docs/decisions/0006` — ADR-0006: the eye-prune argument (weak dominance)
→ `docs/epistemic/CLAIMS.md` row `GLOBAL.ADR0006-EYE` — CLAIMED, never directly falsification-tested
→ `docs/evidence/ADR-0006/` — committed evidence (falsification test added 2026-07-29)
→ `docs/infra/dispatch/ADR0006-FALSIFY.md` — the direct falsification test brief (done)

## Which claims have no committed evidence?

→ `docs/epistemic/CLAIMS.md` §4.2 — load-bearing unknowns ranked by dependent count
→ `docs/epistemic/CLAIMS.md` §7 — evidence-integrity note: 9 missing `untracked/` files
→ `docs/epistemic/claimlint-2026-07-28.md` — the first claimlint run: 79/79 PROVEN rows lack committed evidence
→ `docs/evidence/README.md` — inventory of lost and committed evidence

## What did 2B-4 conclude and does it still stand?

→ `docs/infra/dispatch/2B-4.md` — the brief
→ `docs/audits/2026-07-29-2b-6-full-review.md` — the independent audit (2B-6)
→ `docs/evidence/QA-023/probe-defect-2026-07-29/README.md` — the σ-in-arrival defect that invalidated it
→ `docs/evidence/QA-023/probe-fix-2026-07-29.md` — the corrected re-run (2B-PROBE-FIX)
→ `docs/epistemic/qa023-c2-adjudication-2026-07-29.md` — the final adjudication

## What is the F2-REMEDY and why does it exist?

→ `docs/research/f2-remedy-design-2026-07-29.md` — the design
→ `docs/decisions/0015` — ADR-0015: why the bracket premise is refuted
→ `docs/decisions/0017` — ADR-0017: the failed refutation attempt
→ `docs/decisions/0018` — ADR-0018: unanimous review confirming the orphan
→ `docs/decisions/0019` — ADR-0019: first-revisit truncation is the rule

## What is the single mismatch hypothesis?

→ `docs/epistemic/CLAIMS.md` rows `GLOBAL.ONEMISMATCH-DIAG`, `GLOBAL.ONEMISMATCH-CURE`
→ `docs/epistemic/PROGRESS.md` §"The single mismatch" (search for "non-Markovian")
→ `docs/epistemic/roadmap-2026-07-28.md` §2 — the Markovian vs non-Markovian diagnosis

## What foreclosures cannot be relitigated?

→ `AGENTS.md` (repo root) §"Non-negotiable rules" — the complete, authoritative list

## Where are the per-goban epistemic trees?

→ `docs/epistemic/boards/2x2/EPISTEMIC.md`
→ `docs/epistemic/boards/3x2/EPISTEMIC.md`
→ `docs/epistemic/boards/3x3/EPISTEMIC.md`
→ `docs/epistemic/boards/4x3/EPISTEMIC.md`
→ `docs/epistemic/boards/4x4/EPISTEMIC.md`
→ `docs/epistemic/boards/CONCEPTS.md` — cross-size concept-inventory

**Note:** The per-goban EPISTEMIC.md files are secondary narrative summaries.
`docs/epistemic/CLAIMS.md` is the authoritative claim register. Any conflict
between a board EPISTEMIC.md and CLAIMS.md is resolved in favor of CLAIMS.md.
(design.md §1.5, 2026-08-01)

## What ADRs exist and what did they decide?

→ `docs/decisions/` — 19 ADRs, numbered; each filename states the topic
→ `docs/epistemic/CLAIMS.md` §2.4, §2.6, §2.10 — ADR-claim rows with current status

## Where are the research findings?

→ `docs/research/` — one file per topic
→ `docs/research/ruleset-options.md` — ruleset analysis (PSK, kill-X%, score-on-cycle)
→ `docs/research/ko-sensitive-chainability.md` — why the GTP player loses at first ko
→ `docs/research/c2-falsification-3x2.md` — T13: how C2 was falsified at 3×2
→ `docs/research/consistency-audit.md` — the #2 self-consistency auditor results
→ `docs/research/retrograde-4x4.md` — the 4×4 scale run (⚠ has erratum banner)
→ `docs/research/kostate-census-2026-07-28.md` — the ko-state census (EXP-3)
→ `docs/research/open-hypotheses-2026-07-27.md` — H1–H5 open hypotheses register

## Where are the audits?

→ `docs/audits/` — independent audit reports
→ `docs/audits/2026-07-29-AUDIT-DSPro.md` — the comprehensive audit that spawned many cleanup tasks
→ `docs/audits/2026-07-29-AUDIT-REF-DSPro.md` — references audit
→ `docs/audits/2026-07-29-2b-6-full-review.md` — 2B-6: the load-bearing QA-023 audit
→ `docs/audits/2026-07-29-qa023-kernel-audit.md` — fixpoint kernel verification

## What documents are historical / superseded?

→ `docs/INDEX.md` §"Attic" below — the full list with reasons

---

## Attic — superseded, historical, and duplicative documents

These documents are kept for citation but are not current. Each carries a banner
at its top stating its status. **Do not rely on these for current truth.**

| file | status | replacement |
|---|---|---|
| `docs/AGENTS.md` | stray fragment | `AGENTS.md` (repo root) |
| `docs/engine/TODO.md` | SUPERSEDED | `docs/epistemic/PROGRESS.md` + `docs/epistemic/boards/4x4/EPISTEMIC.md` |
| `docs/infra/agents/workflow.md` | RETIRED 2026-07-28 | `AGENTS.md` + `docs/infra/delegation/DELEGATOR.md` |
| `docs/infra/agents/boss-role.md` | RETIRED 2026-07-28 | `docs/infra/delegation/DELEGATOR.md` |
| `docs/infra/agents/worker-role.md` | RETIRED 2026-07-28 | `docs/infra/delegation/DELEGATEE.md` |
| `docs/infra/delegation.md` | RETIRED 2026-07-28 | `docs/infra/dispatch/README.md` |
| `docs/infra/sprint.md` | RATIFIED rev 4 (d53c2a8); rewritten 200b974 (substance = D-16…D-20) | `docs/infra/dispatch/README.md` |
| `docs/infra/subagent.md` | RETIRED 2026-07-28 | `docs/infra/delegation/DELEGATEE.md` |
| `docs/research/next-step-consistency-auditor.md` | SUPERSEDED | `docs/research/consistency-audit.md` |
| `docs/research/oracle-3x3.md` | historical dead-end | `docs/research/retrograde-3x3.md` |
| `docs/research/forward-solve-scaling.md` | historical dead-end | — |
| `docs/research/terminal-territory-bug.md` | historical dead-end (fixed) | — |
| `docs/research/transposition-bug-root-cause.md` | historical dead-end (fixed) | — |
| `docs/research/strategy-open-questions.md` | historical (2026-07-15) | `docs/epistemic/roadmap-2026-07-28.md` |
| `docs/research/methods-and-findings.md` | historical overview | `docs/epistemic/PROGRESS.md` |
| `docs/research/ghi-and-superko.md` | historical (pre-ADR-0013) | `docs/decisions/0013` |
| `docs/research/data-model-and-measurements.md` | historical (2026-07-14) | `docs/decisions/0002` |
| `docs/status/handover-glm-5.2-2026-07-29.md` | ephemeral handover | superseded by later session |
| `docs/status/handover-glm-advisor-2026-07-28.md` | ephemeral handover | superseded by later session |
| `docs/status/handover-minimax-m3-2026-07-29.md` | ephemeral handover | superseded by later session |
| `docs/status/handover-opus-orcha-2026-07-29.md` | ephemeral handover | superseded by later session |

---

## Files that are authoritative for exactly one thing

This is the anti-confusion list. When two files could both appear canonical for
the same question, one is listed here as the authority.

| question | authoritative file | NOT (why) |
|---|---|---|
| what the project is and its rules | `AGENTS.md` (root) | `docs/AGENTS.md` (stray fragment) |
| the living specification | `docs/epistemic/PROGRESS.md` | `docs/engine/TODO.md` (superseded) |
| every claim's status | `docs/epistemic/CLAIMS.md` | per-goban EPISTEMIC files (may lag) |
| how to dispatch | `docs/infra/dispatch/README.md` | `docs/infra/delegation.md` (retired) |
| how to execute a task | `docs/infra/delegation/DELEGATEE.md` | `docs/infra/agents/worker-role.md` (retired) |
| the reframe deliverable | `AGENTS.md` foreclosures + `docs/epistemic/roadmap-2026-07-28.md` | — |
| ko-sensitive trustworthiness | `AGENTS.md` foreclosure (NOT trustworthy) | `docs/research/retrograde-4x4.md` (superseded claim) |
| the verify-then-promote rules | `AGENTS.md` foreclosures (standing rules from QA-023) | — |
