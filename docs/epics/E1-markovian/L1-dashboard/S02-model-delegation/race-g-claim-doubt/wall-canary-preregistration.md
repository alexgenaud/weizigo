# Wall canary — expected outcomes, pre-registered before the lanes run

**Written 2026-08-22 ~14:55Z, before any lane in the serial Claude queue below was launched.**
The 12:47Z outage was discovered by accident; this time the outcomes are written down first, so
the fleet's behaviour is *tested* rather than merely observed. Whichever serial lane straddles
the wall is the canary, and this file is the key it is graded against.

## AMENDED ~14:58Z, before any lane launched — the operator revised the concurrency rule

The operator's later instruction supersedes the serial rule for **one race**: *"I believe we can
get one full race in parallel before we approach the five hour limit… After a full race
finishes, then if we still have token left without limit, continue Claude runs in serial (DS in
parallel, full speed)."* So Race G's three Claude seats — opus, sonnet, haiku — launch
**together**, and the serial discipline below resumes for everything after this race.

**The expectations in this file are unchanged** and were written before any lane launched; only
the concurrency rule changed. What the change costs, stated plainly so the bet is on the record:
a parallel race means the wall can claim **all three** Claude lanes instead of one. That is
accepted because every Race G lane is told to flush its findings file after each claim and the
batch is ordered by cascade risk, so three wall-killed lanes leave three salvageable prefixes of
the valuable half rather than three empty files — and the T616/T617 precedent for adjudicating a
killed lane's artifact is now established practice rather than an improvisation.

`claude-fable-5` is **not** a lane. Per the operator it may serve only as grader, final arbiter,
evaluator or tie-breaker — so Race G's primary grade goes to a non-Claude seat under G3, and
Fable is held for arbitration of contested verdicts.

## Standing rule for this window (operator, 2026-08-22) — applies after this race

**One live heavy Claude lane at a time.** The wall can then claim at most one lane. Short haiku
lanes (< ~5 min expected) may interleave — they beat the last wall and losing one is cheap.
`claude-fable-5` never runs. DeepSeek and local work continue through any Claude outage.

## The serial Claude queue

1. `T622` re-run — **completed 511.5 s, exit 0** (landed before this file was written)
2. `T621` re-run — **completed 440.0 s, exit 0** (likewise)
3. `T640` Race G / opus seat
4. `T641` Race G / sonnet seat
5. `T642` Race G / haiku seat
6. remainder of the window: serial `T626` variance repeats — cheap to lose, useful if they land

## Expected outcomes if a lane straddles the wall

Pre-registered, in the order they should occur. Anything that does not happen is a finding
against the fix that claimed to handle it, and is to be recorded as such rather than explained.

1. **The lane dies with the provider's own text** in its log — the 12:47Z form was
   `You've hit your session limit · resets <time> (Europe/Oslo)` — and `rc=1`.
2. **The classifier reads provider-limit from the runner's terminal record**, not from a grep
   over worker stdout. T625 landed the Claude phrase, the 8 KiB head/tail window and the
   `tokens: no reading … claude api error` runner signal; this is the first live test of all
   three against a real wall rather than a replayed fixture.
3. **`killed_by = provider`** on the verification record — *if* T629 has landed by then. T629
   is in flight at the time of writing; if it has not landed, expect the ledger line to read
   `verified=unreached reason=provider-429` instead, which is the correct pre-T629 behaviour and
   **not** a failure of this canary. Record which of the two happened.
4. **The row reopens, unscored.** No `verified=fail fail=row`. No model-performance failure row
   against opus, sonnet or haiku. This is the clause that failed on 2026-08-22 and produced five
   false negatives; it is the single most important expectation in this file.
5. **A family cooldown is written** — claude appetite to OFF until the stated reset — *if* T628
   has landed. T628 is not dispatched at the time of writing, so the honest expectation is that
   **this does not happen** and the gap is confirmed rather than discovered. Say so plainly.
6. **At reset: one probe lane first, not a fan-out.** A single cheap lane confirms the window is
   actually back before anything else launches. No calendar auto-trust — the reset time in the
   error message is a claim by the provider, not a measurement.
7. **The killed lane's artifact is salvage-adjudicated before anything is re-run**, per the
   T616/T617 precedent: mechanical envelope-completeness check first, and if the file is
   complete it is graded rather than thrown away. Race G lanes are told to flush after every
   claim precisely so a wall-killed lane leaves a usable prefix. **A partial verdict set is a
   deliverable**, not a failure — expect to salvage 18 of 25, not 0.

## What would falsify the fix

- The lane dies and the ledger still says `fail=row` → T625's classifier did not fire on a live
  wall, and the fixtures gave false confidence.
- The row is left `in_progress` → the heal path failed again (T631 landed to prevent exactly
  this).
- Nothing at all is recorded and the fleet sits idle past the reset → the reset-time watcher gap
  is real and T628 is correctly scoped.
