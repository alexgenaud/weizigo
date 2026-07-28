<!--managent set=A-->

# EXP-13 — `bin/weizigo-claimlint` re-run + orphan catalog

**Closes:** the standing-tier evidence-debt closure. The handover
(`docs/status/handover-glm-advisor-2026-07-28.md`) reports that
`bin/weizigo-claimlint` is built and that on the last run it exited 1
on **10 orphans + 12 dangling evidence paths**. The DECISIONS.md
residue (item 5) names a new orphan **CLAIMS.md §6-D18** that
post-dates the lint run, and the residue also notes the 79/79
PROVEN-fail-evidence-rule figure. **This task re-runs the lint,
catalogs every finding, and produces the remediation list the
CLAIMS owner needs to fold.**

**Read first:** `AGENTS.md` (foreclosures), then
`docs/status/handover-glm-advisor-2026-07-28.md` §"Core technical
state" (the prior run summary), then
`untracked/msg/milestone-01-ko-reframe/DECISIONS.md` §"Residue" (the
known-new finding), then run `bin/weizigo-claimlint` and read its
output (the binary is in `bin/`, source in `src/claimlint.zig`).

**KIND:** ANALYSIS, no `holds`. Reads `bin/weizigo-claimlint`'s
output and `docs/epistemic/CLAIMS.md`; writes one findings file.

**The question.** What does the lint tool say *now*? For every
orphan / dangling evidence / PROVEN-without-evidence finding, name
it precisely: claim id (if any), source file + line, why the lint
flags it, and the **one-line remediation** the owner can apply.

**ACCEPTANCE:** one file
`docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md` containing:

- **The raw output** of `bin/weizigo-claimlint`, captured verbatim
  with the command and exit code, per the project's evidence
  rule (raw stdout/stderr is the evidence; the prose summary is
  the readme).
- **A per-finding table** with columns: `kind | claim-id (or
  none) | file:line | lint's reason | one-line remediation |
  owner-of-record (per the role: agent / human / orchestrator /
  auditor / dabir)`.
- **Counts:** orphans, dangling evidence, PROVEN-without-evidence,
  broken edges, broken calibrations — by kind and by owner.
- **The diff vs the prior run** (the 10 orphans + 12 dangling from
  the handover): new findings, fixed findings, regression
  findings. If a finding the prior run had is now gone, name it
  and the commit that fixed it.
- **The DECISIONS.md residue items** (D-1, D-2, D-6, D-7
  durability; QA-018 ruling; EXP-10 numbering; mixed claim
  inheritance) — for each, the lint finding that touches it (if
  any) and the lint's verdict (orphan, dangling, broken edge, or
  "not a lint concern").

**Calibration (mandatory).** The lint tool has a known-good
fixture (per the handover: "6 checks, 7 calibration cases, 5
mutation tests"). Re-run with the calibration fixture if
available; if not, the worker must read `src/claimlint.zig` to
confirm the tool's own self-test. **A lint tool that says "0
findings" with no calibration is decoration.**

**EVIDENCE:** the captured stdout + the per-finding table. A
`PROVENANCE.md` (per `docs/evidence/README.md`) with the command,
the binary's git hash, the date, and the prior run's summary for
diff comparison.

**Do NOT** edit `src/claimlint.zig`, `docs/epistemic/CLAIMS.md`,
or any other source of truth. This is an audit; the fixes are
separate work for the owners.

**Report shape:** the per-finding table is the deliverable. The
prose around it is for the Orchestrator's standing-tier queue.
