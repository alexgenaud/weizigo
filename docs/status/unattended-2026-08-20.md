# Unattended operation — 2026-08-20 15:40 local onward

The operator left the desk for one to two hours and asked whether the fleet could
keep working without prompting the Orchestrator. This file records what was set up,
what is deliberately NOT allowed to run, and where to look on return.

## The autonomous engine

**The fleet keeper is the self-perpetuating process** — it reads the queue every 20 s
and dispatches up to the cap without any Orchestrator turn. Restarted 15:39 local,
single instance, `FLEET_CAP=3`, `FLEET_INTERVAL=20`. Its durable Ollama denylist
(D036) is now the built-in default, so it cannot walk back into the 429 wall.

**Why the cap is 3, not 5.** The cap counts *workers, not resource weight*
(inventory D2/D12). A full-suite row costs ~2 GB, so a cap of 5 was documented-safe
and effectively unsafe: earlier today three concurrent `zig build test` runs drove
the host below the runner's 6144 MB floor and **12 workers were culled with rc=124**,
each recorded as a model failure. 3 is a stopgap, not a fix.

**A bug fixed at restart that had been hiding real idleness:** the previous keeper
(pid 47334) was refusing *every* dispatch with "REFUSED — you are at the delegation
cap (depth 3 of 3)" because it inherited `WEIZIGO_AGENT_DEPTH` from the shell that
started it. It looked healthy — one instance, logging every iteration — while
dispatching nothing. Filed as inventory item 11.

## Event-driven wake-ups

A persistent monitor watches for the things that need a decision rather than a
schedule: row closes, `KILL: host memory pressure` lines, provider-refusal
signatures (429 / rate limit / usage limit), free memory below 9 GB (the runner culls
at 6 GB), and the fleet sitting idle for three checks while work is queued. Routine
dispatch needs no wake-up; the keeper handles it.

## Deliberately NOT allowed to run unattended

| row | why it is gated |
|---|---|
| `T535` | Stage-4 "clean story" — the history cleanup and squash spec. A standing directive says queued-not-dispatched, and specifying a history rewrite while the store is *provably* corrupting (`T545`) is out of order regardless. Gated behind `T545` + `T541`. |
| `T511` | Rewrites `tools/fleet-keeper.sh` — **the file the running keeper is executing.** `bash` reads a script incrementally, so a mid-run rewrite can make the keeper execute a partial file. Now declares that hold so the one-writer invariant serialises it, and gated behind `T545`. |
| `T541` | The quiet suite-truth re-run requires a **drained** fleet, which the keeper cannot guarantee. Gated behind `T545` + `T542`; run it deliberately, when the fleet is empty. |

## Live at handoff

Keeper cap 3, all three slots full: `T545` (three unlocked store writers — the P0,
and several other defects may be downstream of it), `T542` (bakeoff race gates G1–G4,
the critical path to the grand race), `T543` (race official for the seven sealed
aspect packets). Fifteen further rows queued with bundles, including Claude lanes
seeded by hand — `T527`/`T529`/`T531` to opus and fable, `T533` to sonnet — because
the keeper's own model picker has no Claude labels (sprint item 2), so it would never
choose them on its own.

Memory 32 GB free, no orphaned `zig` processes, claimlint at the floor
(C1a=0 C1b=0 C2=11 C6=0 C7=0), calibration PASS.

## Where to look on return

1. `docs/status/tooling-defects-2026-08-20.md` — the durable defect inventory, section
   D is the unowned intake for the calm cleanup sprint.
2. `sh tools/orcha-acceptance.sh` — now fails honestly (`T537`); AC5 was the open
   failure at handoff, driven by due duty chunks.
3. `docs/infra/model-perf.md` — read the **DO NOT SCORE** annotations first. Two
   cohorts must be excluded from any per-model rate: the ~80 Ollama 429 refusals, and
   today's 12 rc=124 host-memory-pressure culls (which include opus ×2 and fable ×1,
   three of the four lanes in the critical comparison).
4. `git log --oneline` — every finding of the day is in a commit message with its
   evidence and denominators.

## Standing caution for whoever reads this next

The day's recurring pattern is **the measurement apparatus quietly producing the
answer it assumed**. Before believing any number here, check what the instrument
that produced it could not have reported.

## Owed — carried forward (added 16:25 local, as the unattended run progressed)

**Closed this hour:** `T542` (all four race gates green, 36/36 controls, wired into
`zig build test`), `T545` (five store writers locked — two more than the seat's own
survey found; 5-arm concurrency regression green with the pre-fix RED reproduced),
`T543` (aspect races round 1 — 27/49 captured, zero tokens, annotated).

**`T541` — the quiet suite-truth re-run — is OWED and must be run deliberately.**
It closed `blocked` at 16:22 having correctly refused to run: *"Precondition failed:
fleet busy (in_progress=3 …); suite NOT run, manifest untouched."* That is the right
outcome, not a failure — the brief's precondition worked. But the work still needs
doing, and it needs a **drained fleet**: set the keeper cooldown
(`touch untracked/fleet-keeper.cooldown`), let the running rows finish, confirm
`in_progress(0)` and no `bin/subagent` processes, reopen the row, run it alone, then
lift the cooldown. Do **not** let the keeper pick it up again — it has no notion of
preconditions (inventory item 14), which is why it dispatched it into a busy fleet
in the first place.

**`T546` — aspect races round 2 — unblocks the moment `T521` closes** (`T542` is
already done). Its first instruction is to prove token capture on ONE lane before
firing the other 25, so round 1's zero-token outcome cannot repeat. It re-runs only
the 26 owed lane-packet combinations; round 1's 27 good results are not re-spent.

**`T511` and `T535` are gated behind `T546` / `T541` on purpose** — `T511` rewrites
the keeper script while the keeper is executing it, and `T535` is the Stage-4 history
squash spec under a standing queued-not-dispatched directive. Both gates are honest
"not yet" constraints wearing a `needs` edge, which is itself inventory item 14.

**Two seat errors to note against the record:** a directive and a commit message were
each mangled by shell backticks (the directive was resent clean; the commit message
has a two-word gap and was left, since amending a pushed commit would rewrite the
archive branch's history for cosmetics — the full text is in the inventory). And the
seat's survey of unlocked store writers found three of five; `T545` found the rest.
