# Multi-phase sprint process — review (oracle-v2 as case study)

```
Author:   Fable/Navigator (claude-fable-5) · 2026-07-31
Scope:    the spec → strategy → design → audit → gate process itself,
          using oracle-v2 (pass0/ + pass1/, T132–T150) as the evidence base.
          Not a review of the WZO2 format — that is the audits' job.
Status:   ADVISORY — process observations for the human; no doc it names
          is blocked on it
```

## 0. Summary

The process caught four defects that would have shipped and cost wall-clock
sessions or a re-solve: a spec that forbade its own solver (pass-0 F1), a
file layout specified two incompatible ways (BLOCKER-1), a depth-to-terminal
(DTT) definition that collapsed to two distinct values (BLOCKER-2), and a
re-scope request that a one-byte schema change made unnecessary (CRITICAL-2).
Each was exactly the failure mode the project has already paid for once —
two agents implementing a frozen contract that says two different things.
The process earned its cost in rounds one and two.

It then failed to stop. Round three of the design audit found one real
finding (a unit typo), one phantom finding (a MUST filed against a bullet
point that exists in the file), and re-verified work already verified. The
loop converged numerically — 21 findings → 5 → 3 — but nothing in the
process itself was capable of declaring convergence. Termination required
stepping outside the loop.

The root causes are structural, not personal to any model, and all are
fixable with small rule changes. They are listed in §4.

## 1. What the process is

For the record, since oracle-v2 is its first full exercise:

1. **Spec** states requirements and falsifiable acceptance criteria; it does
   not choose designs. Audited fresh-seat, then human-ratified (G1).
2. **Strategy** turns the spec into a task graph with gates, holds, and
   falsification conditions. Audited.
3. **Design** (per module) chooses the layout/encoding/algorithm and derives
   the budgets the spec demanded. Audited, revised, re-audited until PASS,
   then human-ratified (G2) and frozen as the implementation contract.
4. **Implementation** proceeds against the frozen contract in parallel
   lanes; acceptance (A-criteria) is the final gate (G3).
5. Frozen snapshots of each audited text live in `docs/design/<sprint>/passN/`
   so audit line references stay resolvable while the live doc revises.

## 2. What went well

- **Falsifiable specs with honest baselines.** Every acceptance criterion
  states what a *wrong* answer scores, and criteria today's artifact passes
  trivially are marked as proving nothing. The pass-0 auditor spot-checked
  the claimed v1 scores against the code and found none padded. This
  discipline is worth keeping verbatim in every future spec.
- **Pre-committed negative results.** The spec commits to publishing "A1
  does not improve" as the headline result if the diagnosis is wrong. That
  single sentence is what makes the sprint science rather than advocacy.
- **The audit chain caught real, expensive defects early.** Pass-0 F1
  (BLOCKER: the module ownership rules made the solver unreachable) was
  caught before any design work. Design-audit round one caught BLOCKER-1/2
  and CRITICAL-1/2 before M2b/M3 were dispatched to separate agents. The
  cheapest point of repair was hit every time.
- **Independent re-derivation beats checking arithmetic.** The O-4 auditor
  did not verify the design's byte budget — it re-derived the budget from
  primary sources (`4x4-standard.txt`, `exp6_solve.zig:1113`), which is how
  it found that G and N were both already measured, that the claimed range
  was wrong in both directions, and that a 1-byte schema change cleared the
  ceiling the design wanted to raise. Auditors should re-derive, not re-add.
- **Fresh seat + different model worked.** The strongest audits (O-4, T146)
  came from a different model than the author, with less context, exactly as
  `DELEGATOR.md` rule 5 intends. The T146 diagnosis of the A-numbering
  collision — "the revision read the verify-battery spec for its I-numbers
  and did not read oracle-v2 spec §4 for its A-numbers" — is the kind of
  cross-document forensics a fresh seat does better than an author.
- **Graded findings + disposition logs made progress measurable.** The
  blocker/critical/must/should/could taxonomy and the §11 audit-resolution
  log meant every round could be scored: 16 of 21 resolved, then 5 of 8.
  Without that, "are we converging?" would have been unanswerable.

## 3. Where it went wrong

### 3.1 No severity valve at the gate

Any MUST forces NEEDS-FIX, and NEEDS-FIX forces a full revise-and-re-audit
cycle. "§5.3 says 378 MB where it should say 397 MB" received the same
machinery as "the DTT column is mathematically meaningless." By round three
the loop was running because no rule told it to stop: the process has
PASS / NEEDS-FIX / REDO, and nothing between PASS and NEEDS-FIX.

### 3.2 Partial revisions regenerate the loop

Rev 1 resolved 16 of 21 findings but rebuilt §7.1 from the wrong upstream
document. Rev 2 resolved the five findings its brief apparently enumerated
(the hard DTT mathematics — done correctly) and silently skipped the open
CRITICAL and a MUST, while its header claimed "T146 re-audit addressed."
Each partial revision guarantees a full further cycle. The failure is in
the brief contract: "address the audit" under-delivers; an enumerated
work-list is treated as complete even when it is not the whole audit.

### 3.3 Auditors under pressure to find something

The phantom finding (RV2-1, a MUST asserting §2.3 lacks a "DTT = 0" bullet
that is present in the file) appeared in round three, precisely when the
real defects ran out. An auditor whose only respectable outputs are
findings will eventually manufacture one. A PASS with zero new findings
must be an explicitly acceptable — praised, even — audit outcome, and every
finding must be verified against the current file text before filing.

### 3.4 Bare numbers as cross-document foreign keys

The A-numbers and I-numbers are load-bearing references across four
documents and several dispatched briefs, with no checker. Two independent
collisions resulted: the design's §7.1 renumbered the spec's A-series
(CRITICAL, survived two revisions), and the spec's own A6 references
"A1–A5" where the zeroed-DTT corruption can only fail A8 (NEW-6). Numbering
collisions are invisible to every format- and code-level check; they
surface only when two agents implement different readings.

### 3.5 Snapshot bookkeeping duplicates git

`pass0/` and `pass1/` frozen copies exist so audit line references stay
resolvable. Git already provides immutable snapshots addressable by commit;
a pinned reference (`spec.md @ 7ba70b7`) achieves the same stability
without a second copy that can drift (and whose diff against the live doc
someone must now verify — see the diff run in this review's preparation).
The bookkeeping is also growing superlinearly: ~3,500 lines of process
documents now surround a ~660-line design.

### 3.6 Nobody owned convergence

Each audit round was locally justified; no role was responsible for asking
"should this loop continue?" The strategy has falsification conditions for
the *sprint* but none for the *process* — no cap on rounds, no rule for
when residual findings transfer to the ratification gate instead of another
cycle.

## 4. Recommendations

1. **Add a verdict: PASS-WITH-EDITS.** Auditor supplies the exact edits
   (they already do — T146 and T150 both wrote the fixes verbatim); the
   author applies them; the human ratifies the *diff* at the gate. No
   re-audit cycle for editorial MUSTs, SHOULDs, or COULDs. NEEDS-FIX is
   reserved for findings that require design judgment to resolve.
2. **Revision briefs enumerate every open finding ID, and acceptance is the
   disposition log.** A revision is incomplete unless its resolution log
   shows a disposition (fixed / rejected-with-reason / escalated) for every
   open finding in the audit it answers. A skipped ID is a failed task, not
   a smaller task.
3. **Audit briefs must state that zero new findings is an acceptable PASS,**
   and require every finding to cite file+line verified against the current
   text. (The RV2-1 rule.)
4. **Cap audit rounds at two per document by default.** After round two,
   remaining open items go to the human gate as a ratification checklist
   with proposed edits, not into another cycle. The human is the final
   auditor anyway; three rounds of prose audit before the human reads the
   document is deference, not rigor.
5. **Refer to acceptance criteria by slug, not bare number** — `A1-refusal`,
   `A7-gate-chain` — or quote the criterion verbatim where cited. Downstream
   briefs (M4a: "A3, A5, A6 fixtures") should never be interpretable two ways.
6. **Replace `passN/` snapshots with commit-pinned references.** One live
   document per artifact; audits cite `path @ short-sha : line`. (Meta:
   the human has already flagged the pass0/pass1 split as not making sense;
   this is the concrete replacement.)
7. **Model allocation, from observed performance in this sprint:**
   - *Opus* for load-bearing audits and design mathematics — O-4/T146
     caught every real blocker and effectively dictated the DTT fix.
   - *DSPro* for implementation against a frozen contract and for
     checklist-style verification (its DTT trace in T150 was sound), with
     the rule-2 brief discipline, since as reviser it twice did partial work.
   - *Fable* sparingly: gate decisions, loop termination, cross-corpus
     consistency — the places where the whole document set must be in one
     head.
   - Keep the cheapest models off critical-path transcription; the two
     cheapest tasks in this sprint (apply enumerated fixes) were the ones
     that failed twice.
8. **Shift audit budget from prose to code as the sprint matures.**
   Design-audit rounds one and two had the highest defect yield of the
   whole process; round three was net-negative. Past that point the
   mechanical checks (A5 round-trip, A7 gate chain, A6 calibration) catch
   the residual class of defect more cheaply than another reading. The
   acceptance harness existing *before* the code it judges (the M4a
   sequencing) is the right instinct — trust it.

## 5. Oracle-v2 scorecard

| stage | rounds | real defects found | verdict on the stage |
|---|---|---|---|
| spec (pass 0 → 1) | 1 audit + 1 revision + 1 re-audit | 1 BLOCKER, 5 MUST, all real | worked exactly as designed |
| strategy | 1 audit | 2 MUST (review-gating gaps), real | worked; findings absorbed downstream |
| design M1 rev 0 → 1 | audit O-4 | 2 BLOCKER, 2 CRITICAL, 5 MUST — all real, two sprint-saving | highest-value audit of the sprint |
| design M1 rev 1 → 2 | re-audit T146 | 1 CRITICAL (real), 3 MUST (real, the DTT mathematics), 1 MUST (unit typo) | still positive yield; DTT needed it |
| design M1 rev 2 → 3 | re-audit T150 | 1 CRITICAL carried (not fixed), 1 MUST carried, 1 MUST phantom | net-negative round; the loop should have ended at the gate instead |

The claim was never impossible, the methodology did not need proving past
round two, and implementation is the only remaining proof that matters:
A1-refusal is an empirical question no further prose can move. Rev 3 of the
design applies the already-written fixes; after that, the correct spend of
audit attention is `src/`, not `docs/`.
