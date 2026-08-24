# S05 — Startup surfaces: one verb to orient any agent (SEED)

**Status:** SEED, not ratified. **Author:** claude-fable-5 at the operator's console, 2026-08-22.
**Kanban row:** T583. **Operator direction:** "I suspect ALL agents startup and read a tangled
spaghetti mess of AGENTS.md and other documents with archeological negative examples and
contradictions" — review every startup file, optimize per model and agent-type, including the
'Fable, get us back on course' role (possibly already recorded as **Navigator**).

## 1. Goal in one line

Any agent, any model, any seat, at any time, runs **one command** — `managent orient
[--role <r>]` — and receives a current, contradiction-free, role-sized orientation composed at
read time from the store and a small set of audited sources; no agent ever assembles its own
startup reading list again.

## 2. What exists

`managent orient` (≤150-line worker preamble from AGENTS.md / DELEGATEE.md / sprint.md /
DIRECTION.md + kanban + activity) and `managent resume` (resume surface from tasks.json + git +
claimlint + the RESUME-* handover pointer). The composition mechanism is right; the **sources** and **role fit** are
unaudited.

## 3. The work

1. **Census** every startup-read surface: AGENTS.md, DELEGATEE.md, DELEGATOR.md, sprint.md,
   DIRECTION.md, handover docs, role docs (docs/infra/roles/, docs/infra/agents/), bundle
   preambles, the Claude auto-memory convention — who reads what, at which seat, at what cost.
2. **Audit for archaeology**: contradictions, superseded rules still stated, negative examples
   presented before the rule, duplicated principles with drifted wording. Every finding: fix the
   source or delete it — orient must compose from clean inputs (prose is not a remedy).
3. **Role-size the output**: `orient --role` variants per agent type — leaf worker, sprint
   console, auditor, reconciler, **navigator** — each ≤ a stated line budget, each containing
   ONLY what that role acts on. Verify whether "Navigator" is already a recorded role
   (2026-07-31 handover used the name) and either adopt or retire it deliberately.
4. **The navigator role** (the operator's 'get us back on course' session): `orient --role
   navigator` emits the ordered ground-truth walk — store state first (`status`/`audit`), then
   the newest roadmap, rulings in force (orchestration-layer-spec §7*), live sprint seeds,
   recent git — with the standing instruction: judge docs against reality, deviations +
   corrections against the landmarks, one operator question max. The reading list lives in the
   verb, not in anyone's memory.
5. **Controls** (never trust a green preamble): a seeded contradiction between two sources must
   be *detected* at compose time, not silently harmonized; a role variant over budget fails its
   gate; `orient` output for each role is snapshot-tested.

## 4. Non-goals

No new documents (this sprint deletes more than it writes). No change to sprint pass protocol.
No memory-system changes (Claude auto-memory is harness-scoped convenience, not a project
surface — nothing project-critical may live only there).

## 5. Gates

Phase audits per the ruled audit-loop (cap 3). Acceptance: `gate: <command>` where possible —
the snapshot tests + the seeded-contradiction control; final acceptance `gate: audit`.
