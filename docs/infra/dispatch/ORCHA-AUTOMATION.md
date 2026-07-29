<!--managent set=W holds=src/managent/main.zig needs=MANAGENT-DERIVE-STATUS-->
# ORCHA-AUTOMATION — make the Orchestrator role cheap to run: sync, standing-tier auto-registration, attribution enforcement

**Opened by:** the human, 2026-07-29: *"I feel that Opus 5/Orcha is too clever (and expensive) for the Orcha role. But I am not confident that the Orcha role is sufficiently defined, streamlined, automated and supported by managent to be managed by a lesser agent."* This task closes that gap. **The goal is that a small model can run the Orchestrator correctly by executing commands, not by exercising judgement.**

`docs/infra/roles/ORCHESTRATOR.md` §"The cadence" is the spec: seven steps, every turn. Today every one is manual and therefore skippable. Automate them.

## The task

**1. `managent sync <role>`** — already specified in `docs/infra/managent/SPEC-msgbus.md` plus the delta in channel msg 035 §3. Implement it:
- print unread messages addressed to `<role>` or to all (the inbox)
- print the last message `<role>` itself posted, and how many events (kanban changes, messages) have happened since
- **exit non-zero if that gap exceeds a threshold** — "you owe a write"

**2. `managent audit`** — one command that performs cadence step 2 and prints a fix list. Cross-check the kanban against reality and report each discrepancy as an imperative:
- a `done` task whose deliverable paths are not in `git ls-files` → *commit these*
- a task with a deliverable on disk but not `done` → *mark done*
- an `in_progress` task with no matching live process → *reopen*
- a `dispatchable` task with unmet `needs` → *gate it* (see `MANAGENT-DERIVE-STATUS`, which this depends on)
- a `done` task with `agent == null` → *attribute it*
Exit non-zero when the list is non-empty. **This is the single highest-value command in the task** — it turns "did the Orchestrator remember to check?" into a test.

**3. Attribution enforcement.** `managent done <id>` should **refuse** (or loudly warn) when `agent` is unset. Agents are expected to declare their own model in the result file; when one writes "not stated at dispatch", the gap must surface at completion, not weeks later in an empty ledger.

**4. Standing-tier auto-registration.** A `managent standing` command that registers the recurring holistic tasks when their trigger fires, so nobody has to remember them:
- a **holistic audit** when a milestone's shape changes
- a **cleanup/absorption** task when the tree has been dirty across two turns
- a **re-evidencing** task when `claimlint`'s C3 debt grows
- a **what-did-we-learn** consolidation after any falsification
Each registers from a template brief with the trigger recorded in the note. Do not invent new triggers; implement these four, and make adding a fifth a one-line change.

**5. A retrieval surface.** The human's standing complaint is that knowledge cannot be retrieved without sifting kludge. `managent show <id>` should print the task, its deliverables, their commit hashes, and the claims it touched. Consider `managent why <claim-id>` — which tasks produced the evidence behind a claim. Keep it deterministic; no summarisation by model.

## Acceptance

- Each command demonstrated against the live `tasks.json`, with output shown.
- `managent audit` finds the discrepancies that actually occurred on 2026-07-29: 2B-3-AUDIT and EVIDENCE-INTEGRITY completed without ever being claimed; 2B-6 claimed after being gated; EXP-4 dispatchable against a falsified premise; ADR0006-FALSIFY completed with `agent` unset. **Use those five as the calibration set** — a version of `audit` that misses them is not done.
- `sync` demonstrated returning non-zero when a write is owed.
- **Rebuild discipline:** `zig build install` then `cp zig-out/bin/managent bin/managent`, or the binary is stale.
- Update `docs/infra/managent/spec.md` and add one line per command to `ORCHESTRATOR.md`'s cadence section pointing at the command that performs each step.

## Deliverable

`src/managent/main.zig`, `bin/managent` refreshed, `spec.md` updated. **Holds `src/managent/main.zig`**; depends on `MANAGENT-DERIVE-STATUS` (derived status is a precondition for `audit`'s gating check).

**Read first:** `docs/infra/roles/ORCHESTRATOR.md` §"The cadence" (the spec this automates), `docs/infra/managent/SPEC-msgbus.md`, channel msg 035 §3, `docs/infra/managent/spec.md`.
