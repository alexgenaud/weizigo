<!--managent set=A holds=AGENTS.md,docs/infra/roles/ORCHESTRATOR.md,docs/infra/roles/DABIR.md,docs/infra/roles/AUDITOR.md,docs/infra/delegation/ROLES.md,docs/infra/delegation/DELEGATOR.md,docs/infra/delegation/DELEGATEE.md,docs/infra/dispatch/-->
# ROLE-NAMES — instruction files name roles, not models; models live in STATE.md and model-perf.md only

**Opened by:** the human, 2026-07-29, via Dabir (msg 042 §1). ANALYSIS + doc edits — no code, no engine, no CLAIMS.md.

## The defect

`AGENTS.md:68` says `Opus/Orcha`, `DSPro/Dabir` — but Orcha was GLM-5.2 two days ago and Opus 5 today. A standing instruction file that binds a model to a role is wrong the moment the allocation changes. Model names belong in exactly two places: `STATE.md` (the live allocation — who holds which seat right now) and `model-perf.md` (the historical ledger). Everywhere else, the role name is the durable identifier.

The same pattern appears in dispatch briefs: `"Agent: Fable"`, `"Opus reviews adversarially"`, `"dispatched to DeepSeek-Pro"`. When the same brief is re-used after an allocation change, the model name is misleading at best and a wrong instruction at worst.

The AGENTS.md identifier convention is `model/role` for court seats — but the convention itself is the problem. A role is stable; a model is not. The format should be just `role` for court seats and `task-id` for workers. The model is recorded at dispatch time in managent's `agent` field, which feeds model-perf — it doesn't need to be in the instruction.

## The task

1. **Sweep the standing instruction files** — `AGENTS.md`, `docs/infra/roles/*.md`, `docs/infra/delegation/*.md` — and replace every model-name reference with the role name:
   - `Opus/Orcha` → `Orchestrator` (or leave as bare `Orcha`)
   - `DSPro/Dabir` → `Dabir`
   - `Fable 5` / `Opus 5` in role descriptions → `the Orchestrator` / `the Auditor` etc.
   - Model names in examples → role names
2. **Update the identifier convention in AGENTS.md** — the `model/role` format becomes just `role` for court seats, `task-id` for workers. The model is recorded in managent and model-perf, not in the identifier.
3. **Sweep dispatch briefs** — `docs/infra/dispatch/*.md`. Where a brief says "Agent: Fable" or "dispatched to Opus", replace with the capability needed: `reasoning: sustained`, `adversarial review`, `measurement executor`, etc. Per `ROLES.md` §"Specification restraint": "specify only what changes the outcome, and say why." The brief says *what kind of thinking is needed*; STATE.md says *which model provides it today*.
4. **Do NOT touch:** `model-perf.md` (it IS the model ledger), `CLAIMS.md` (records which model found/adjudicated what — that's provenance, not instruction), the channel (historical record), `tasks.json` (the `agent` field is the performance record and the `note` field is historical). `CURRENT.md` is retired (2026-08-03) — held files live in the kanban `holds=` field and are listed by `bin/managent resume`.
5. **STATE.md gets a one-line note** that it is now the single source of truth for which model holds which seat — every other file defers to it.

## Acceptance

- `grep -rn "Opus\|Fable\|GLM-5\|Kimi-k2\|Minimax-m3\|DeepSeek-Pro\|DSPro\|DSFlash\|Kimi-k3" docs/infra/roles/ docs/infra/delegation/ AGENTS.md` returns **zero** model-name references outside of historical examples clearly marked as such.
- Dispatch briefs say *what capability is needed*, not *which model*.
- AGENTS.md identifier convention updated.
- STATE.md carries the single-source-of-truth note.
- No model-perf.md rows, CLAIMS.md provenance, channel messages, or tasks.json records touched.

## Deliverable

The edited files. **Holds:** `AGENTS.md`, `docs/infra/roles/*.md`, `docs/infra/delegation/*.md`, `docs/infra/dispatch/*.md`. No other task should hold these concurrently.

**Read first:** `AGENTS.md:67-72` (the identifier convention), `ROLES.md:1-150` (the role descriptions and the independence rule), `DABIR.md`, `ORCHESTRATOR.md`, `AUDITOR.md`, `STATE.md` (the live allocation to verify against).
