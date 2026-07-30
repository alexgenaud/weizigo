<!--managent set=A-->

# EXP-12 — denominator sweep across `docs/research/*.md`

**Closes:** a standing-tier hygiene gap. The chainability finding
research doc (`docs/research/ko-sensitive-chainability.md`) has a
paragraph titled **"Every percentage in this document names its
denominator"** — and the tool it audits (`bin/weizigo-chainability`)
ships a `// Tool note: … the counter printed as 'legal, non-settled'
was incremented before the settled 'continue'…` that explicitly
documents a denominator confusion seeded by a mislabelled output
line. The project's standing rule (AGENTS.md, GLOSSARY §"Black-
positive", and the rationale behind every published anchor) is that
percentages must state their denominator. **This task audits that
rule across the research tree.**

**Read first:** `AGENTS.md` (foreclosures, "Evidence outlives
agents", "Numbers cite their run and state their denominator"), then
`docs/research/ko-sensitive-chainability.md` (the canonical example
of *how* to write denominators and *what* the rule looks like when
followed), then walk every `docs/research/*.md`.

**KIND:** ANALYSIS, no `holds`. Reads `docs/research/`, writes one
new file.

**The question.** For every percentage that appears in
`docs/research/*.md` (and in the `Evidence` and `Research` sections
of `docs/epistemic/PROGRESS.md` if time permits), report:

- The file and line of the percentage.
- The denominator as *written* in the document.
- The denominator as *correct* per the cited source-of-truth
  (commit hash, run command, OEIS reference, artifact header, etc.).
- **PASS** if written denominator matches the correct one and the
  numerator is verifiable.
- **FAIL** with the kind of failure if they disagree:
  - "denominator unstated" (no number for `n=`)
  - "denominator ambiguous" (two possible denominators, neither
    stated as the one used)
  - "denominator wrong" (a different denominator should be used;
    the correct one differs from the stated one)
  - "numerator unverifiable" (no source-of-truth, or the source
    disagrees with the percentage)
  - "stale" (the document's percentage predates a regeneration;
    the new number is in another document, this one wasn't updated)

**ACCEPTANCE:** one file
`docs/evidence/GLOBAL.DENOMINATORS/sweep-2026-07-28.md` containing:

- A summary table: `| file:line | % as written | denominator written |
  denominator correct | verdict | fix |`.
- Counts: total percentages, PASS, FAIL by kind, stale.
- A short list of the FAILs grouped by the kind, with the fix
  proposed for each.
- A "no false negatives" line: the worker has looked at every
  `docs/research/*.md` and named every percentage found, not just
  the suspicious ones.

**Calibration (mandatory).** The worker must include at least three
**known-good** rows (e.g. the 21.32% / 21.33% reconciliation in the
chainability doc, where the denominators are correct) and at least
three **known-bad** rows from the *prior denominator confusion*
described in the chainability doc's "Reconciliation" section, with
verdict FAIL. A worker who finds zero FAILs has either missed them
or has a different definition of "stated denominator" than the
project — both are findings to report, not a clean sweep.

**EVIDENCE:** `docs/evidence/GLOBAL.DENOMINATORS/sweep-2026-07-28.md`
plus a `PROVENANCE.md` (per `docs/evidence/README.md`) listing the
files read, the runs, the commit hashes.

**Do NOT** edit `docs/research/*.md`. This is an audit; the fixes
are separate work for the owners of each file.

**Report shape:**
- The summary table (above).
- The PASS/FAIL counts and the kind breakdown.
- A short paragraph on what the FAILs have in common
  (single-goban vs cross-goban; L==H vs ko-sensitive; etc.).
- An "honest negatives" paragraph: percentages the worker
  judged borderline and left alone, with the reason.
