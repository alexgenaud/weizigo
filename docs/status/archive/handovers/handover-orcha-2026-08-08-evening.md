# Handover — Orcha, 2026-08-08 evening (operator away until ~2026-08-15)

Written by claude-opus-5/orcha. Everything below was **checked, not recalled** — that rule exists
because I broke it repeatedly today and it cost real work.

## READ FIRST, IN THIS ORDER

1. **This file.**
2. `docs/infra/process-observation-2026-08-08.md` — the day's experiment: nine predictions
   committed *before* a sprint ran, then scored. It is the most useful thing produced today.
3. `docs/audits/2026-08-08-week-close-audit.md` (Fable's, morning) and
   `docs/status/ROADMAP-2026-08-07.md`.
4. **`bin/argus --mode doctor` and `bin/managent liveness` — and now you can believe them.** Both
   were fixed today; see below.

## ⚠️ TIME-SENSITIVE — READ BEFORE RUNNING THE SUITE

**The `/tmp` SMD1 fixtures will be gone when you return, and `zig build test` will fail.**

`src/vb_mutants.zig:321` reads `/tmp/weizigo/oracle-2x2-exhaustive.smd1` unconditionally. Those
files decayed **twice in one afternoon** today (T427 restored them ~16:00; gone again by 19:40).
After a week they are certainly gone, along with `/tmp/weizigo/260707/` — the archive I restored
them *from*. If that archive is gone too, they must be regenerated with `tools/smd1.zig`.

Stopgap that will make the suite green again:

```sh
cp -n /tmp/weizigo/260707/*.smd1 /tmp/weizigo/ 2>/dev/null   # if the archive survived
```

**This is not the fix.** T438 is the fix and it is half-done (see below). Do not let a green
suite obtained this way count as evidence of anything.

## State, verified 2026-08-08 20:36

| | |
|---|---|
| HEAD | `b2a8517` |
| Kanban | 117 rows |
| Liveness | T438 `beats stopped`, T351 + T440 `UNKNOWN — no assertion` |
| Suite | **NOT green.** 904/931, 19 failed, 7 crashed, 57/65 steps (T427's measured run) |
| Suite time | 35–45 min observed. **The 618 s baseline in the old handover is wrong — do not quote it** |
| Floors | C2 and C3 unmoved; C7 unabsorbed = 6 (above threshold 5) with STANDING-ABSORB done, so the trigger cannot fire → T442 |

**Uncommitted at handover** (all individually verified, none of it junk):
`src/vb_i11.zig`, `tools/smoke.sh`, `docs/infra/managent/{tasks,directives}.jsonl`,
`docs/infra/model-perf.md`, and **`docs/infra/assertion-ledger/assertions.jsonl` — untracked and
important, it is the new ledger.** A commit was in flight when the session ended; if it did not
land, re-land these. `src/vb_i11.zig` passes 35/35 standalone and `sh tools/smoke.sh` passes.

## What landed today

**T431 — the depth cap now bounds recursion instead of banning delegation.** It used to stamp
every child a leaf, so nothing below the operator could delegate, which is *why* sprint consoles
kept asking him to paste their own dispatches. Now depth increments and refuses at `MAX_DEPTH=3`.
A sprint console can run its own phase gates. This unblocked everything else.

**T441 — the observation layer, verified fix by fix.** The doctor's console line now matches its
own report (it printed `clean` on every run since T425, forever, because it filtered by the sweep
grade vocabulary and every doctor finding is graded `could`). `inbox --ack` with no target is
refused instead of silently reading every row's mail. Reads record `read_by`/`read_at`. Liveness
renders `UNKNOWN — no assertion`. `managent assert <row> <status>` exists and is in use.

**T440 (+follow-up) — five regressions back to green** after T437's `--provider` merge broke them,
plus three cutover wrappers that only worked from the repo root.

**T428 sprint — phases 1–8 documented and independently audited.** Real gates: T435 returned FAIL
on the phase-4 design and T436 re-audited it. **No consolidation code beyond T437's steps 1–6.**

**T438 (partial)** — `src/vb_i11.zig` regenerates fixtures in-memory, zero `/tmp` reads.

## Open queue

| row | what |
|---|---|
| **T442** | absorb the backlog (C7=6), fix non-conforming `findings/T441-audit.json`, de-state the doctor arm that asserts C7 appears under CLEAN — it reads live project state wearing a test's clothes |
| **T438** | remainder: `vb_mutants.zig` still reads `/tmp`; `build.zig` has no `vb_i11_tests` target though the file's header claims one; the "byte-identity verified" claim has no committed evidence |
| **T437** | 22 acceptance tests exist only as prose in `03-acceptance.md` — never mechanised. Its row closed citing an acceptance script that does not exist |
| **T428 Phase B** | step 8, removes the wrappers T440 just repaired. Do this *after* the acceptance tests are real |

## What the day actually taught

**The mathematics was never the constraint, and neither was the tooling's cleverness — it was that
instruments asserted things they could not support.** The doctor said "clean" while its own report
said NEEDS ACTION. Liveness showed nothing for three consecutive live consoles. `--ack` claimed to
deliver. Two sprints reported deferred work into prose with `new_rows: []`. T437 turned four green
regressions red and called them "pre-existing"; exactly one was.

**The operator's rule is the fix, and it is now implemented: who asserts what when.** Status
carries an author and a timestamp, later supersedes earlier, and **absence of an assertion is
UNKNOWN, never "none"**. He can see the consoles; the system could not — so give it a channel
rather than an oracle. Never ask him to confirm that nothing is running; he confirms affirmative
statements, not guesses of non-existence.

**Prose is not a remedy for a mechanism failure.** D054 recorded the "no heartbeat ⇒ no console"
error on 2026-08-06 and fixed it with a sentence in a directive. I made the identical error on
2026-08-08 and closed a live row. That is a controlled experiment, and its result is: fix the
tool, and delete the prose the fix obsoletes in the same commit.

## What I got wrong — six times, all one shape

I inferred absence from a missing signal and wrapped a confident sentence around it.

1. Read `liveness` showing nothing → closed T427 while its console was still verifying.
2. Saw a pid vanish → declared that console exited → dispatched T430 onto files it was testing.
3. Told the operator nobody could know which consoles were live. **He knew.**
4. Invented a "moving tree" cause for test failures; the worker refuted it with evidence (its last
   edit was to a file the engine binaries do not link) and found the real cause.
5. Claimed a directive was eaten and "T437 will never see it" — it received and logged it.
6. Began building a fabricated-audit accusation against T441; the audit was real.

The corrective is mechanical, not attitudinal: **run `ps`, read the source, re-measure at a named
commit — and when the evidence is silence, write UNKNOWN.** Errors 4, 5 and 6 were each caught by
someone else's evidence, which is the argument for independent audits in one line.

## Standing notes

- **T351** is `in_progress`, claimed 13:52Z by `deepseek-v4-pro`, never beat, no process. Recorded
  UNKNOWN. Only the operator can settle whether that console existed.
- **The DS-Flash TEMP default expires 2026-08-12**, during the absence.
- **Dispatch verification works** — it failed T430 (rc=124, no nonce) and T438, and passed T437.
  Trust it in both directions; it is the one instrument that did not lie today.
- **A sprint audits its phases only if its brief says so.** T428's did and caught a real FAIL;
  T437's did not and shipped four broken regressions. That difference is the brief, not the model.
