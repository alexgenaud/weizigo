<!--managent set=A-->

# EXP-15 — `docs/research/open-hypotheses-2026-07-27.md` reality check

**Closes:** a standing-tier audit of the open-work queue. The
hypotheses doc (H1..H5) was written 2026-07-27 evening; the
session's CURRENT.md uncommitted-work table lists it as "in flight,
may not exist yet." It does exist (we read it as part of the
chainability work), and the standing-tier work is to *close* the
queue, not let it grow. **This task checks each hypothesis against
the current state and tags it OPEN / IN PROGRESS / CLOSED with
evidence.**

**Read first:** `AGENTS.md` (foreclosures), then
`docs/research/open-hypotheses-2026-07-27.md` (the hypotheses), then
`docs/status/CURRENT.md` and `docs/status/HANDOVER.md` (the tactical
state), then `docs/epistemic/PROGRESS.md` (the strategic state), then
`docs/INTENT.md` (the human's purpose, to anchor "what is
consequential").

**KIND:** ANALYSIS, no `holds`. Reads research/ and status/; writes
one findings file.

**The question.** For each of H1..H5 (and any sub-hypotheses the doc
lists), report the **current state** with a one-line verdict and a
one-line evidence pointer. Verdicts:

- **CLOSED**: a finding exists, an artifact exists, or a doc
  records the answer. Cite the artifact / doc.
- **IN PROGRESS**: a worker is on it, the brief exists, the
  `bin/managent` kanban says so. Cite the task id.
- **OPEN**: no worker, no finding, the hypothesis stands.
- **STALE**: the hypothesis's premise no longer holds (e.g. the
  artifact was regenerated, the rule was rejected, the doc was
  superseded). Cite what superseded it.
- **REJECTED**: the hypothesis was tested and falsified; the
  falsification is recorded. Cite the falsification.

**ACCEPTANCE:** one file
`docs/evidence/GLOBAL.HYPOTHESES/reality-check-2026-07-28.md`
containing:

- **A per-hypothesis table:** `| id | hypothesis (one line) |
  verdict | evidence pointer | remediation |`.
- **Counts:** total hypotheses, by verdict.
- **A "what to dispatch next" section:** for each OPEN or IN
  PROGRESS hypothesis, the *minimum* next step the Orchestrator
  can take. (E.g. "H1: dispatch a 10-ply `bin/weizigo-reachcensus`
  on 4×4 with simple ko, ~30 min run; deliverable: a number; the
  number is the GO/NO-GO on simple ko as the generation rule.")
- **A "what to close" section:** for each CLOSED or REJECTED
  hypothesis, the *one-line* doc edit the owner can apply to
  reflect the new state.

**Calibration (mandatory).** The chainability finding (CLOSED
during this session, see `docs/research/ko-sensitive-chainability.md`
and the `eebe3c2` chain of commits) is the test case the worker
must verify the verdict logic on. A worker who tags H1 (chainability)
as OPEN has a different definition of "closed" than the project.

**EVIDENCE:** the per-hypothesis table. A `PROVENANCE.md` (per
`docs/evidence/README.md`) with the commit hash used as "now"
(`eebe3c2`), the date, the list of files read.

**Do NOT** edit `docs/research/open-hypotheses-2026-07-27.md` or
any cited source. The doc is the input; the audit is the output.

**Report shape:** the per-hypothesis table is the deliverable. The
"what to dispatch next" section is the standing-tier queue feed
for the Orchestrator.
