# Handover — orchestration oversight seat, 2026-08-24

**From:** `claude-opus-5`/T771 (context heavy) · **To:** a fresh `claude-opus-5` orchestrator seat.
**Operator instruction:** divide past, present and future work; the outgoing seat keeps what
benefits from its context, hands over what does not or what transfers cheaply.

---

## 1. The division, and the interaction model

**Recommendation, and the reason matters:** the incoming seat owns **the queue and all dispatch
from now on.** The outgoing seat dispatches **nothing further** — it only interprets four in-flight
race results and closes one task, then stands down.

Why not both active: two seats dispatching into one queue is exactly the *two doors, one gated*
defect this project spent 2026-08-23 measuring — five dispatch paths of which 159 of 364 executions
skipped the layer that adds the nonce and the token meter; two close paths of which the ungated one
lost the model on 9 tasks. **The one-writer doctrine applies to seats.** Judging is not dispatching,
so a split by *task list* cannot collide, whereas a split by *activity* would.

### Outgoing seat keeps (finite, then done)

| task | why its context does not transfer cheaply |
|---|---|
| **T832** — judge the diff race (T826/T827/T828/T829/T831) | knows why the 172 arms predate the race, why disqualification is mechanical, and that the T818 case is the concrete test |
| **T843 / T844** — judge the rate race (T838–T842) | wrote the retroactive-visual instruction and the "name the hinge" requirement; the operator's later reading must apply without a re-grade |
| **T819** — three-way corpus agreement (T817/T818/T820) | knows T817's brief deliberately differs (seeded from the old classifier) while T818/T820 are byte-identical, so the comparison means two different things |
| **T818** — close it | complete but unclosed; blocked on T835 clearing C7/C11 |
| **T822** — arm-or-delete on the S06 spec | knows the armed-count history: 15/31 → claimed 22/31 → independently counted 12/37 |

### Incoming seat owns (everything else, including all new specification)

- **The `main.zig` chain:** `T834 → T767 → T768 → T775 → T786 → T798 → T815 → T816 → T833`. One
  writer, strictly serial. Each brief is self-carrying.
- **S06 consolidation:** shape RATIFIED by the operator. Pass 2 (arbiter) landed as T821. Passes
  **1, 3, 4, 5, 6 need minting and dispatching** — `S06-orchestration-refactor/STATUS.md` is the
  live state, `spec.md` is rev 3. **Operator ruling: interleave ordinary unrelated work through the
  changed mechanism between passes; a pass is complete only when that work closes cleanly, not when
  its own arms are green.**
- **The epistemic arc:** T836 (board proof census, in flight) → T837 (C3's 42 unbacked proofs).
  T814 already took C2 from 13 to **0**.
- **S09 module contracts:** T790's spec exists; nothing built.
- **Loose dispatchable work:** T787, T750, T751, T753, T712, T715, T735, T529, T535, T709, T764.
- **`docs/status/OPEN.md`** — 4 decisions owed to the operator, 8 known issues, 5 undispatched
  ideas. **Maintaining it is the seat's job.** An item leaves only when dispatched, decided or
  killed — never because it went quiet.

---

## 2. First actions for the incoming seat

1. **`bin/managent reap` before believing any status.** On 2026-08-23 sixteen tasks were reported in
   flight when **zero** were alive. A claimed task is not a running task.
2. **Watch the keeper's first auto-dispatches.** `tools/fleet-keeper.sh` (pid 99956, up 3d) was
   paused for **four days** by a zero-byte `untracked/fleet-keeper.cooldown` dated 2026-08-20; the
   outgoing seat removed it at 2026-08-24T07:04Z. It is capped at **1 concurrent task**, so it does
   nothing until the fleet drains, then dispatches one at a time. Its picker is now
   `method=solo-least-data` (T772 removed cost from selection and added the methodology §5 quality
   gate) — verify the first two or three picks look sane rather than assuming.
3. **`src/managent/main.zig` is mid-edit** by T834. Nothing else may touch it.
4. **A new citation to `untracked/` or `/tmp/` fails the commit gate** (T814's C10-NEW ratchet).
   Three consoles hit it on day one, including the outgoing seat, whose own OPEN register cited a
   volatile path. Cite committed artifacts.

## 3. Facts that cost real time to learn

- **Titles over 40 characters are refused at dispatch.** It will bite twice before you believe it.
- **`managent done` takes `--status`, not `--verdict`**; an unrecognized flag is silently ignored
  and the verdict defaults to `pass`. T775 fixes it. The outgoing seat's own close recorded `pass`
  when it typed `pass-with-findings`.
- **Appetite gates only `managent assign`.** `bin/dispatch <task> <model>` never consults it, so
  glm / kimi / minimax were usable the whole time the family read OFF. The outgoing seat called
  this structural and was wrong; the correction is recorded here because it wasted the operator's
  attention.
- **Racing writes works via patches.** Entrants write `untracked/<race>/<id>.patch` against a
  pinned commit; a judge applies each in isolation and runs arms that predate the race. Six models
  edited one file with zero conflicts. Operator's idea; it makes `implement` raceable.
- **A pi console looks dead while healthy** — stdout is buffered to completion. The live signal is
  the session transcript under `untracked/tokens/sessions/`. qwen sat at 2,951 log bytes for 33
  minutes with a 573 KB transcript and 25 tool calls.
- **A consolidation pass editing a live file breaks the fleet while it works** — T821's arbeiter
  edit left a `NameError` in `tools/runner` and 13 dispatches died inside a 7-second window. Passes
  must land atomically or work on a copy.

## 4. Standing operator rulings that bind the seat

`docs/infra/discuss.md` governs all operator contact: **recap first in human words, exactly one
decision per ask, then stop.** He tracks nothing between messages; a reply he answers with "I do not
understand" is the agent's protocol failure, not his memory's.

Bring him only decisions he alone can make — intent, taste, appetite, irreversible direction.
Everything else: decide on evidence, record it, act, report the outcome. He has said he will likely
agree with a well-argued recommendation and does not want to micromanage.

Sharpest recurring lesson from 2026-08-23, in his words: *"too much energy monitoring rather than
just fixing the root problems and causes"*, and *"I do not think we should build jacuzzies on the
roof if the basement is unstable."*

## 5. Where the measurement stands

- **Unit tests:** 300+ arms across five modules, 0.172 s. Before 2026-08-23 there were **zero** for
  any Python or shell module.
- **Round-trip tier:** `tests/roundtrip/`, 10 arms, 70.6 s, on the `--test-worker` seam.
- **Suite:** re-baselined — 112/122 steps, 1344/1348 tests, 906 s. `tools/smoke.sh` is 1 s.
- **Ledger:** 24 rows across 72 cells; **59 empty**; 9 of 13 filled are `audit`. Nothing writes it
  automatically — that is issue B1 in OPEN.md and the deepest measurement gap remaining.
- **RAM floor deleted** — 16 of 20 recorded kills were futile, 0 of 20 both necessary and effective.

## 6. Handover discipline

The outgoing seat will **not** dispatch after this document is committed. If it finds something
urgent, it records it in `OPEN.md` and says so in its final report rather than acting. When its five
tasks close, it stands down and the incoming seat owns everything.
