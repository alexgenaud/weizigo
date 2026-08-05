# Race 3 · Packet R3-P2 — "the frozen reference"

*Exam item for EPISTEMIC-RACES race 3 (prior-art mapping). Below is a plain-language description of a method the project uses. Identify the literature: the established name of the method, the canonical citation, and what the literature offers that the project has not imported.*

---

## The description

When a program is being refactored or re-derived, the correct output is often too expensive
to recompute from scratch on every change — but you still need to know the new version behaves
like the old one. So: freeze the output of the known-good version as a reference file. After
every change, run the new version and compare its output byte-for-byte against the frozen
reference. Any difference is an unintended behaviour change, flagged immediately, without
having to recompute what "correct" means. The project uses this as a gate inside its test
suite: the frozen reference stands in for ground truth that would be too costly to recompute
per commit.

## Task

1. **Name the technique** (the established literature name) and give the canonical citation
   (the book that introduced it).
2. In 2–4 sentences: what does the literature offer that the project has not imported?
