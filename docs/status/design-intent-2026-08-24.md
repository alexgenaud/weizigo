# Design intent and evidence provenance — outgoing seat, 2026-08-24

**Why this file exists.** Everything else the outgoing seat wrote is *what happened*. This is *why
it was built that way* and *how far each number can be trusted* — the two things that live only in
a console's head and vanish when it closes. A fresh reader would otherwise grade the in-flight
races incorrectly, because their design carries assumptions their briefs do not state.

---

## 1. The in-flight races: what each was actually testing

### RACE-X (T807/T808/T809 → graders T810/T811/T812) — audit the S06 spec
**Not a normal audit race.** Its answer key is **the spec's own claim about itself** — that 22 of 31
requirements were armed. Arms are files, so the claim is checkable without planting defects. That
design was chosen because seeding fake defects into a live spec would corrupt the thing six passes
were about to build on.

**Grade it on recall against that key, not on finding count.** Independent hand-censuses by two
entrants *and* a grader agreed on **12 of 37**, against a claimed 22 of 31. The convergence is the
result; the individual findings are secondary.

**Contaminated mid-flight, and the contamination is informative.** The oversight seat dispatched
T813 to amend the same spec *while the race was auditing it* — the same error class as the repair
row that erased Race G's canaries. The dsflash entrant **detected the subject had moved and adapted
rather than auditing a stale target**, and a grader ranked it first for that. **Do not penalise
entrants for disagreeing about a spec that changed underneath them.**

### The diff race (T826/T827/T828/T829/T831 → judge T832) — `dispatch_verify`
**The point is the mechanism, not the patch.** Entrants write a *patch* against a pinned commit
instead of editing the file, so six models can work one file with zero conflict. This is what makes
`implement` raceable at all — 11% of task volume, and the matrix cell was empty because three
earlier attempts had to use three *different* bugs.

**The gate predates the race**: 172 arms written by T793 before the race existed, two already red as
recorded defects. So a patch cannot be graded against arms written to fit it. **Breaking a green arm
must outrank elegance**, and a patch touching the test file is disqualified — diff the test file for
every entrant, including the well-behaved ones.

### The rate race (T838–T842 → judges T843/T844) — the dashboard
**Judged twice, and the second reading is the operator's.** He said he would smoke-test the rendered
output himself and that his reading counts *retroactively*. So the judges were told to paste every
frame verbatim and **name the hinge** — which of their rankings would change if he dislikes a
specific presentation choice. A ranking that cannot absorb his verdict without a re-grade has failed
its job. **Do not re-run the grade when his verdict arrives; apply it to the hinges.**

Three ollama entrants died on the window cap. **glm delivered a patch and then died** — preserved at
`untracked/ratrace/T840.patch.delivered-before-death`. Judge what exists; a partial field is still a
field.

### The corpus three-way (T817/T818/T820 → T819)
**T817's brief deliberately differs.** Flash was told to *start from* `model-profiles.py`'s keyword
classifier and beat it; oxalpha and dspro were told to build their own method, and their briefs are
**byte-identical to each other**. So:
- **T818 vs T820 is a clean two-model comparison.**
- **T817 is a separate experiment**: does seeding from the existing classifier help, or anchor you to
  its mistakes?

Grading all three as one field would answer neither question. T817 measured its brief-aware
classifier at **100% against the legacy classifier's 78%** on a held-out set — meaning every
task-type number this project has published rests on the 78% version.

### Race W re-judge (T780–T783 → T784)
Section A leans opus 3-of-4 **with one exact tie, and a tie counts as non-unanimous**. Section B is
2–2. Any split escalates to the operator's own panel. Worth preserving: the original non-blind grade
had T755 winning both sections **and its judge was T755**. The blind re-run does not reproduce that.

---

## 2. Provenance of the outgoing seat's numbers

**Verified twice or derived mechanically — trust these:**
- 448 token readings recovered; coverage 127 → 575 (parser reproduced dispatch-time truth **54/54**;
  attribution had **0 model conflicts over 160** run records).
- 300+ unit arms at 0.172 s; the suite at 112/122 steps, 1344/1348 tests, 906 s.
- C2 dangling citations 13 → 0.
- `FLEET_CAP`/`FLEET_FAMILY_CAP` absent from `bin/dispatch` (grep count 0) — and the fix demonstrated
  by the cap refusing the seat's own dispatch.
- The two git guards, both shown red-then-green against a seeded poisoned config.
- 16 of 20 host-guard kills futile, 0 of 20 necessary-and-effective (T806's census, not the seat's).

**Measured once, from a mutable shared surface — re-check before acting:**
- Every deliverable-presence figure. The seat's first two attempts were wrong (a regex breaking on
  hyphens, then a stale index read). The corrected reading was **65 absent paths of 429 tasks, of
  which 37 are one unrepointed directory rename** — but it was taken once.
- Any `git status` or `git ls-files` reading. Three were confidently wrong today.
- The 92%-pass / 4-`fail-found` ratio: derived from the store *after* the revert, so the denominator
  may be short.

**Reported by others, not verified by the seat:**
- The quota figures (operator's console), T806's kill census, T817's classifier accuracy, and every
  race grade.

---

## 3. Lessons, in order of how much they cost

1. **We built the thing that broke us.** The test gate wired into pre-commit ran regression scripts
   that `git init` scratch repos; `GIT_DIR` leaked; the repository was repointed and 59 tasks
   vanished. The safety mechanism was the attack vector. **Every new gate should be asked: what does
   this run, and with what environment?**
2. **A number nobody can derive is a number nobody should trust.** `total // 8` had no provenance
   beyond "an eighth of RAM felt safe" and drove 20 kills, 16 of them futile. Five more unexamined
   constants remain (`MEMORY_GATE_MARGIN_MB` 2048, `FALLBACK_COOLDOWN_SECONDS`, `ARM_FRESHNESS`,
   `--poll-ms` 250, `MAX_DEPTH` 3).
3. **Two doors, one gated, is the master defect.** It appeared five times in one day: dispatch
   paths, close paths, appetite read only by `assign`, caps read only by the keeper, canonicalizers
   in four copies. **The convenience path is always the one that loses data, because the gate is
   where the data is demanded.**
4. **Absence of a signal is not absence of a problem.** 1,476 kill events lived only in gitignored
   state; the one tracked kill ledger held zero. The store shrank by 59 tasks with no alarm. **Ask
   of every surface: if this were wrong, who would notice, and how?**
5. **The instruments need the same scepticism as the code.** The seat produced three wrong readings
   in ten minutes *while investigating silent failure*, from a census that read shared mutable state
   without locking. A tool that reports absence is making a claim and needs a control.
6. **Verification is not optional at speed.** Roughly thirty dispatches in one day, and the two worst
   errors — moving `main` onto a truncated tree, and the appetite claim — were both acts taken on
   unchecked readings. **One worker finishing beats three started.**
7. **The ratio worth watching.** Across T500–T700: 70% of file touches were documents and records,
   **7% product source**. Six themes of infrastructure to one of product. The apparatus for doing
   the work outgrew the work.
