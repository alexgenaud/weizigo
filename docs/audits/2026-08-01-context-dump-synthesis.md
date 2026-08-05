# Context-dump synthesis — 2026-08-01

```
Author: Opus/Orcha · Date: 2026-08-01 · HEAD at absorption: c46fc78
Sources: findings/T{205,207,211,213,214,215,216,217}-context*.json
Method: eight worker consoles were asked, before closing, for hypotheses
  ruled out, hazards noticed out of scope, uncertainty in their own
  deliverables, and where the briefs or tooling misled them.
```

The consoles' context is the only project asset not in git and it dies
silently. This is what came back. Ranked by what it changes, not by who
said it.

## P0 — the new acceptance machinery has a hole in exactly our failure mode

**T217, own-deliverable uncertainty.** `managent done`'s acceptance check
inspects `term.exited != 0`. Zig 0.16's `Child.Term` is a union — a command
killed by a **signal** carries `.signal`, not `.exited`, and reading
`.exited` on the wrong active field yields 0. **An acceptance command that
the runner SIGKILLs at a ceiling therefore passes.**

This is not hypothetical: the runner SIGKILLed T212 at a CPU ceiling today.
The mechanism built this afternoon to stop T192-class failures — a build
that succeeds while its deliverable is invalid — fails open in precisely the
scenario that motivated it. Registered **T221**, urgent.

Same task carries T217's second find: `parseDeliverablesFromBundle` scans
forward to `-->`, so **any key placed after `deliverables=` is swallowed into
the deliverable list**. The example in my own T217 brief did exactly that and
cost the worker a test redesign.

## P0 — evidence stdout files may be silently corrupt

**T215/T193, hazard 1.** `util.out()` uses `std.Io.Threaded`. On
`std.process.exit(1)` the I/O thread is never joined and stdout is only
partially flushed. Observed directly: redirecting with `>` produced
truncated output with characters missing mid-line (`sorted=true` →
`orted=true`); `2>&1 | tee` worked because both streams share a descriptor.

**Any tool that writes evidence and exits non-zero may have written corrupt
evidence** — and tools exit non-zero exactly when they find something, so the
corruption is biased toward our most interesting results. The existing
`docs/evidence/**/*.stdout` corpus needs an integrity pass, not just a code
fix. Registered **T222**.

## P1 — the M4a harness has its own private encoder

**T215, hazard 2.** `artifact2.zig:60` and `oracle_v2_accept.zig:121` both
define `encodeKeyByte`, with different signatures (`passes: u1` vs `u2`,
`terminal: u1` vs `bool`) and currently identical bit layouts. The type
divergence hides the duplication from reviewers, and **the compiler cannot
catch a future divergence** — the acceptance harness would validate an
artifact against an encoding the builder no longer uses.

The acceptance instrument sharing no code with the thing it accepts is
normally a *virtue* — independent re-implementation is the only thing that
has ever found a defect here (PROGRESS.md §9). So this is a judgement call,
not an obvious unification: **either** make the duplication deliberate and
documented as an independent check, **or** unify. It must not stay
accidental. Registered **T223**. Same task carries `lookup()`'s `passes: u2`
parameter that `@intCast`s to `u1` — panics on `passes ≥ 2` in safe builds,
silently truncates in fast builds, guarded today only by its sole caller.

## P1 — T193's result is weaker than its headline

**T215, own-deliverable uncertainty**, qualifying `CODE.WZO2-PASSBIT`:

- **A5 sampled ~1% of entries at a fixed stride of 97**, and the stride was
  never verified coprime to group sizes. A systematic error at a fixed
  position within groups could be missed entirely. A5 PASS is much weaker
  evidence than A3/A9 FAIL is strong.
- **The 16,314,978 A3 violation count was taken on trust**, not
  independently sampled. The first ten violations all had `ko=16`, which is
  consistent with the passes-bit diagnosis — but **nobody checked whether
  violations exist at `ko ≠ 16`**, which would mean a second root cause
  hiding behind the first.
- `consumer_load.zig`'s 2×2/3×2 paths were never swept, and `decodeKeyByte`
  was grepped by name only — manual bit-shifting elsewhere would not appear.

None of this undoes the fix. It does mean **T212's rebuild passing A3/A9 is
not by itself proof the artifact is sound**, and the register row should say
so. Folded into T223.

## P1 — the ceiling fix could kill correct builds

**T214, own-deliverable uncertainty A.** `--progress-timeout` defaults to
600 s because the brief suggested it. The worker states plainly: *"I have NO
DATA on actual fixpoint sweep durations on 4×4. If a single sweep takes
>10 min — plausible for late-stage fixpoint on the full 4×4 state space —
the watchdog would kill a correctly-progressing build. I would not defend
600 s without a measured sweep-duration distribution."*

We replaced a bad stuck-detector with a good one whose threshold is a guess.
T212's run emits per-sweep progress; the distribution is measurable from its
log for free. Registered **T224**.

## P1 — six sprint headers say RATIFIED on inference, not on rulings

**T205, own-deliverable uncertainty 1**, and the most epistemically serious
item in the set. T205 flipped six sprint phase-doc headers to RATIFIED per
CA-14's prescribed fix. It flags which of those are **inference**:

- Solid: oracle-v2 spec G1 (archive README records spec.audit-2 PASS);
  oracle-v2 and verify-battery design-M1 G2 (msg 074, `6de985a`).
- **Thin: oracle-v2 plan G2, verify-battery spec G1, verify-battery plan
  G2.** The verify-battery G1 agenda — R8 shared-code policy, §6a matrix,
  S1, the ADR-0020 amendment, sprint un-retirement — **has no recorded human
  ruling anyone has found.**

We have written "RATIFIED (G-human)" into tracked documents for gates the
human may never have held. That is a claim about a *person's decision*, and
it is the one kind of claim no amount of agent reasoning can substantiate.
**Surfaced to the human; not fixable by any task.**

## P2 — recorded, no task

- **`bin/` is gitignored wholesale and catches `bin/argus`**, a Python script
  that is therefore invisible to `git status` and one `git clean -x` from
  gone (T211-A). **Fixed inline** by the Orcha: `!bin/argus` exemption.
- **T216 could not identify what killed all 7 artifacts at 082650Z.** It
  ruled out a data regression (all seven failed at once — not a single-file
  signature) and ruled out inadequate ceilings (largest artifact: 248 MB,
  0.6 s). The disposition "transient" now rests on two eliminations rather
  than on inference, which is better than T208 had it — but **the trigger
  remains unexplained** and the CRITICAL should not be closed as understood.
- **`git add -A` mid-session absorbs another worker's kanban transitions**
  (T205-1). The "two Fable sessions share one git index" warning generalises
  to every concurrent worker and is enforced by nothing.
- **`suggest` registers the task from the template before the human edits
  it**, so `acceptance=` added afterwards never reaches the task record
  (T217). Documentation gap with a real trap in it.
- **T213 chose `blocked` for legacy `--fail`** where `fail-found` was equally
  arguable; the brief said "maps to fail-found or blocked" without deciding.
  One word in a brief cost a re-read of the whole vocabulary section.
- **`managent help` is a hardcoded string**, so a new verb must be added in
  two places; `cmdVerdict` reached the dispatch table and the spec but not
  the help text (T213).

## What this exercise cost and returned

Eight prompts. Returned two P0 defects in code written today, a qualification
that weakens the session's headline finding, a threshold nobody could defend,
and a documented case of tracked documents asserting human decisions on
inference. **Every one of these was known to a worker and to nobody else**,
and seven of the eight consoles would have closed within the hour.

The closeout question becomes protocol in T218 rather than staying a thing
the orchestrator remembers to ask.
