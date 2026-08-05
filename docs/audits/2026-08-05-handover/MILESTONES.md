# MILESTONES — what the human can see, test, and care about

Companion to `ROADMAP.md` (same directory, same commit stream). The roadmap orders the work by
dependency and speaks the project's internal language; this file names the checkpoints a human can
verify without reading a single task brief. Each milestone says what changes in plain terms, how to
see it with your own eyes, and where it stands today. Milestones are observations, not tasks —
nothing here adds work; it only makes the work visible.

**Every milestone has a short name. Use `M3 (the new engine outplays the old one)`, never a bare
`M3`.** The names are the point of this file: an ID nobody can expand is not communication.

---

## The one-paragraph story

We already have a complete 4×4 answer table and a set of instruments that have been shown to catch
deliberately broken input — that is **M0 (the table and the instruments exist)**. What we do *not*
yet have is the right to call those 99 million values *proven*: two of the four correctness
properties hold at full scale, and the other two rested on a 22-entry sample until that was
corrected to "deferred". Closing those two is **M2 (proven 4×4 values)**, and it is the critical
path right now. Alongside it, the project has been paying down two debts: the dashboard that
describes the project has to stop lying about itself — **M1 (the dashboard tells the truth)** — and
the claim ledger has to stop marking things "proven" with no evidence attached — **M4 (the ledger
is clean)**. Then the fourteen scattered copies of the ko rule collapse into one production
rulebook, **M5 (one rulebook)**, at which point the theorem itself is claimable: **M6 (small Go
solved, certifiably)**. **M7 (the 5×5 decision, costed)** is the prize behind it. Running
independently of that spine, **M3 (the new engine outplays the old one)** is the sanity check that
the reconstruction is actually an improvement — and as of 2026-08-05 it has been measured, on the
board, with the games committed.

| milestone | short name | status today |
|---|---|---|
| **M0** | the table and the instruments exist | banked — **but its own self-test is failing today** (see below) |
| **M1** | the dashboard tells the truth | substantially delivered 2026-08-05; one gauge still mis-reads |
| **M2** | proven 4×4 values | **in progress — the critical path** (row T363) |
| **M3** | the new engine outplays the old one | **met 2026-08-05**, scope stated |
| **M4** | the ledger is clean | opened 2026-08-05 — the plan exists and is ruled on (rows T354 → T373) |
| **M5** | one rulebook | not started; correctly waits on M2 |
| **M6** | small Go solved, certifiably | the mission; needs M2 + M4 + M5 |
| **M7** | the 5×5 decision, costed | frontier; only after M6 |

---

## M0 — the table and the instruments exist *(banked, with one caveat you should know about)*

A complete 4×4 table exists — 99,133,036 entries, every reachable position present, none extra —
and the instruments that judge it have been proven to work: every check first had to catch a
deliberately sabotaged input before its "pass" counted for anything.

**See it yourself:** play the engine over GTP (Go Text Protocol) in Sabaki or GoGui — it plays
real, legal, strong small-board Go right now. The battery's own self-test:
`verify-battery 3x3 artifacts/oracle-3x3.wzo` reproduces the recorded golden-master numbers.

**Status caveat, 2026-08-05:** this milestone's original self-test was "`zig build test` runs the
battery green", and **that command is red today** — broken by construction since row T346, where a
test target was wired so that it cannot compile. The instruments themselves are fine (they were
re-verified in isolation on 2026-08-05: the clean 3×3 artifact reproduced the golden master
exactly, and a single deliberately altered *value* was caught by two independent invariants). But
by this file's own rule — the test outranks the narrative — M0 is not currently *observable*.
Restoring it is row T369; the specific wiring fix belongs to T363, whose gate it is.

## M1 — the dashboard tells the truth *(roadmap Tier 0 — substantially delivered)*

What the project says about itself matches reality: no stale binaries, no gauge reading that
disagrees with a fresh measurement, no messages rotting unread in the queue.

**See it yourself:** run `bin/managent resume`. It should show zero STALE lines and no stalled
directives, and the gate numbers it prints should match a fresh run of `bin/weizigo-claimlint`.

**Status, 2026-08-05:** delivered during the day — binaries rebuilt and current, the 24-message
backlog drained, the unabsorbed-findings gauge taken from 4 to 0, and **two defects found in the
smoke test itself**, one of which had been passing vacuously since the line was written (it
filtered for tests by a pattern that matched *zero* tests, and zero tests passing exits
successfully). One gauge still mis-reads: a rename in one tool orphaned the trigger text another
tool watches for, so an auto-absorb trigger silently reads zero forever (row T368). Also newly
found: the liveness display cannot distinguish a working agent from a dead one, because the
identity that would tell them apart is never passed in (row T370).

## M2 — proven 4×4 values, an answer key rather than an opinion *(roadmap Tier 1 — the critical path)*

Today's honest sentence, which must not be shortened: *the 4×4 artifact is structurally complete;
its values are verified for Bellman residual and key agreement at full scale, and not yet for
closure or cycle containment.* After M2, all four properties hold — every value verified to be
*the* answer under the written rules, with the full table as the denominator, never a sample. This
is the difference between "a strong engine's opinion" and "an answer key".

**See it yourself:** the discharge ruling will state each property as `0 violations / <full
count>` — **if any line lacks a denominator, the milestone is not met, whatever the prose says.**
That rule exists because it was broken once: two properties were tabled as "pass" on a 22-entry
sample — 0.00002% of the table — and had to be corrected to "deferred".

For a hands-on test: corrupt a *copy* of an artifact and run the battery against it — it must fail
loudly. **Do it the strong way.** A blind byte flip is caught by the file's internal checksum, so
it only proves the checksum works; the corruption never reaches a single correctness check. The
real test changes a *value* and repairs the checksum, so the lie reaches the invariants. That was
run on 2026-08-05 (`docs/evidence/BATTERY/seeded-control-2026-08-05.md`): one value altered out of
12,675 legal cells, and two independent checks fired — the Bellman residual check went from 0 to 4
violations — while six unrelated checks stayed exactly still. A green light you have watched turn
red when it should is the only green light worth trusting.

**Status:** two of four properties established at full scale (0 Bellman violations / 95,677,624
and 0 key mismatches / 99,133,036). The remaining two — closure and cycle containment — plus a
retroactive 4×3 rung and two mutation assertions, are the four gaps in row T363, in flight.

## M3 — the new engine outplays the old one, watchably *(met 2026-08-05)*

The ratified bar for the whole reconstruction is "at least as good as today's 4×4 engine." This
milestone makes that bar watchable: the two engines play each other, both colour assignments, and
every game where the old engine genuinely threw away a winnable position is recorded as an SGF
(Smart Game Format) file you can step through move by move.

**See it yourself:** open the SGF files in `docs/evidence/ENGINE-VS-ENGINE/` in any Go viewer. No
committed kifu (game record), no milestone.

**Status: met.** 132 games committed (33 openings × 2 colour assignments × 2 rule frames, seed 42),
all 132 structurally valid and annotated at the divergence move. The direction of the result is
**the new engine is better**: the old engine lost 36–30 in the shared-rules frame, and in **9
games it threw away a position it could have won or drawn** — the new engine, given the same
colour from the same opening, does win them. The cleanest single case: at one position *both*
tables agree White is winning by 16, and the old engine then loses by 3 from it, while the new
engine wins by 16 — a 19-point swing that shows the old table contradicting its own play.

**Scope, stated plainly:** the two artifacts encode slightly different rulesets, so a raw
value-by-value comparison would be comparing two different games. Only an *outcome* difference was
counted as a loss, and 62 of 66 comparisons fall in the directly-comparable slice. A second run
with a different random seed reproduced the shape.

## M4 — the ledger is clean *(roadmap Tier 2 — opened 2026-08-05)*

Every claim marked PROVEN links to committed evidence you can open; every claim that cannot be
backed has been demoted or archived with a one-line epitaph saying why. The number nobody watched,
because it never failed anything: **76 of 100 PROVEN rows have no committed evidence.**

**See it yourself:** `bin/weizigo-claimlint` reports `UNBACKED 0`. Then the spot-check: pick any
PROVEN row at random, follow its evidence path, and confirm the file exists and says what the row
says. If a random probe ever fails, the milestone is off.

**Status:** the plan now exists and has been ruled on. All 334 ledger rows were classified with
denominators (row T354): 201 are live claims, 132 are history — measurements of artifacts the
project has since disowned, ruleset experiments that were foreclosed, player-side diagnostics, and
process notes — and those 132 move to an archive **in full, with epitaphs, never deleted**. The
live ledger goes 334 → 202. The unbacked count comes down in four declared steps (76 → 48 → 32 →
18 → 0), each step's floor locked in only by the commit that reaches it, so the number can never
quietly climb again. Row T373 executes the first step and is deliberately blocked until T363
finishes, because it touches machinery that could otherwise freeze every agent's ability to commit.

## M5 — one rulebook *(roadmap Tier 3)*

The rules of Go, as this project defines them, live in exactly one production module. The fourteen
historical copies of the ko rule — the confirmed root cause of the project's worst bugs — become
frozen museum pieces that the tests compare against but nothing runs in anger.

**See it yourself:** ask "where is the ko rule?" and get one file as the answer. The engine you
play in M0's test is, from here on, playing through that one rulebook.

**Status:** not started, correctly. The kernel extraction it depends on has landed but is held
unpromoted on purpose — promotion is gated on mutation testing showing the tests can actually
catch a broken rule.

## M6 — the theorem: small Go solved, certifiably *(the mission)*

For every legal position on every board up to 4×4, the exact game-theoretic value is known, proven
under the written axioms, with explicit non-claims for everything outside them. weizigo stops being
a strong program and becomes a reference — the answer key other Go software could be checked
against.

**See it yourself:** play any 4×4 position against the oracle from both sides, any line you like —
the result it predicted is the result you get, every time. The certification machinery
(M2 + M4 + M5) is what turns that experience from anecdote into theorem.

## M7 — the 5×5 decision, with a price tag *(frontier; only after M6)*

A one-page go/no-go memo for 5×4 and 5×5: measured cost per board size, the measured 16× symmetry
saving, projected memory and wall-clock on this host. Whatever the decision, it will be a costed
choice, not a hope.

**See it yourself:** the memo fits on one page and every number in it cites the run that measured
it.

---

## How work reports against milestones

Findings files and commit messages are written for the next agent; this section exists so the human
gets a sentence written for them. **After a row records its findings to disk, its close report adds
a short milestone line** — no new artifact, no schema change, no extra approval step:

> **Milestone:** advances `M<n> (<short name>)` — <what a human can now see that they could not
> before> — <what still stands between here and that milestone>.

Three rules make it useful rather than decorative:

1. **Always expand the ID.** `M2 (proven 4×4 values)`, never a bare `M2`.
2. **Say the direction plainly.** If a result makes something look *worse*, say which thing got
   worse and which got better. "Every game diverged and there were 9 genuine losses" is
   uninterpretable until you say **whose** losses they were and that the new engine wins them.
3. **A row that advances no milestone says so** — `Milestone: none directly; unblocks <row>`. Fleet
   plumbing and hygiene rows are honest work; pretending they move the mission is what makes
   milestone talk worthless.

**Reading progress:** M1 is observable this week; M2 is the current critical path; M3 is done;
M4 is the long middle now opened; M5 follows M2; M6 is the mission; M7 is the prize behind it. When
any milestone's self-test fails, the milestone is not met — the tests above outrank any narrative,
including this one.
