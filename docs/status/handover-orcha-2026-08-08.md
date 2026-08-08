# Orchestrator handover — 2026-08-08

**Author:** claude-opus-5, Orchestrator seat (2026-08-06 → 2026-08-08).
**Audience:** the next Orchestrator, and the operator returning after a week.

**This file is deliberately short.** Two documents already carry the substance and neither should be
duplicated here — the project's own doctrine is one canonical doc per topic, and this week's audit
found the corpus already collects contradictions:

1. **`docs/audits/2026-08-08-week-close-audit.md`** — claude-fable-5's independent holistic audit.
   Read it first; it was written from live reads, not from my summaries.
2. **`docs/status/ROADMAP-2026-08-07.md`** — what we know / what we know we don't / doubts / short and
   long term. Still current; §2 items 2 and 3 were answered on 2026-08-08 and are marked as such.
3. **This file** — only what is specific to the seat: state at handover, and what I got wrong.

Then `bin/managent status` and `git log` **before dispatching anything**.

---

## State at handover

| | |
|---|---|
| Register | 228 rows, mapping doc 228, C9b lockstep, 0 node mismatches |
| Findings | C7 unabsorbed **0**, non-conforming **0** |
| Floors | C2 = 11, C3 = 48 — unmoved all week |
| Rows in flight | none |
| Processes | none (no zombies, no orphans) |
| Engine | current, playable in Sabaki: `bin/weizigo-gtp` + `data/oracle-4x4-v2.wzo2`, board 4×4, komi 0 |

**Registered and not yet dispatched:** `T423` (date-partition `/tmp`), `T424` (claim/close lifecycle
flakes — five defects, priority order stated in the brief).

**The one open stability question:** `zig build test` was **not confirmed green** in Fable's audit run
(923/931, 7 crashed, ~52 min against a documented ~610 s), though nothing reproduced standalone and
the machine was saturated. A clean run was started on a quiet machine at handover time; **check
`/tmp/weizigo-suite-clean-260808.log` for its verdict before trusting or distrusting the suite.**

---

## What I got wrong, recorded because the next seat will be tempted the same way

1. **I asserted a negative a measurement could not support.** I said T408 "falsified" the five-agent
   Ollama cap. It did not — it said *not observed through 6*, which is different, and its probe
   finished in **nine seconds on warm sessions** and could not have detected a transfer-session cap.
   The operator corrected me twice. **The cap exists; absence of an observed effect is not evidence of
   absence.** This is now audit-gate check 7 on every sprint.
2. **I let a brief contradict itself within 24 hours.** T407 still said "six games" in its title and
   two sections a day after the matrix was corrected to four. A console caught it before I did.
3. **I made a production edit without a test first** (`src/gtp.zig`, the `list_commands` overflow).
   Verified by hand; the regression test had to be added afterwards by T403. `AGENTS.md` now binds the
   Orchestrator seat to test-first, by name.
4. **I treated three `/tmp` evidence rescues as one-offs before looking for the pattern.** The sweep
   then found **344 cited `/tmp` paths across 72 docs, 43 already destroyed**. Fixing the mechanism
   should have come after the first rescue, not the fourth.
5. **I sent a directive while a row was writing up** (D064 to T422) and it landed post-close. Steering
   sent late will usually miss; send early or expect a follow-up commit.
6. **A prediction of mine was falsified and the row was right to say so** — I expected
   wins-from-non-claimed-roots to fall as opponent strength rose. Measured: pachi 5→4, fuego 23→24.
   The earlier margin was **not** primarily opponent weakness.

---

## What I would do next, in order

1. **Resolve the suite** — one clean run, already started. Either it clears the flag or it hands you a
   real defect. Cheap, and everything else is easier once the suite is trustworthy.
2. **`T424`** — the claim/close lifecycle. Five rows this week were worked and committed while reading
   `dispatchable`; that is why the kanban and reality diverge.
3. **Audit the 4×3 root `[+4,+12]`** — single-instrument, unaudited, and it gates anything citing it.
4. **Exhaustive 4×4 cycle detection** — the sampled zero is a lower bound; the run was killed twice by
   the RSS guard, so it is a resource problem, not a method one.
5. **The `life ⟹ L==H` theorem attempt** — 99.1M entries, zero exceptions, unexplained, and *not*
   score-forced (alive-and-losing states exist). The only thing that converts a measurement into a
   proof.

---

## The one sentence I would keep

**Four separate tools this week reported success while doing nothing** — an instrument that ran 14
hours in an infinite loop, a directive channel that reported delivery of an unreadable record, an
absorb tool that read a 221-row register as empty, and an agent that replied `OK.` and executed
nothing. The mathematics was never the constraint. **A silent wrong answer outranks a loud crash**,
and the cure is always mechanical — a control shown red, a side effect asserted — never an
instruction to be more careful.
