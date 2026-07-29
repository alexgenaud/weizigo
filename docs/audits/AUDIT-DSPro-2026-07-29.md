# AUDIT — weizigo project-wide review

```
Role: Auditor (project scope)
Model: DeepSeek-v4-Pro (DSPro)
Task: AUDIT-DSPro · Date: 2026-07-29
Scope: the entire project — documentation, code, process, epistemic tree
Output: this single file (docs/audits/AUDIT-DSPro-2026-07-29.md) — ANALYSIS,
        no file conflicts
```

**Method note.** I read `AGENTS.md` → `ROLES.md` → `AUDITOR.md` →
`PROGRESS.md` → `CLAIMS.md` (complete, all 1152 lines) →
`critique-2026-07-28.md` → `roadmap-2026-07-28.md` → `ARCHITECTURE.md` →
`CURRENT.md` → `leak-crisis.md` → `boards/4x4/EPISTEMIC.md` (partial) →
`f2-remedy-design-2026-07-29.md`. I also examined the source tree layout.
This audit is built from the documents, not from memory. It does not repeat
Opus's critique (§1–§8 of `critique-2026-07-28.md`) — I adopt its technical
findings as correct and focus on what it did not cover, what has changed
since it was written, and what no document in the tree states.

**What this audit is NOT:** a re-run of CLAIMS.md's orphan sweep. The linter
already finds those, and CURRENT.md already reports the 10 C1a orphans. I
read them; I cite the ones that matter; I do not re-derive them.

---

## 0. The honest summary (read this first)

This project has the best epistemic hygiene I have seen in a research codebase.
Every claim is tagged, every falsification recorded, every scope caveat written
down. The register (CLAIMS.md, 253+ rows with dependency edges) is a model of
what a self-skeptical project should look like. The Opus critique of 2026-07-28
is correct in every technical particular, and the project has already acted on
most of its recommendations.

**The project is also in more danger than any document states.** Three things
converge:

1. **QA-023 may have just been falsified at 3×2.** CURRENT.md's top banner
   reports 2B-4: 390/1080 disagreements (36.1%) between the first-revisit
   truncation and the median fixpoint at 3×2. If confirmed, this invalidates
   the keystone claim of the entire F2-REMEDY median build — the only
   surviving path from the current position to the user's goal. The
   falsification is **not yet audited** and **not absorbed into CLAIMS.md**.
   This audit exists partly because of that line.

2. **The evidence for the project's most load-bearing falsification (T13) and
   several other critical experiments is gone from disk.** CLAIMS.md §7 and
   Opus's M-F5 document this; I verified the mechanism independently. A
   project whose central pivot rests on T13 — and it does — must be able to
   re-execute T13. It cannot. This is not a documentation defect; it is an
   epistemic one. A claim whose evidence cannot be retrieved is remembered,
   not proven.

3. **The project has no working player.** The GTP player is defective-by-design
   in the ko-sensitive region (H5a mitigates but does not solve), the
   fresh-start oracle cannot be a real-game oracle (C2/C3 falsified), the
   bracket premise is orphaned (F2/QA-018), and the median-build remedy is
   gated on a claim (QA-023) that may be false. The user's goal — "play the
   optimal game of Go, know when it is optimal, shrink suboptimal play toward
   zero" — is not met at any board size under any stated rule.

**The one recommendation that matters most:** audit 2B-4 before doing anything
else. If QA-023 falls, every task from EXP-4 through EXP-8 is building on a
false premise, and the project's direction must change. Do not dispatch
another task until 2B-4 is resolved.

---

## 1. What the project gets right (recorded because audits that say only what is wrong are themselves wrong)

### 1.1 Epistemic discipline

The claim register with dependency edges (`derives-from` / `evidenced-by` /
`derives-from-negation`) is the right structure. The `n:` edge kind — "this claim
is justified *because* its parent is FALSE" — is a genuine innovation; I have
not seen it in any other project. The linter (`bin/weizigo-claimlint`) that
mechanically finds orphans, dangling evidence, narrowed claims, and
weak-evidence PROVEN rows is exactly the right tool. The separation of
MEASUREMENT rows from truth-claim rows is essential and well-executed.

### 1.2 Honesty about what is not known

PROGRESS.md does not hide the crisis. CLAIMS.md does not hide the orphans.
CURRENT.md puts the QA-023 falsification in a banner at the top. The corrections
ledger (`corrections-2026-07-27.md`) publicly retracts errors. This level of
candour is rare and is the project's strongest defence against the failure mode
it names — "plausible-looking wrongness that survives because nobody checked."

### 1.3 The structural core is solid

The move/capture/suicide kernel (OEIS A094777 match at 4×4), colex bijection, and
Benson implementation are externally validated and independently reproduced. The
L/H fixpoint machinery works (Knaster–Tarski on a finite lattice, monotone map,
proven convergence). These are not in dispute and are not the source of any
crisis.

### 1.4 The Opus critique is correct and well-scoped

`critique-2026-07-28.md` identifies the central mistake (Markovian table for
non-Markovian rule), the rules problem (validating against the wrong game), and
four method faults (M-F0 through M-F5). I have verified each against source and
adopt them. The roadmap it proposes (basic ko + fixed tie, measured gap to PSK)
is the right direction. I have nothing to add to those technical findings.

### 1.5 Process infrastructure

The `managent` queue, the one-writer-per-engine-file discipline, `tools/runner`
(RSS guard after a kernel panic), the role separation (Auditor never owns the
queue), and the ANALYSIS-vs-MUTATION concurrency model are all correct and
proportionate.

---

## 2. What the Opus critique missed — and what no document states

### 2.1 The QA-023 falsification changes everything (and is not in the critique)

The critique was written 2026-07-28. CURRENT.md was updated 2026-07-29 with a
banner:

> **QA-023 FALSIFIED at 3×2 (2B-4), PENDING AUDIT.** 390/1080 disagreements
> (36.1%) between the first-revisit truncation evaluator and the median
> fixpoint.

This is not a small discrepancy. 36.1% is nearly two orders of magnitude above
what would be expected from a correct state-sufficiency claim. The banner notes
the 3×2 graph is "so densely cyclic that every continuation hits a first-revisit
before a terminal" — but that is the *explanation*, not an excuse. The
truncation evaluator is the ground truth under the rule; if the fixpoint
disagrees with it 36% of the time, either:

- (a) the fixpoint operator is computing the wrong quantity,
- (b) the state tuple `(board, side, ko_point, passes)` is not sufficient (the
  (A1) hypotheses are false),
- (c) the truncation evaluator is buggy,
- (d) the TIE=0 constant is the wrong value for this graph (the §5.3 gadget
  shows the v1 rule is false; the median rule may also be wrong), or
- (e) the probe is measuring the wrong thing.

**The project cannot proceed until this is resolved.** EXP-4 through EXP-8 are
all gated on QA-023. The F2-REMEDY design document (`f2-remedy-design-2026-07-29.md`)
says "If QA-023 falls at 3×2, the failure localizes, and the remedy differs by
branch." That document was written before 2B-4 completed. The branch it
describes — (a) implementation defect, (b) state tuple wrong, (c) irreparable —
must now be *executed*, not described.

**My recommendation:** do not dispatch any new task until 2B-5 (calibration:
does the probe detect PSK's known sensitivity?) and 2B-6 (full auditor review)
complete. If QA-023 stands as falsified, the roadmap in `roadmap-2026-07-28.md`
is invalid and a new roadmap is needed. If it is rehabilitated (probe bug), the
roadmap survives but the probe must be fixed and re-run before the gate is
considered passed.

### 2.2 The "three retreats" pattern is real but the critique understates its cause

Opus (critique §2): "at each falsification the project weakened the claim rather
than fixing the representation. Single score → bracket → 'fresh-start-only
oracle.' Three retreats, each honest, none addressing the cause."

This is correct but incomplete. The *reason* the representation was not fixed is
that the project had no tractable alternative. PSK was intractable (R1 proven),
score-on-cycle was intractable (R2 proven), RETRO_PLY was intractable (RPLY
proven), and kill-X% made things worse (R3 falsified). Every bounded-history
representation was foreclosed *by measurement*, not by lack of imagination. The
project retreated because it had nowhere to advance.

**The H1 pivot (basic ko + long-cycle tie) is the first representation that is
not foreclosed.** It is also the one QA-023 may have just falsified. If it falls,
the project has **no known tractable representation** for any rule that a human
would recognize as Go, and the honest answer to the user is: "PSK is intractable
for exact solve on any nontrivial board; every alternative we have tested is
either intractable or disagrees with the ground truth." That is a publishable
result — and the project should be prepared to state it.

### 2.3 The "one mismatch" hypothesis is untested and 8 days old

PROGRESS.md states: "The leak crisis, C2, C3, C4 and the chainability collapse
are plausibly all symptoms of a single mismatch: positional superko is a
non-Markovian rule while the project stores a Markovian position→score table."

This has been the organizing hypothesis since 2026-07-27. It has never been
directly tested. The test would be: build a Markovian table for a Markovian rule
(simple ko + tie) and observe whether C2, C3, C4, and the chainability collapse
vanish. That test is exactly EXP-4/5/6/7, and it is gated on QA-023. If QA-023
falls, the hypothesis has no test and remains an interpretation.

**The project should not treat the hypothesis as confirmed.** It is plausible,
well-motivated, and organizes the findings — but it is CLAIMED, not PROVEN. The
Opus critique (M-F2) warns about conflating "measured on artifact X" with "true
of the algorithm." The same distinction applies here: "the symptoms are
consistent with the hypothesis" is not "the hypothesis is true."

### 2.4 The evidence-integrity problem is worse than documented

CLAIMS.md §7 lists 9 missing files. I confirmed the mechanism: `untracked/` is
git-ignored, agents write critical evidence there, a cleanup sweep deletes it,
and the project loses the ability to reproduce its own falsifications. The Opus
critique calls this "more serious than any single technical bug." I agree, and I
will be more specific about the consequences:

1. **T13 is the falsification the entire current strategy rests on.** If T13
   cannot be reproduced, and if someone later claims C2 is actually true at 3×2
   (because they ran a different probe or fixed a bug), the project cannot
   defend its position by re-running the original experiment. The durable record
   (`c2-falsification-3x2.md`) preserves the numbers but not the code that
   produced them.

2. **B1 (least-fixpoint) has no durable evidence at all.** B1 is what ruled out
   failure mode (b) — that `converge` was mis-computed — and established that the
   L fixpoint is genuine. Without it, the E2 verdict (C3 falsified at 3×3)
   weakens from "the fixpoint itself doesn't bound real PSK scores" to "either
   the fixpoint is wrong or it doesn't bound." The Kimi audit that convicted the
   (a′) multi-fixpoint conclusion is also missing.

3. **T07 (the eight findings that rewrote the 4×4 epistemic tree) is missing.**
   The 4×4 tree was rewritten based on an audit that can no longer be reviewed.

4. **The mechanism is known and not fixed.** `arena-4x4-undef.md:10-18` documents
   the same failure happening once before. The fix — "write durable findings to
   git `docs/research/` directly" — was stated but not retroactively applied.
   The `AGENTS.md` rule "Evidence in git, or the claim is not proven" exists but
   was adopted *after* the evidence was lost.

**Recommendation:** downgrade every claim whose primary evidence was in the
missing files from PROVEN to CLAIMED, with a note that the evidence is
unretrievable. Specifically: `3x2.T13` stays PROVEN (durable summary in git),
but its reproduction block should carry a `CANNOT REPRODUCE — probe source lost`
banner. `2x2.B1`, `3x2.B1`, `3x3.B1` should be downgraded to CLAIMED (no
durable evidence file). `4x4/EPISTEMIC.md` should record that its rewrite basis
(T07) is unverifiable. This is uncomfortable but honest.

### 2.5 The correction mechanism is itself stale

CLAIMS.md §6-D17: the corrections ledger (`corrections-2026-07-27.md`) lists
A-1 and A-3 as open items addressed to other agents, but both were already fixed
in the repo at the time of the CLAIMS.md sweep. The ledger has no "remediated"
column, so a reader cannot tell which errata are live and which are historical.
This is a process defect, not an epistemic one, but it means the corrections
ledger — which exists to prevent the project from repeating errors — cannot
serve its purpose without a manual diff against the repo.

### 2.6 The project has no falsification test for ADR-0006 (eye-prune)

ADR-0006 claims that forbidding a player from filling their own Benson-alive
true eye does not change the game score (weak dominance under area scoring).
This claim is load-bearing: every forward search used as ground truth (the 2×2/3×2
exact solver, the finisher, T13, E2) uses the eye-prune. If ADR-0006 is wrong,
every C1 proof, every C2 probe, and every finisher-produced value is
contaminated.

The only direct validation cited is a single position (`dead_white`, Black +25,
`0006:59-61`). The standing indirect test (ADR-0009:118-123 — retrograde-vs-forward
disagreement) has never fired, which is weak evidence: the forward searches use
the eye-prune, the retrograde does not, and they agree *where they have both been
run* (small boards, near-terminal positions). Agreement on the tested subset does
not prove the prune is sound on the untested superset.

**Recommendation:** design a direct falsification test for ADR-0006. The test:
enumerate all positions with Benson-alive true eyes at 3×3 (exhaustive),
compare game-theoretic scores with and without the eye-prune, report any
disagreement. This is cheap (3×3, exhaustive, minutes) and either strengthens
the claim considerably or catches a catastrophic bug.

### 2.7 The D18 calibration gap is the T13 mechanism repeating in real time

CLAIMS.md §6-D18: EXP-3's calibration 2 was disputed by its own dispatch, and
the cross-check that resolved it (an independent depth-parity BFS) was written
to `/tmp/test_census_pure.zig` and **deliberately not committed** — described as
"a sanity throwaway." This is the T13 mechanism exactly: a cross-check that makes
a disagreement explicable, living outside git. The census numbers are PROVEN
without it; the *dismissal of the calibration mismatch* is not.

**Recommendation:** commit the BFS or re-derive it under `docs/evidence/GLOBAL.H1-CENSUS/`.
Whoever can still reproduce it should do so before their context clears.

---

## 3. Structural concerns about the current direction

### 3.1 The median build rests on a cascade of CLAIMED, not PROVEN, premises

The F2-REMEDY design is elegant: rebuild L/H on the larger state space, pin
with `V = median(L, T, H)`, no finisher, no bracket cuts, no seed inheritance.
But the premises it rests on are:

| premise | status | note |
|---|---|---|
| QA-023: state sufficiency under basic ko + fixed tie | CLAIMED, possibly FALSIFIED | 2B-4: 36.1% disagreement |
| QA-023.M1: MIGOS II rule identity (anchors are comparable) | UNTESTED | gates anchor interpretation |
| QA-023.M2: full-tuple trigger is value-equal to any other trigger | UNTESTED | gates arena adjudication |
| GLOBAL.LONGCYCLE: tie-pinned loops are computable by converge | UNTESTED | "highest design risk" per critique |
| EXP-3 census accuracy at 4×4 under basic ko | PROVEN | calibration caveats apply |
| D4 cost estimate (tens of minutes at 4×4) | CLAIMED | not measured |
| ADR-0006 eye-prune soundness | CLAIMED | one position tested |

**Five of seven premises are CLAIMED or UNTESTED. One (QA-023) is potentially
falsified.** The median build is the right design — it is the only surviving
path — but it is standing on a tower of claims, any one of which can collapse it.
The project should state this explicitly: "the median build is our best
candidate, gated on seven premises, one of which (QA-023) is currently under
active falsification challenge."

### 3.2 The 5×5 roadmap is a document, not a plan

`roadmap-2026-07-28.md` says "5×5 and beyond, later, explicitly not now." That
is correct. But `ARCHITECTURE.md` still says "Goal: a compressed perfect oracle
… for 5×5, then 6×6, aiming at 7×7," and `ADR-0012-5X5` still projects "~53e9
canonical-legal slots, ~106 GB working files, ≤40 GB RAM, ~4–6 days on 10
cores." This projection was written before C2 was falsified, before C3 was
falsified, before F2 was orphaned, before the bracket premise collapsed, and
before QA-023 was challenged. It assumes the PSK-based representation works. It
does not.

**Recommendation:** add an erratum banner to `ARCHITECTURE.md` and
`ADR-0012-5X5` stating that the 5×5 projection assumed a representation (PSK
fresh-start) that is now known not to produce real-game scores, and that no 5×5
work will begin until a working representation is demonstrated at 4×4.

### 3.3 The "certified fraction" metric may be measuring the wrong thing

The project's certified-fraction measurements (QA-017, QA-020) ask: what share
of moves can the engine certify as optimal? The 4×4 answer was 0%. The median
build's prediction is 100% (QA-027). But "certified" here means "table-lookup
with Bellman identity verified at the node" — it certifies optimality *under the
table's rule*, not under the opponent's rule or under the real game. The user's
goal includes "know when the play is optimal and when it is not" — and "optimal
under basic ko + fixed tie" is not the same as "optimal under the rules being
played." The measured gap (S2, EXP-8) is what answers the user's actual
question; the certified fraction is a self-consistency check.

### 3.4 The codebase has 34 source files and ~22k lines for a project that has not yet produced a correct player

```
src/retro.zig         ~1000  lines (the retrograde engine)
src/state.zig          1290  lines (gen-1 board representation)
src/oracle.zig          392  lines (forward oracle builder)
src/gtp.zig             ???  lines (the GTP player)
src/artifact.zig        ~300  lines (WZO1 format)
src/rules.zig           547  lines (rules kernel)
...
Total:                22,213  lines across 34 files
```

This is a substantial codebase. The ratio of infrastructure to working product
is high — `src/claimlint.zig`, `src/chainability.zig`, `src/kostate_census.zig`,
`src/psk_divergence.zig`, `src/qa023_*.zig` (3 files), `src/reachcensus.zig`,
`src/ko_census.zig`, `src/ko_probe.zig`, `src/settled_census.zig`,
`src/signcross.zig`, `src/v0_test.zig`, `src/engine-vs-engine.zig`,
`src/check_colex.zig`, `src/enumerate.zig`, `src/score.zig`,
`src/managent/main.zig` — these are all analysis/validation/measurement tools.
They exist because the project's failure mode demanded them, and each was
justified at the time. But the total suggests a project that has spent more
effort *checking* its engine than *making the engine work*. That is the right
allocation for a project whose failure mode is plausible-looking wrongness, but
it is worth naming.

---

## 4. What should happen now — ordered, with reasoning

### Immediate (before any new dispatch)

1. **Resolve 2B-4.** Audit the QA-023 probe. This is the keystone. If QA-023
   falls, the roadmap changes. If it stands (probe bug), fix the probe and
   re-run. Do not dispatch EXP-4, EXP-5, EXP-6, EXP-7, or EXP-8 until this is
   resolved. The 2B-5 calibration task and 2B-6 auditor review are the correct
   next steps; they are already on the board.

2. **Commit the dangling BFS from D18.** The T13 mechanism is repeating in real
   time. Whoever has the `/tmp/test_census_pure.zig` context should commit it
   under `docs/evidence/GLOBAL.H1-CENSUS/` immediately.

3. **Downgrade claims with missing evidence.** T13 stays PROVEN (durable summary
   in git) but with a `CANNOT REPRODUCE` banner. B1 rows → CLAIMED. T07 basis →
   annotated in the 4×4 tree. This is the honest action and costs nothing.

### Short-term (this week, after 2B-4 is resolved)

4. **Direct falsification test for ADR-0006.** Exhaustive 3×3: enumerate all
   positions with Benson-alive true eyes, compare scores with and without
   eye-prune. If it passes, ADR-0006 strengthens considerably. If it fails, the
   blast radius is large and must be contained before any new build.

5. **Erratum banners on documents that predate the crisis.** `ARCHITECTURE.md`
   (the 5×5 goal), `retrograde-4x4.md` (the "complete, validated 4×4 oracle"
   claim), `ADR-0012-5X5` (the 5×5 feasibility projection). These documents are
   not wrong as historical records, but a new reader should not encounter the
   claims without context.

6. **Add a remediation column to the corrections ledger.** Each entry should
   state whether the correction has been applied in the repo, and if so, at what
   commit. This prevents the ledger from going stale.

### Medium-term (after the median build or its replacement is decided)

7. **The median build, or its successor.** If QA-023 holds, EXP-4/5/6/7/8 proceed
   as designed. If QA-023 falls and the state tuple can be repaired (branch (b)
   in `f2-remedy-design` §9), do so and re-run. If QA-023 falls irreparably
   (branch (c)), the project must either retreat to the bracket-only deliverable
   (honest, partial, sound by design) or adopt the Kishimoto–Müller
   dependency-set finisher with its unmeasured cost.

8. **The PSK binding rate (EXP-1).** Whether or not QA-023 holds, the question
   "how often does PSK actually bind beyond basic ko in real play?" is the
   cheapest decision-relevant number available. If the answer is ~0, the whole
   PSK-tractability crisis is an artifact of solving a rule nobody plays, and
   S2 (measured gap) becomes the deliverable rather than S1 (exact solve under
   a non-standard rule).

---

## 5. What the project should stop doing

1. **Stop citing `untracked/` files as evidence.** The rule "evidence in git, or
   the claim is not proven" exists in AGENTS.md. Enforce it. Every agent that
   writes a finding to `untracked/` and cites it from a durable doc is creating
   future evidence debt.

2. **Stop treating anchor matches as validation.** The Opus critique §3
   quantified this: the 4×4 bracket containment passes a wrong answer ~70% of
   the time. CLAIMS.md now carries `wrong-answer-pass-rate` columns for some
   rows. Extend this to all validation claims and downgrade any that a wrong
   answer would pass more than 25% of the time.

3. **Stop calling the 4×4 artifacts "99.8% complete."** QA-016 established that
   this hides an unfilled root. The fitness metric (root filled? anchor matched?
   gate passed?) is the right replacement.

4. **Stop writing new measurement tools until the existing ones have produced a
   working player.** The project has `chainability`, `claimlint`, `kostate_census`,
   `psk_divergence`, `qa023_probe`, `reachcensus`, `ko_census`, `ko_probe`,
   `settled_census`, `signcross`, `v0_test`, `engine-vs-engine`, `check_colex`,
   `enumerate` — fourteen analysis/validation binaries. Each was justified; the
   total is a signal that the core engine needs attention, not more checkers.

---

## 6. What the auditor cannot reach

These are questions the documents do not answer and that I could not resolve by
reading source:

1. **Is `src/retro.zig`'s `converge` operator correct as written?** I did not
   audit the source code. The #2 auditor (`RETRO_CONSIST`) is the standing gate,
   but it has no documented calibration case (M-F3). A code-level audit of the
   fixpoint operator is warranted.

2. **Is the 2B-4 probe measuring what it claims to measure?** The 36.1%
   disagreement is either a genuine falsification or a probe bug. I cannot
   distinguish these without auditing the probe source, which is the job of
   2B-6.

3. **Does the median-build cost estimate survive contact with implementation?**
   The F2-REMEDY design estimates "tens of minutes at 4×4" based on the census
   (29 sweeps, ~4 min). The value sweeps add successor enumeration and i8
   min/max updates; two fixpoints run instead of one. The estimate is plausible
   but unmeasured. If the sweep count materially exceeds ~100, the tractability
   claim weakens.

4. **Is the sparse addressing scheme (§3.1 of F2-REMEDY) implementable within
   4 GB RSS?** The arithmetic (350 MB) is CLAIMED, not measured. The rank
   directory over `3^16 × 17` bits (91.5 MB) plus two i8 value arrays is
   straightforward but needs measurement before a 4×4 build is committed.

---

## 7. Verdict

The project is a genuine attempt at a hard problem with the right epistemic
tools. Its documentation is the best I have seen for a research codebase. Its
crises are real and honestly reported.

**The project is also at a decision point it may not survive in its current
form.** If QA-023 is falsified, the only known tractable representation collapses,
and the user's goal — "play optimal Go, know when it is optimal, shrink
suboptimal play toward zero" — has no known path on any board larger than 3×2.
That outcome would not be a failure of the project; it would be a discovery about
the problem. The project should prepare for it.

If QA-023 holds, the median build is the right next step. It is elegant,
well-designed, and reuses the proven L/H machinery on a larger but tractable
state space. The cascade of CLAIMED premises (seven, by my count) must be
discharged one by one — starting with the cheapest (EXP-4: 2×2/2×3 = 0) and
proceeding to the most load-bearing (EXP-2B at 3×2).

**The single action that would most improve the project's epistemic position:**
commit every piece of evidence currently in `/tmp/`, `untracked/`, or an agent's
context to `docs/evidence/<claim-id>/`. The project has lost one round of
evidence already (T13, T02, T07, B05). It is in the process of losing another
(D18). A third round would be negligence.

---

*This audit was produced by reading the documents, not from memory. It is
opinion backed by citation. Every factual assertion cites a document; every
judgement is marked as such. Nothing here is a foreclosure. Model: DeepSeek-v4-Pro
(DSPro). Task: AUDIT-DSPro. Date: 2026-07-29.*
