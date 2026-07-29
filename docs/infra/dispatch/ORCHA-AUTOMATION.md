<!--managent set=W holds=src/managent/main.zig needs=MANAGENT-DERIVE-STATUS-->
# ORCHA-AUTOMATION — make the Orchestrator role cheap to run: sync, standing-tier auto-registration, attribution enforcement

**Opened by:** the human, 2026-07-29: *"I feel that a reasoning-intensive model as Orchestrator is too clever (and expensive) for the Orcha role. But I am not confident that the Orcha role is sufficiently defined, streamlined, automated and supported by managent to be managed by a lesser agent."* This task closes that gap. **The goal is that a small model can run the Orchestrator correctly by executing commands, not by exercising judgement.**

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

## 0. FIRST — managent prints everything to stderr, so none of it can be piped

**All 132 output calls in `src/managent/main.zig` are `std.debug.print`, which in Zig writes to stderr unconditionally. There are zero writes to stdout.** Measured: `managent status 2>/dev/null` emits **0** lines; `2>&1 1>/dev/null` emits **45**.

This blocks everything else in this brief. `audit`, `sync` and `liveness` are only useful if a script can read them, and a pipeline like `managent audit | grep -q REJECTED` **silently succeeds** today — the data bypasses the pipe, the grep matches nothing, and the exit code says all is well. The human hit this from the command line; it has presumably been silently defeating every agent that tried to filter kanban output, and it went unnoticed because habitual `2>&1` masks it.

**Fix with the conventional split, before adding commands:**

- **stdout — the data.** `status`, `show`, `msgs`, `inbox`, `liveness`, `whoami`: anything a caller might parse, filter, or redirect to a file.
- **stderr — everything else.** Warnings, errors, `REJECTED: holds conflict …`, `warning: already in progress`, progress chatter.

Then a caller can do `managent status | grep 2B` and get the answer, or `managent audit >/dev/null` and still see the complaints. **Add a regression check:** `status 2>/dev/null` must be non-empty and `status 1>/dev/null` must be silent on a clean run. That check is one line and it is the reason this defect survived — nothing asserted which stream the data was on.

Consider `--json` on `status` and `audit` while you are in there; deterministic machine output is what makes the rest of the automation composable, and it is cheap once the streams are split.

## 6. Replace prescriptions with commands wherever a rule can become a check

The role files state rules an agent must remember. **Every rule that can be a command should become one** — a remembered rule is optional, a non-zero exit is not. Working list, from `ORCHESTRATOR.md` §Prescriptions:

| prescription today | command that would retire it |
|---|---|
| "commit before purge" | `purge` refuses a task whose deliverables are not in `git ls-files` |
| "protect untracked in-flight source" | `audit` lists untracked `src/*.zig` held by an `in_progress` task |
| "all ad-hoc builds through `tools/runner`" | `audit` warns when a build artefact is newer than its source with no runner log |
| "rebuilt managent? `cp` it" | `managent` warns when `zig-out/bin/managent` is newer than `bin/managent` |
| "register the standing tier unprompted" | `standing` (§4) |
| "read the channel, write when there is news" | `sync` (§1) |
| "verify, don't trust" | `done` warns when a load-bearing claim's status changed with only one seat's evidence cited |
| "attribute the worker" | `done` refuses an unset `agent` (§3) |
| **"verify, don't trust" — the seat's highest-stakes judgement** | **a claim-status change must name the independent seat that agreed.** `audit` flags any `CLAIMS.md` status edit in the working tree whose commit message cites no second task id. This is the guard that would have caught the only Orchestrator error today that reached the durable tree. |
| **"absorb what workers report"** | **`audit` verifies reported edits exist.** Given a deliverable claiming "banner placed on X", check X actually changed. Fast-model reporting defects (a banner reported as placed but never written, a stale count quoted as current) are cheap to catch mechanically and expensive to catch by reading. |

Implement the ones that are cheap and unambiguous; **for each one you skip, say why** — an un-automatable rule is a real category and worth naming. Then **delete every prescription the commands now enforce** from `ORCHESTRATOR.md` and cite the command instead. The role file should shrink as a result of this task; if it does not, the automation is not carrying its weight.

## Acceptance

- Each command demonstrated against the live `tasks.json`, with output shown.
- `managent audit` finds the discrepancies that actually occurred on 2026-07-29: 2B-3-AUDIT and EVIDENCE-INTEGRITY completed without ever being claimed; 2B-6 claimed after being gated; EXP-4 dispatchable against a falsified premise; ADR0006-FALSIFY completed with `agent` unset. **Use those five as the calibration set** — a version of `audit` that misses them is not done.
- `sync` demonstrated returning non-zero when a write is owed.
- **Rebuild discipline:** `zig build install` then `cp zig-out/bin/managent bin/managent`, or the binary is stale.
- Update `docs/infra/managent/spec.md` and add one line per command to `ORCHESTRATOR.md`'s cadence section pointing at the command that performs each step.

## Deliverable

`src/managent/main.zig`, `bin/managent` refreshed, `spec.md` updated. **Holds `src/managent/main.zig`**; depends on `MANAGENT-DERIVE-STATUS` (derived status is a precondition for `audit`'s gating check).

**Read first:** `docs/infra/roles/ORCHESTRATOR.md` §"The cadence" (the spec this automates), `docs/infra/managent/SPEC-msgbus.md`, channel msg 035 §3, `docs/infra/managent/spec.md`.
