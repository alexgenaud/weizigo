<!--managent set=A-->

# EXP-14 — `docs/research/corrections-2026-07-27.md` cross-check

**Closes:** a standing-tier audit of the "errata ledger" named in
`docs/status/CURRENT.md`'s uncommitted-work table. The corrections
doc is dated 2026-07-27 and was written by an in-flight agent
during the 2026-07-27 evening chainability session. It lists known-
unsound statements in the repo. **This task verifies each
correction against its cited source-of-truth, so the Orchestrator
can fold the verified ones into the standing state.**

**Read first:** `AGENTS.md` (foreclosures), then
`docs/research/corrections-2026-07-27.md` (the corrections ledger),
then for each correction, the file the correction says is wrong.
Read `docs/status/HANDOVER.md` §"Gotchas" for the prior session's
framing.

**KIND:** ANALYSIS, no `holds`. Reads research/ and status/; writes
one findings file.

**The question.** For each correction in
`docs/research/corrections-2026-07-27.md`, find the cited source-
of-truth and verify: is the correction's claim that the source is
wrong actually true at the current commit (`eebe3c2`)? If the
source has been fixed since, the correction is **stale**. If the
correction misreads the source, the correction is **wrong**. If
both are true at HEAD, the correction is **verified**.

**ACCEPTANCE:** one file
`docs/evidence/GLOBAL.CORRECTIONS/cross-check-2026-07-28.md`
containing:

- **A per-correction table:** `| correction-id | file:line in
  corrections | source file:line | what the correction says |
  what the source actually says (at eebe3c2) | verdict:
  verified / stale / wrong / partial | remediation |`.
- **Counts:** total corrections, verified, stale, wrong, partial.
- **A "fixes since 2026-07-27" section:** corrections that became
  stale because a later commit fixed the source. Name the commit.
  (E.g. if a correction says "ADR-0013 closing line is wrong" and
  ADR-0013 was amended by a later commit, that's a stale
  correction.)
- **A "wrong corrections" section:** corrections whose claim is
  not supported by the source. The worker must name what the
  source actually says, in the source's own words, and what the
  correction claims, in the correction's own words.
- **A "partial corrections" section:** corrections that are
  half-right (e.g. "the comment is wrong, but the code is right" or
  "the line is right, but a different line has the bug"). The
  partial verdict must say *which* half is which.

**Calibration (mandatory).** The chainability finding is the
corrections' "Known-unsound statements already in the repo"
section's most-cited example. The worker must read at least three
corrections that the doc's preamble says are "do not re-derive" and
verify them by hand. A worker who finds zero wrong/stale
corrections has either missed them or has not done the read.

**EVIDENCE:** the per-correction table. A `PROVENANCE.md` (per
`docs/evidence/README.md`) with the commit hash used as
"now" (`eebe3c2`), the date, and a one-line note on each source
file's last-touched timestamp.

**Do NOT** edit `docs/research/corrections-2026-07-27.md` or any
cited source. This is an audit; the fixes are separate.

**Report shape:** the per-correction table is the deliverable. The
worker should also name **the two most consequential** corrections
in plain prose (the ones that, if wrong, mislead the most
readers), and the **one correction that should be retracted** if
any are wrong.
