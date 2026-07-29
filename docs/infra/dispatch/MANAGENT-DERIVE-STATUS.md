<!--managent set=S holds=src/managent/main.zig-->
# MANAGENT-DERIVE-STATUS — a gated task stayed claimable; status must be derived from `needs`, not stored

**Opened by:** the human, 2026-07-29, reading `managent status` and asking whether two listed tasks could actually run in parallel. They could not. The board was wrong, and the Orchestrator had made it wrong an hour earlier.

## What happened

`2B-6` was `dispatchable` (its then-`needs` were all `done`). The Orchestrator ran `managent needs 2B-6 --add 2B-PROBE-FIX` to gate it behind a task that had just been registered — because `2B-6` is a *full auditor review* of results that had just been shown to be artefacts (`docs/evidence/QA-023/probe-defect-2026-07-29/README.md`).

The board printed the new `needs` edge and kept the status `dispatchable`. **A console then claimed it** — legitimately, from the board's point of view — and began auditing invalidated numbers.

## The defect

`status` is a **stored** field, not a derived one:

- `src/managent/main.zig:759-761` — `add` computes `needs_met` and stores `.dispatchable` or `.blocked`. **This is the only place `needs` is ever consulted to set status.**
- `cmdNeeds` (`--add` / `--rm`) mutates the `needs` list and **never re-evaluates status**. Adding a dependency to a `dispatchable` task therefore does not gate it; removing the last dependency from a `blocked` task does not release it.
- `reopen` (`:1056`) sets `.dispatchable` unconditionally, ignoring `needs` — so reopening a task with unmet dependencies produces the same lie.
- `done` (`:1015`) walks dependents and sets them `.dispatchable`, which is correct only because it checks that specific edge; it does not re-derive the rest.

The consequence is not cosmetic. `claim` only permits `.dispatchable` (`:857`), and `holdsConflict` (`:865`, `:693`) only compares against tasks that are `.in_progress`. A status field that can drift from the `needs` graph therefore weakens **both** gates the board exists to enforce: dependency ordering and the exclusive-write lock.

## The task

**Derive `dispatchable` vs `blocked` rather than storing it.** `in_progress`, `done` and `failed` are genuine stored facts — a claim happened, a completion happened. `dispatchable`/`blocked` are a *function of the needs graph* and must be computed wherever they are read.

1. Introduce a single predicate — `needsMet(state, id)` — and use it in **every** place that reads or transitions status: `status` display, `claim`, `next`, `dispatch`'s warning, `reopen`.
2. `claim` must **reject** a task whose `needs` are unmet, with the unmet ids named, regardless of the stored value. That is the gate that actually failed here.
3. `reopen` must land on `dispatchable` **or** `blocked` according to `needsMet`, not unconditionally on `dispatchable`.
4. `needs --add` / `--rm` must re-evaluate, and **print the resulting status** so the operator sees the gate take effect. The absence of that line is why the Orchestrator believed the gate had applied.
5. Decide and document what happens to an **already-`in_progress`** task that gains an unmet dependency. Do not silently un-claim a live console. Recommended: keep it `in_progress`, and print a **loud warning** on `status` — something like `2B-6 in progress but needs 2B-PROBE-FIX (not done)` — because that is precisely the state the project is in right now and the board should say so out loud.
6. **Migration:** existing `tasks.json` rows carry stored values that may already disagree with the graph. On load, re-derive and report any row that changed, so this defect's existing damage is visible once rather than silently corrected.

## Acceptance

- A test or demonstration for each of: `needs --add` gating a dispatchable task; `needs --rm` releasing a blocked one; `claim` refusing an unmet-needs task; `reopen` landing on `blocked` when appropriate; the in-progress-with-unmet-needs warning appearing.
- `bin/managent status` output for the **current** `tasks.json` before and after, with every row whose status changes listed.
- **Rebuild discipline:** `zig build install` writes `zig-out/bin/managent`; the project runs `bin/managent` (gitignored). **`cp zig-out/bin/managent bin/managent`** or the binary is stale — this has bitten a previous successor.

## Deliverable

`src/managent/main.zig` (modified), `bin/managent` refreshed, and a short note in `docs/infra/managent/spec.md` stating that `dispatchable`/`blocked` are derived and `in_progress`/`done`/`failed` are stored. **Holds `src/managent/main.zig`** — the board is the single source of truth for the queue; land it in one commit.

**Read first:** `docs/infra/managent/spec.md`, `src/managent/main.zig:693` (`holdsConflict`), `:759-761` (`add`), `:1015` (`done`), `:1056` (`reopen`), `:857-872` (`claim`).
