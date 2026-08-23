# Orchestration-refactor sprint — seed (ratified rulings, 2026-08-23)

Operator + Fable seat (T733), ratified in discussion 2026-08-23. This seed is the input to
the sprint spec (T748 drafts it; the operator ratifies the spec revision). North star:
**state in one pane, pauses that expire, gates as data, one arbiter, briefs without
boilerplate, models as registry entries.**

## Ratified rulings

1. **One policy file** — per-family appetite, caps, allow/deny lists, cooldowns, window
   budgets; every entry carries owner, reason, expiry. Keeper, dispatch, and subagent read
   it; env vars become overrides only. Kills invisible defaults (the D036 deny default, the
   5M invented window budget T736 recalibrated).
2. **Expiring pauses** — scoped per family; 5-hour default maximum unless explicitly longer;
   a pause must be re-asserted or it lapses loudly. (The 2.5-day silent global cooldown of
   2026-08-20→23 is the incident this ends.)
3. **One dashboard** — presentation moves into `bin/managent` (Zig, the one reader of store +
   policy file); watch-fleet.sh becomes a thin refresh wrapper. Human surfaces show SHORT
   model names only (opus, dspro, oxalpha, …) via model-registry.md's one table; canonical
   labels live in stats and records. Empty sections are omitted; recovered height shows rows
   (T738/T739 are the interim precedent).
4. **One arbiter** — host-pressure and shed-load decisions move out of N runners into a
   single decision point. Absorbs held rows T712 (one arbiter) and T713 (resident-tenant
   dispatch check); T711's declared-tenant fix already landed.
5. **Registration flow** (operator's design): agents NEVER write tasks.json. An agent
   authors `untracked/T-<slug>.md` first (filenames collide gracefully), then ONE
   `bin/managent` call registers/claims — managent is the sole store writer and the
   recoverable conflict point. Direct tasks.json edits fail mechanically (hook/permission),
   not by prose. Registration requires: title ≤40 chars, deliverables, **landmark tag**
   (T747), needs/holds edges read from the bundle header at add time (the T735 dropped-edge
   incident is the negative precedent — the fix is affirmative: one parser, used by add,
   suggest, and dispatch alike).
6. **Gate diet** — every dispatch gate re-justified against process doctrine; display
   preferences (the 40-char title refusal) demote to warnings; the three cooldown mechanisms
   (heal, dispatch, window) merge into one visible state machine.
7. **Startup-prose diet** — `managent orient`'s ≤150-line preamble is the only boilerplate,
   injected at dispatch; briefs carry task-specific content only.
8. **Provider seam** — providers as data; acceptance: onboarding a new model costs one
   registry entry (T732's findings record today's baseline: the ox-alpha onboarding cost).

## Acceptance for the sprint

- `tools/orcha-acceptance.sh` green three consecutive days with zero operator process-relays
  (the existing L1 bar), AND
- a demonstrated one-edit model onboarding (measured against the T732 baseline), AND
- the dashboard shows, in one pane: keeper liveness, every pause with owner/reason/age/expiry,
  per-family window budget and appetite, benched models.

## Feedstock rows held for this sprint

T712, T713 (arbiter); T578 (S04 orchestrator-retirement — this sprint absorbs its reconciler
scope, operator-ratified direction); T709 (dispatch-verify reconcile) if not closed sooner.

## Explicitly out of scope

claimlint and the science suite (separate ledger tooling); the history squash (T535, its own
spec-first console); race machinery beyond what the policy file touches.
