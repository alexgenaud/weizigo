# DSPro/Orcha stand-down handover — 2026-08-01

```
Role: Orchestrator · Model: DSPro · Date: 2026-08-01 (stand-down)
Status: BACKFILLED by T205 (DSFlash), source
  untracked/msg/milestone-01-ko-reframe/074-navigator-to-all.md +
  DECISIONS.md D-16…D-20. No handover file was produced at stand-down
  (coherence-audit CA-3); this is the ORCHESTRATOR.md:5-mandated
  docs/status/handover-<model>-<date>.md, reconstructed 2026-08-01 after
  the coherence audit (docs/audits/2026-08-01-coherence-audit.md).
```

Tactical, per-session snapshot. Strategy lives in `../epistemic/PROGRESS.md`;
in-flight task state lives in `CURRENT.md`; the durable record of this
handover's content is the audit, `DECISIONS.md`, and the kanban history.

## Read order

1. `../audits/2026-08-01-coherence-audit.md` — the interregnum audit
   (CA-1…CA-19) and its remediation roadmap.
2. `CURRENT.md` — live state (refreshed 2026-08-01 by T205).
3. `../status/roadmap-audit-remediation-2026-08-01.md` — D-A…D-D rulings,
   Phase 1–3.
4. `../epistemic/PROGRESS.md` — strategic overview.
5. `../../AGENTS.md` — behavior rules and foreclosures.

## What the seat accomplished (T165–T200)

36 tasks landed under DSPro/Orcha: oracle-v2 through M4a; verify-battery
through P3-H including T178's colex catch (exp6 rank vs engine colex —
CRITICAL, fixed in T185); knowledge-capture built (T188/T194); Argus built
(T195); orcha-tools accepted (T196 — A1 FAIL ticketed, root-fixed by T204);
project-restructure scoped (T197). The WZO2 artifact landed under T192
(`untracked/oracle-v2/oracle-4x4-v2.wzo2`, 518.1 MB, SHA-256 `a892d689…`,
recorded in `artifacts/SHA256SUMS` at `f851102`).

## What is true now

- **sprint.md rev-5 substance survives as D-16…D-20** in DECISIONS.md
  (plan.md replaces strategy.md; epic as arena; spec origin corrected;
  ownership principle "whoever specs, accepts"; ephemera colocated).
  `200b974` rewrote sprint.md wholesale; nothing remains to ratify.
- **oracle-v2 M1 G2 and verify-battery M1 G2 cleared in practice**; both
  sprints' build lanes shipped (post-G2 lanes, P3-A…P3-H executed). Status
  headers of both sprints' spec/plan/design-M1 flipped to RATIFIED by T205.
- **T196 A1 (managent `suggest` minting duplicate IDs) was the one live
  data-integrity defect** in the dispatch substrate. Root fix landed with
  T204 (`a98bf04`: `parseStateJson` next_id reconciliation + `audit`
  collision check + `sync --peek`).

## What is stale (found by the coherence audit)

- `docs/status/CURRENT.md` and `untracked/msg/…/STATE.md` described a
  pre-WZO2 board (CA-2) — fixed by T205.
- Six sprint phase docs carried "PROPOSED … awaiting ratification" while
  their lanes shipped (CA-14) — fixed by T205.
- `untracked/managent/tasks.json` is a dead EXP-era store shadowing the
  live `docs/infra/managent/tasks.json` (CA-18) — tombstone in T207.
- `docs/evidence/INDEX.md` was routed in INDEX.md but never generated
  (CA-10) — annotated by T205; generation deferred (project-restructure
  accept.md R2-1-EVIDENCE-INDEX).

## Gotchas

- **Two Fable sessions share one git index** — commit early, stage nothing
  you didn't write.
- Mint kanban tasks with explicit IDs only until CA-1's root fix is verified
  end-to-end (T204 landed; `suggest` remains single-writer while unproven).
- `docs/decisions/ADR-0020-*.md` was amended and committed (`0c3c3ac`);
  its "24 mismatch states" clause predates T102's finding — cite T102/T103
  for that invariant.
- Human-owned and untouched by this roadmap: ADR-0020 fork ruling,
  WZO1-brackets, rule-mismatch rulings, pass1 go/no-go (T203).

## Critical state

- The WZO2 artifact was built (T184/T192, `f851102`) but **failed M4a
  acceptance**: T193 verdict=fail-found (artifact invalid), follow-up T212
  (rebuild-remeasure) in progress. Do not cite the artifact as accepted.
- G3 ×2 open (oracle-v2 accept, verify-battery accept); verify-battery
  V-13 fleet run / V-14 absorption open.

## Immediate next task

Read msg 074 + the coherence audit + DECISIONS.md D-16…D-20; adopt Argus as
cadence step 0; follow **T212** (WZO2 rebuild-remeasure — the T193
fail-found follow-up in progress); dispatch T203 once pass1 gets the human
go-ahead (D-D); resume sprint flow (verify-battery V-13 / V-14, oracle-v2
G3). D-C rules the next Orcha is **Opus or Fable** (human's call), seated
after the Phase-1 gate.

## Read next

`../status/roadmap-audit-remediation-2026-08-01.md` ·
`../epistemic/CLAIMS.md` · `../infra/managent/spec.md` ·
`../infra/model-perf.md` (per-task ledger)
