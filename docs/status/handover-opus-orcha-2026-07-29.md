Outgoing: `Opus/Orcha` (Opus 5, `claude-opus-5[1m]`) · Date: 2026-07-29 ~23:55 CEST
Incoming: `DSPro/Orcha` · Protocol: `docs/infra/roles/ORCHESTRATOR.md` §"Exactly one, ever"

# Handover — Opus/Orcha → DSPro/Orcha

I stand down as Orchestrator on your acknowledgement. Read `ORCHESTRATOR.md` (49
lines) first — it is a prescription, not a history — then `STATE.md`, then this.

## Why the seat changes hands

Conditions I set in `orcha-handover-conditions.md`: (1) `MANAGENT-DERIVE-STATUS`
— **done, and it proved itself within a minute** (`needs --add` re-gated `EXP-4`
automatically, the defect that bit twice); (2) `ORCHA-AUTOMATION` — **not done**;
(3) a named-second-seat rule for promotions — **enacted below, as a rule**;
(4) `WORKER-CHANNEL` — desirable, not blocking.

I am not treating (2) as blocking any more, because the evidence overtook it.
**`DSPro/Dabir` already performed cadence step 2 unprompted** in channel msg 044
§4: it scanned the kanban against reality, found that two completed tasks still
read `dispatchable`, and produced the exact fix commands. That is the test I
proposed — *fix a dirty state without being told* — passed as Dabir. Dispatch
`ORCHA-AUTOMATION` early; run the cadence by hand until it lands.

The other half of the reason is in `orcha-handover-conditions.md` and I will not
soften it: an Opus seat held Orcha today and **the two errors that reached the
durable tree were both the Orchestrator's** — accepting half a verification, and
seeing `pin_L=142` vs `pin_H=0` in every run without reading it. Today's evidence
does not show the expensive seat was better at what this seat is for.

## Seat allocation — my recommendation

**Fill both court seats with separate DSPro instances.** The human's stated
preference is to talk to **Dabir**, who relays to **Orcha**; if one instance holds
both, he becomes the relay again, which is the thing he complained about. The
identity scheme handles this — `DSPro/Orcha` and `DSPro/Dabir` are distinct
identifiers.

Keep **Opus or Fable on call as *Auditor*, dispatched to tasks** — never as a
second Orchestrator. The seat that found σ-in-arrival should be sent *to a task*,
so its output gets independently checked instead of promoted by its own author.

## The one rule I am enacting on the way out

**No claim-status change without naming the independent seat that agreed, in the
commit message.** This is the guard that would have caught the only Orchestrator
error today that reached the durable tree. It is already in `ORCHA-AUTOMATION` §6
to be enforced by `audit`; until then it is a rule you keep by hand. It cost me
one wrong promotion to learn.

## State of the world

**Tree clean, 98 commits, claimlint 254/254 rows parse, calibration PASS, C1a
orphans 14** (expected — the C1 promotion orphaned `GLOBAL.H1`, `QA-011`,
`GLOBAL.ONEMISMATCH`; `CLAIMS-SPLIT-CONJUNCTS` is registered to split them, and
they must be **split, not marked false**).

### The keystone, as it actually stands

- **`fixpoint_kernel` had inverted White-branch guards** — all 878 White-to-move
  non-terminals pinned at (−6,+6), `median = 0` by construction. **VERIFIED by two
  seats** (`Kimi-k3` found it, `Kimi-k2.7` reproduced from scratch in Python).
  Corrected census `2232/322/34/34` replaces `948/1532/142/0`.
- **C1 is FALSIFIED at 3×2 for history-conditioned semantics.** Witness
  `(178,0,6,0)` = `[B,W,B,␣,W,␣]`, Black to move, `passes=0`, no ko: arrival A (20
  moves) → **−3**, arrival B (24 moves) → **−6**, corrected fixpoint `L=H=−6`.
- **Fresh-start / shortest-arrival semantics survives** everything checked
  (`396/396`). This is what the shipped table holds. **The scope is the result** —
  never report C1's failure without naming the semantics.
- **`QA023-C1-WITNESS` is the gate.** Dispatched to DSPro, *not* K3: the dump must
  not come from the harness that produced the finding, and the brief requires the
  ~22-node tree produced twice by independent paths, agreeing node for node.
  **`EXP-4` needs it.** If the witness does not hold up, `QA-023`, `ADR-0019`'s
  fork and `EXP-4` all move.

### Awaiting the human — do not decide these for him

- **`ADR-0020`: the fork.** Truncation is not Markovian on the tuple and enlarging
  the tuple is foreclosed by measurement. Options: (a) history-dependent solve →
  PSK's intractability; (b) adopt fresh-start semantics as the rule; (c) ship (b)
  plus the measured gap = the `K2` deliverable. My analysis:
  `docs/epistemic/is-real-game-markovian.md`. **He owns ruleset adjudication.**
- **`knowledge-ladder.md` is PROPOSED, not adjudicated.** If he ratifies it, the
  `rung` + `rule` columns would make the `4x4.ANCHOR` class of error
  machine-checkable instead of prose-only.

### The highest-value unblocked experiment

**`S2` / `EXP-8` — the measured value gap in real play.** Legality divergence is
measured at ≈0 (EXP-1, 1,015,076 candidate moves). **Value divergence in real play
has never been measured**, and it decides whether the fresh-start deliverable is
*practically* correct while theoretically wrong. Cheaper than any 4×4 build. It is
blocked behind the new-rule tables today; unblocking it is worth more than
unblocking EXP-4.

## Traps that have each cost a day

- **`bin/managent` goes stale.** `cp zig-out/bin/managent bin/managent` after every
  rebuild. It was stale tonight.
- **managent prints everything to stderr** — 764 `std.debug.print` calls
  project-wide, zero stdout writes outside `gtp.zig`. `status | grep` **silently**
  returns nothing. Use `2>&1` until `ORCHA-AUTOMATION` item 0 lands.
- **`timeout(1)` does not exist on macOS.** A run bounded with it is unbounded and
  its empty output is not a result.
- **Never unfiltered `zig test src/qa023_probe.zig`** — it collects the brute's
  exponential tests; 301 min CPU, one killed console. Use `--test-filter`.
- **`budget-exhausted: 0` is a red flag**, not a green one, on an exponential search.
- **Refresh `STATE.md` in the same commit as any kanban change.** I read "when there
  is news" as discretionary and let the anchor go 3 hours stale; the human caught it
  by asking whether we could survive a crash.

## What I would do first, in order

1. Acknowledge in the channel; the board is yours on that post.
2. `ORCHA-AUTOMATION` — item 0 (stdout) first; it blocks the rest.
3. `QA023-C1-WITNESS` result → absorb, and if it holds, `ADR-0020` goes to the human.
4. `CLAIMS-SPLIT-CONJUNCTS` — 14 orphans, and `GLOBAL.H1` is the pivot.
5. `STREAM-DISCIPLINE`, `INDEX-RETRIEVAL`, `NARRATIVE-LAYER` — none needs a
   milestone, all raise the floor, and the last two are what the human keeps asking
   for: retrievable knowledge and a through-line told once.

I remain available as **Auditor on call**, dispatched to a task, at the human's
choice. I will not touch the kanban again.

— `Opus/Orcha`, standing down
