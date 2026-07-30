# Handover — GLM (Advisor), 2026-07-28 (context full)

**Read first on resume:** `untracked/msg/milestone-01-ko-reframe/STATE.md` (crash
anchor), then `bin/managent status` (the agreed kanban), then this file.

## Role
**GLM = Advisor.** Owns project machinery: `bin/managent` kanban (single dispatch
registry), commits, no stale docs, protocol, model-perf ledger; synthesises
Opus's technical direction for the user. **Opus = Overseer** — grand overview,
epistemic tree, adversarial review of load-bearing proofs, claim-semantics
rulings; does NOT execute mechanical work. **User** — goals, ruleset
adjudication, ADR ownership, dispatches only from `bin/managent` `dispatchable`.
**Fable** — hardest reasoning, documents over implementation (D-7). **Minimax**
— measurement/census/tooling (reassigned, not retired). **Kimi/lesser** —
bookkeeping, harnesses, cleanup.

## The milestone
`untracked/msg/milestone-01-ko-reframe/` — decide whether weizigo can be exactly
solved under a tractable traditional ruleset, and which. Comms: `STATE.md`
(anchor, overwrite), `NNN-<from>-to-<to>.md` (append-only), `DECISIONS.md`
(rulings + promotion targets). **Deletion gate:** promote every DECISIONS entry
to `docs/` before deleting the dir (git-ignored; QA-022 lesson).

## managent kanban (the agreed state; `bin/managent status`)
- **in-progress:** `EXP-2` (agent **Fable5**) — §4.3 trichotomy repair (Part A
  proof). Brief `docs/infra/dispatch/EXP-2A-trichotomy.md` (routing → `004-opus-to-pi`
  + `005` + `EXP-2.md` Part A). Opus reviews adversarially.
- **dispatchable:** `EXP-2B` (Minimax, corrected 3×2 probe, holds `src/qa023_probe.zig`),
  `EXP-8` (PSK-divergence harness, holds `src/psk_divergence.zig`), `EXP-9` (H5(a)
  play-time mitigation, holds `src/gtp.zig`), `EXP-10` (QA-018 ADR refutation,
  Fable 2nd, holds `docs/decisions/`).
- **blocked:** `EXP-4←EXP-2,EXP-2B`; `EXP-5←EXP-4`; `EXP-6←EXP-5`; `EXP-7←EXP-6`;
  `QA-018-RULING←EXP-10` (a **human** goban item — the user's ruling).
- **done:** B34–B45, EXP-3.
- **sets are PHASES not lanes (Opus 009)** — everything set A; concurrency gated
  by `holds`, not set. All 4 dispatchable can run at once (no shared holds).

## The core technical state
- **Engine is optimal under no stated rule.** The chaining diagnosis (Opus): `Session.choose`
  is one-ply minimax over V0 — sound only where the Bellman identity holds (L==H,
  0 violations at every size); in L<H it compares incommensurable quantities →
  32-pt collapse. C4+unchainability, not C2. Player not fresh-start-perfect.
- **EXP-2 verdict (004-opus-to-pi): UNRESOLVED, one wrong theorem.** §4.3's
  `L<H⇒V=T` false (3 orderings, 2 unargued); the "one-line post-processing, no
  engine retraining" convenience rests on the broken branch → re-cost needed.
  QA-023 stays CLAIMED; EXP-4..7 held.
- **EXP-3 DONE, GO:** reachable `(board,side,ko)` dense at 4×4 = 177 MB (0.69×
  current) — simple-ko table buildable, dense addressing works (retires the
  "augmented state breaks colex" prediction).
- **QA-018 ruling (D-5, Opus):** ADR-0010 "brackets hold under ANY arrival
  history" refuted as stated → F2 orphaned. EXP-10 (Fable) attempts to refute;
  user rules (Horn A: F2 orphaned/brackets-off, or Horn B: search-path exempt/F2
  stands). Blocks whether EXP-6 needs a brackets-off build.
- **Epistemic-tree crisis (my remit):** `bin/weizigo-claimlint` — 10 orphans, 12
  dangling evidence, **79/79 PROVEN claims fail "evidence in git"** (T13's probe
  source deleted). Rule enforced: nothing new PROVEN without git-committed evidence.

## The user's directive this session (the thing to act on next)
**GLM↔Opus communication is broken** (relay-based, collisions, stale pointers).
The user demands: managent becomes the **consensus + human-action surface** —
the human reads `bin/managent` to see agreed state, roadmap, and what he
MUST/CAN do; no more relaying. I proposed to Opus (`010-glm-to-opus.md`):
(1) one-writer protocol via a managent `proposals` log (no unilateral
registration); (2) a `human-actions` view (human-owned dispatchable items =
"rule now"); (3) a `roadmap` tree print; (4) msg channel kept only for
reasoning, not status. **Awaiting Opus agree/amend, then I implement in
`src/managent/main.zig`** (mechanism, mine).

## Two defects to fix (Opus 009, mine if agreed)
1. `untracked/managent/tasks.json` git-ignored → kanban lost on clone (T13 class).
   Fix: move state to a tracked path (`docs/infra/managent/tasks.json`) + update
   `state_path` in `src/managent/main.zig`.
2. Spec/binary disagree on `context` (spec dropped it, binary keeps
   `--context`/`needs_context`). Reconcile either way (Opus's call).

## Open human rulings (not delegable)
1. **ADR numbering for EXP-10** — 0015 (ruling-of-record) vs new 0017 (Residue #5).
2. **QA-018 ruling** — Horn A vs Horn B (after EXP-10 lands).
3. **`mixed` claim inheritance** — unruled (D-2 splits 2 kinds; CLAIMS §5 has 3).

## In-flight (do not touch until their agents report)
- AGENTS.md + `docs/infra/{delegation,subagent,sprint,discuss}.md` + `docs/infra/agents/*`
  consolidation (203→89-line router).
- `docs/epistemic/CLAIMS.md`, `claimlint-2026-07-28.md`, `DECISIONS.md`, new
  `docs/decisions/` — D-1..D-7 promotion.
- `docs/infra/model-perf.md` — being written.
- EXP-2 (Fable5) — just dispatched.

## Key files
- Board: `bin/managent` (state `untracked/managent/tasks.json` — to be moved).
- Briefs: `docs/infra/dispatch/EXP-*.md` + `EXP-2A-trichotomy.md` + `QA-018-RULING.md`.
- Channel: `untracked/msg/milestone-01-ko-reframe/` (STATE/DECISIONS/messages 001–010).
- Evidence/claims: `docs/evidence/`, `docs/epistemic/CLAIMS.md`,
  `docs/epistemic/critique-2026-07-28.md`, `docs/epistemic/roadmap-2026-07-28.md`.

## Immediate next actions
1. Get Opus's reply to 010 (consensus proposal); if agree, implement managent
   `proposals` + `human-actions` + `roadmap` + move `tasks.json` to tracked.
2. As Fable5/EXP-2B/EXP-8/EXP-9/EXP-10 report: `managent done`, unblock
   dependents, report to user; promote evidence to git.
3. Resolve the 3 human rulings when they're ripe; keep DECISIONS promoted.