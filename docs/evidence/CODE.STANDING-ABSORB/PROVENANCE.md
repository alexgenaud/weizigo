# PROVENANCE — CODE.STANDING-ABSORB (T294, 2026-08-03)

Task: T294 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03

What this file proves, and how:

## Claim: CODE.STANDING-ABSORB — the absorption backlog is a standing trigger

`managent standing` now carries a fifth standing-tier trigger, `STANDING-ABSORB`,
which auto-registers an absorption kanban task when claimlint's C7
unabsorbed-findings count exceeds the threshold **5**.

- **The count is claimlint's own.** `cmdStanding` runs `bin/weizigo-claimlint`
  once per invocation (the same run the C3-debt trigger uses) and parses the
  `C7 unabsorbed findings: N` summary line — the same "read the summary, don't
  reimplement" doctrine the pre-commit hook applies to C1a/C1b/C2/C6
  (`tools/hooks/pre-commit`). There is exactly one implementation of the count.
- **The composition is surfaced.** The per-file breakdown aggregates claimlint's
  own `UNABSORBED … in <file>` detail lines and prints `per file: …` alongside
  the trigger, so a fired trigger decomposes before anyone triages (the
  2026-08-03 case: C7=21 was 10 genuine + 11 context dumps repeating their
  findings files — T290-context 9, T288-context 2).
- **Threshold 5, rationale in `src/managent/main.zig:4117`:** 0 is the
  permanently-red-gate failure (GRAND-AUDIT §1c); 1–4 is the in-flight noise
  band (a finished task's findings are legitimately unabsorbed until ratified);
  5 is a session-sized job (triage + reconcile + CLAIMS.md update + disposition)
  and fires with margin on the smallest fully decomposable genuine backlog
  observed (10, 2026-08-03) without firing on noise. The trigger is absolute
  (count > threshold), not change-based.
- **Trigger is `CODE.STANDING-ABSORB`-related source:** `src/managent/main.zig`
  (threshold constant at 4117; C7 parse at 4151; trigger evaluation at 4366);
  brief `docs/infra/dispatch/STANDING-ABSORB.md`; spec
  `docs/infra/managent/spec.md` §`managent standing`.

### Controls (both in `zig build test` via tools/regression-managent-standing.sh)

| control | fixture | observed | verdict |
|---|---|---|---|
| null | scratch repo, empty `findings/` → C7=0 ≤ 5 | `C7 unabsorbed: 0 (threshold 5) — at/below threshold, no trigger`; nothing registered in the scratch kanban | PASS |
| seeded | scratch repo + synthetic fixture `T294SEED-absorb.json` (6 claims, none in register; written into the scratch repo's `findings/` at test time by tools/regression-managent-standing.sh, never committed to the live repo) → C7=6 > 5 | trigger fires, names the count (`C7 unabsorbed: 6 (threshold 5)`), registers `STANDING-ABSORB` dispatchable, per-file line `T294SEED-absorb.json: 6` | PASS |

All fixtures synthetic, run in `/tmp/weizigo` — live kanban, live findings/,
live CLAIMS.md untouched (verified: no `managent standing` run in the live repo
as part of T294). Live-state observation, in sequence: at T294 start the live
repo measured C7=21 (the brief's 2026-08-03 case, decomposable as 10 genuine +
11 context dumps); during T294 the concurrent T293 worktree absorption
(uncommitted changes to `docs/epistemic/CLAIMS.md` + `findings/rejections.json`,
not T294's) brought the pre-T294 count to 0, and T294's own three proposed rows
now measure C7=3 — at/below the threshold, so a live `standing` run today does
not fire. The trigger fires only when the count exceeds 5; deciding what to do
with a fired trigger (or a row T294 proposed) is the Orchestrator's call per
the brief's note on the neighbouring triggers.

## Observations reported with the claim (also in findings/T294-standing.json)

- **CODE.STANDING-C3-DEAD:** the pre-existing `STANDING-REEVIDENCE` trigger
  cannot fire: `cmdStanding` searches claimlint output for the marker
  `"C3: "` (`src/managent/main.zig:4140`), but claimlint's summary prints
  `C3 PROVEN w/o committed evid. N` — no `C3: ` line exists in its output
  (verified by `grep -n "C3:"` over a full claimlint run, 2026-08-03), so
  `c3_debt` is always 0 and the change-based condition
  (`c3_debt > c3_prior and c3_prior > 0`) can never hold.
- **CODE.STANDING-STATE-FRAGILE:** the standing triggers' persisted was/now
  priors (`_standing` in tasks.json) survive only until the next kanban write:
  `parseStateJson` skips every `_`-prefixed key (`src/managent/main.zig:581`)
  and `writeState` re-serializes only task keys, so `persistStandingState`'s
  textual `_standing` insertion is dropped by any subsequent `add`/`claim`/
  `done`. Today's tasks.json carries no `_standing` despite the Orchestrator's
  fired-trigger report. STANDING-ABSORB is unaffected (absolute trigger).

Both reported; neither fixed — out of T294 scope, and the neighbouring triggers
are the Orchestrator's call (brief's note).
