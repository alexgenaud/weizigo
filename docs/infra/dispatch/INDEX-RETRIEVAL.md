<!--managent set=X-->
# INDEX-RETRIEVAL — summarise and index the tree so knowledge can be found without sifting kludge

**Opened by:** the human, 2026-07-29: *"He stores records, with claims backing claims. I just hope we properly summarize and index our knowledge so that we can easily and quickly retrieve useful information that we want and need to know without sifting through useless kludge that we do not want and do not need."*

That is the Persian-chancery standard: the tablet is worthless if the scribe cannot find it. The project has the records (254 claims, ~60 docs, evidence trees, ADRs, audits, channel history) and **no retrieval layer**. This is the complement to `NARRATIVE-LAYER`: that task tells the through-line; this one makes any *specific* fact findable in one hop.

## The task

**1. A single top-level index** — `docs/INDEX.md`. For each question a reader or agent actually arrives with, one line and one destination:
- *what is known / what failed / what's open* → `PROGRESS.md` (narrative), `CLAIMS.md` (ledger)
- *what is the state right now* → `bin/managent resume`
- *why was X decided* → the ADR, by topic not by number
- *what backs claim Y* → its evidence dir
- *what did model Z do* → `model-perf.md`
- *what is in flight* → `bin/managent status`
Every line states **which file is authoritative for that question**, so two files never both look canonical.

**2. Prune the kludge, and say what was pruned.** Identify docs that are superseded, duplicative, or historical-only, and move them under a clearly-marked `docs/attic/` (or banner them in place if they are cited). **Do not delete** — the project's rule is that evidence stays. But a reader must be able to tell in one line whether a file is current, historical, or superseded. Add that line to the top of every doc that lacks it.

**3. Claim-to-evidence and claim-to-task indices**, generated not hand-written: for each claim ID, its status, its evidence paths, and the tasks that produced them. `claimlint` already parses the graph — emit this as a by-product rather than writing a second parser.

**4. A retrieval test — this is the acceptance criterion, not decoration.** Write down ten questions a new agent or the human would realistically ask (*"is the 4×4 +2 value trustworthy?"*, *"why is PSK not the target?"*, *"what is the eye-prune's status?"*, *"which claims have no committed evidence?"*, *"what did 2B-4 conclude and does it still stand?"*). For each: the exact path from `docs/INDEX.md` to the answer, and the **number of hops**. Any question needing more than **two hops** is a defect in the index — fix the index, not the question.

## Acceptance

- `docs/INDEX.md` exists, with one authoritative destination per question.
- Every doc carries a current/historical/superseded line at its top.
- The generated claim→evidence and claim→task indices exist and are reproducible by a command.
- The ten-question retrieval test, with hop counts, all ≤ 2.
- No claim status changed; no evidence deleted.

## Deliverable

`docs/INDEX.md`, the generated indices, the per-doc status lines, and the retrieval test as `docs/status/retrieval-test-<date>.md`. Coordinate with `NARRATIVE-LAYER` (it owns `PROGRESS.md`) and with whoever holds `CLAIMS.md`.

**Read first:** `AGENTS.md` (the current router — this task supersedes its "where to go next" table with something exhaustive), `docs/README.md`, `docs/about-this-document.md`, `CLAIMS.md` §4-§7.
