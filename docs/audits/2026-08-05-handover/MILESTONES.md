# MILESTONES — what the human can see, test, and care about

Companion to `ROADMAP.md` (same directory, same commit stream). The roadmap orders the work
by dependency and speaks the project's internal language; this file names the checkpoints a
human can verify without reading a single task brief. Each milestone says what changes in
plain terms, how to see it with your own eyes, and which roadmap tier delivers it. Milestones
are observations, not tasks — nothing here adds work; it only makes the work visible.

---

## M0 — already banked (so progress is measured from the right zero)

A complete 4×4 table exists — 99,133,036 entries, every reachable position present, none
extra — and the instruments that judge it have been proven to work: every check first had to
catch a deliberately sabotaged input before its "pass" counted for anything.

**See it yourself:** `zig build test` runs the battery green. Play the engine over GTP (Go
Text Protocol) in Sabaki or GoGui — it plays real, legal, strong small-board Go right now.

## M1 — the dashboard tells the truth *(next; delivered by roadmap Tier 0, hours)*

What the project says about itself matches reality: no stale binaries, no gauge reading
that disagrees with a fresh measurement, no messages rotting unread in the queue.

**See it yourself:** run `bin/managent resume`. It should show zero STALE lines and no
stalled directives, and the gate numbers it prints should match a fresh run of
`bin/weizigo-claimlint`. Today it fails this test in three places — that is the milestone.

## M2 — the 4×4 numbers are *proven right*, not just present *(roadmap Tier 1)*

Today's honest sentence: the table is structurally complete and its values pass two of the
four correctness properties at full scale. After M2, all four hold — every value is verified
to be *the* answer under the written rules, with the full table as the denominator, never a
sample. This is the difference between "an engine's opinion" and "an answer key".

**See it yourself:** the discharge ruling will state each property as `0 violations /
<full count>` — if any line lacks a denominator, the milestone is not met, whatever the
prose says. For a hands-on test: corrupt one byte of a *copy* of the artifact and run the
battery against it — it must fail loudly. A green light you have watched turn red when it
should is the only green light worth trusting.

## M3 — old engine vs new engine, on the board *(independent; needs T361 re-registered)*

The ratified bar for the whole reconstruction is "at least as good as today's 4×4 engine."
This milestone makes that bar watchable: the two engines play each other, both colour
assignments, and every genuine loss is recorded as an SGF (Smart Game Format) game you can
step through move by move.

**See it yourself:** open the SGF files in any Go viewer. No committed kifu, no milestone.

## M4 — the ledger is clean *(roadmap Tier 2)*

Every claim marked PROVEN links to committed evidence you can open; every claim that cannot
be backed has been demoted or archived with a one-line epitaph saying why. Today 76 of 100
PROVEN rows have no committed evidence — the number nobody watched because it never failed
anything.

**See it yourself:** `bin/weizigo-claimlint` reports `UNBACKED 0`. Then the spot-check: pick
any PROVEN row at random, follow its evidence path, and confirm the file exists and says
what the row says. If a random probe ever fails, the milestone is off.

## M5 — one rulebook *(roadmap Tier 3)*

The rules of Go, as this project defines them, live in exactly one production module. The
fourteen historical copies of the ko rule — the confirmed root cause of the project's worst
bugs — become frozen museum pieces that the tests compare against but nothing runs in anger.

**See it yourself:** ask "where is the ko rule?" and get one file as the answer. The engine
you play in M0's test is, from here on, playing through that one rulebook.

## M6 — the theorem: small Go is solved, certifiably *(the mission's Z)*

For every legal position on every board up to 4×4, the exact game-theoretic value is known,
proven under the written axioms, with explicit non-claims for everything outside them.
weizigo stops being a strong program and becomes a reference — the answer key other Go
software could be checked against.

**See it yourself:** play any 4×4 position against the oracle from both sides, any line you
like — the result it predicted is the result you get, every time. The certification
machinery (M2 + M4 + M5) is what turns that experience from anecdote into theorem.

## M7 — the 5×5 decision, with a price tag *(frontier; only after M6)*

A one-page go/no-go memo for 5×4 and 5×5: measured cost per board size, the measured 16×
symmetry saving, projected memory and wall-clock on this host. Whatever the decision, it
will be a costed choice, not a hope.

**See it yourself:** the memo fits on one page and every number in it cites the run that
measured it.

---

**Reading progress:** M1 is observable this week; M2 is the current critical path; M3 can
land any time a console is free; M4–M5 are the long middle; M6 is the mission; M7 is the
prize behind it. When any milestone's self-test fails, the milestone is not met — the tests
above outrank any narrative, including this one.
