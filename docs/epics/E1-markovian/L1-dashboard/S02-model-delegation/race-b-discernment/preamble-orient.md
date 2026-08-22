=== managent orient — generated worker preamble (≤150 lines) ===
composed 2026-08-22T12:00:50Z from tasks.json · git · claimlint · floor
self: built from 5036557-dirty (zig 0.16.0)

## principles (extracted from AGENTS.md / DELEGATEE.md / sprint.md / DIRECTION.md)
1. Commit → deploy → smoke for every mutating commit, before anything else touches the store.
2. One writer per engine file; declare via kanban holds= and clear when done.
3. The claimlint floor never rises; a regression moves it down or is reverted.
4. Instruments over documents — a checker ships a known-good it passes and a known-bad it catches.
5. Both findings deliverables: findings/<id>-<slug>.json (schema) + findings/<id>-context.json (dump).
6. Canonical model labels only — one spelling per model (src/managent/main.zig canonical_models).
7. Never ask a model to introspect its own kind; workers are task IDs, seats are roles.
8. Mutation is serial per held file; analysis is parallel and unlimited.

## gates (live)
pre-commit hook: INSTALLED (core.hooksPath = tools/hooks)
claimlint: C1a=0 C1b=0 C2=11 C6=0 calibration=PASS
floor: C1a=0 C1b=0 C2=11 C6=0

## kanban (live)
in progress (4):
  T568  (deepseek-v4-pro/T568) [stalled] — untracked/T568-orcha-successor-seat.md
  T584  (claude-opus-5/T584) [stalled] — untracked/T584-s04-spec-audit.md
  T587  (deepseek-v4-pro/T587) [UNKNOWN] — untracked/T587-store-write-utf8.md
  T591  (deepseek-v4-flash/T591) [UNKNOWN] — untracked/T591-watchfleet-times.md
dispatchable (18):
  --bundle [set S] — untracked/T430-phase2-audit.md
  DARGUS [set H] — untracked/DARGUS-run-argus-once.md
  DCLAIM [set H] — untracked/DCLAIM-verify-one-unbacked-claim.md
  DRPLAY [set H] — untracked/DRPLAY-random-game-falsification.md
  STANDING-ABSORB [set H] — docs/infra/dispatch/STANDING-ABSORB.md
  STANDING-CLEANUP [set H] — docs/infra/dispatch/STANDING-CLEANUP.md
  T511 [set A] — untracked/T511-keeper-arg-single-instance.md
  T525 [set A] — untracked/T525-epoch-boundaries-aggregation.md
  T526 [set A] — untracked/T526-family-blinding-harness.md
  T527 [set A] — untracked/T527-t428-console-execution.md
  T529 [set A] — untracked/T529-grand-race-p0.md
  T530 [set A] — untracked/T530-mutation-gate-fixtures.md
  T531 [set A] — untracked/T531-t351-twosurfaces.md
  T533 [set A] — untracked/T533-STANDING-CLAIMVERIFY.md
  T544 [set A] — untracked/T544-model-attribution-backfill.md
  T578 [set A] — untracked/T578-orchestrator-retirement.md
  T583 [set A] — untracked/T583-startup-surfaces.md
  T592 [set A] — untracked/T592-tools-census.md
blocked (1):
  T535 [set A] needs T536 T539 T541 T544 T545 T547 T548 — untracked/T535-stage4-clean-story-spec.md

## fresh activity (git log --oneline -10)
  446e226 T590: audit S04 reconciler spec — PASS-WITH-FINDINGS (8 findings)
  ecbb0a7 T586: fix pi-worker nonce-stall (json stream + startup liveness)
  e1799dc T588: race A audit of S04 reconciler spec — PASS-WITH-FINDINGS (2 findings)
  6407d1a T589: S04 spec audit (Race A) — PASS-WITH-FINDINGS, 8 findings
  c47d581 kanban-store: recover store + dispatch T587-T591 (race A + fixes)
  09d8990 commit ladder-races-2026-08-22 (operator-funded races A-D)
  9690b62 T522: record store-repair + close resolution in findings
  c9ecb8b T522: record close-blocked-by-store-corruption in findings
  ee28e62 T522: impression-or-waiver gate at close (G6/D-b)
  5036557 watch-fleet: concern labels (console vs orphaned) + tag override file

## handover head (by reference — not copied here)
