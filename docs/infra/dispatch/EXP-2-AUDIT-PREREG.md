# EXP-2 audit — PRE-REGISTERED acceptance criteria

**Written 2026-07-28, pre-registered BEFORE any EXP-2 result exists.** That is the
point of the document: I proposed QA-023 and I want it to be true, so the
criteria for believing it must be fixed before I can see whether they were met.
If a later audit relaxes anything here, that relaxation must be recorded as a
deviation with a written reason.

Context: the EXP-2 brief was corrected mid-flight (Part B moved from 2×2 to
3×2, because 2×2 admits no reachable non-root cycles and the check would have
been vacuous). A console that started before that correction may report a
2×2-based result. These criteria apply regardless of which revision was run.

---

## REJECT outright — any one of these, no discussion

1. **The computational check was run at 2×2 only.** 2×2 admits no reachable
   non-root cycles (`CLAIMS.md:159` `2x2.T12`; `4x4/EPISTEMIC.md:401`). QA-023
   is a claim about how long cycles are valued, so a goban without them cannot
   test it. A 2×2 pass is *not evidence*; it is the T12 tautology again.
   → Verdict: **INCOMPLETE**, not FAIL. Part A may still be good. Re-run Part B
   at 3×2.
2. **The cycle census is zero or unreported.** If no state required the
   fixed-value verdict to resolve, the machinery under test was never exercised
   and the goban is too small. → **INCOMPLETE**; escalate to 3×3.
3. **No calibration case**, or a calibration case the checker failed to catch.
4. **No independent brute-force comparison** — a solver agreeing with itself is
   not a check.
5. **Part A is missing or is a plausibility argument rather than an argument.**
   In particular, an argument that establishes only *"a fixpoint exists on a
   finite graph"* does **not** establish QA-023. The claim is that the fixpoint
   **equals the true game value under the rule**. Existence is not equality.
6. **The adversarial reviewer was given this brief, the roadmap, or the
   critique.** All three argue for the conclusion; a reviewer who read them is
   not independent, and the review must be redone.

## REQUIRE — all of these, for a PROVEN verdict

7. **A2 answered concretely:** the two basic-ko formalisations are shown
   equivalent under this project's rules, **or** a distinguishing position is
   exhibited and a choice is made. "They coincide in practice" is not an answer.
8. **A4 answered concretely:** the algorithm is named and argued correct. If the
   answer is "iterate L/H and pin `L≠H` states to the tie value", that
   equivalence must be *proven*, not assumed — I flagged my own earlier claim
   here as too strong and I do not want it accepted back uncritically.
9. **A5 answered:** the value domain including the tie is specified, with its
   byte representation.
10. **Every state agrees** with the brute force at 3×2 — not "agrees on a
    sample", not "agrees except for N".
11. **Evidence committed** under `docs/evidence/QA-023/`: proof, solver source,
    brute-force source, both outputs, the calibration run, the review verdict.
    Per roadmap §4 P1 a claim is not PROVEN if its evidence is not in git — and
    this project has already destroyed the evidence for its central
    falsification exactly that way.

## The question I must ask of a PASS, per critique §3

**What is the probability that a wrong answer would also have passed this test?**
The audit must state it. Three of this project's past "validations" — anchor
agreement, cycle-rule insensitivity, bracket containment — would have been
passed by a wrong result 40-70% of the time and were recorded as confirmation.
If EXP-2's check has a comparably high pass-rate-under-error, it is weak
evidence and must be labelled as such no matter how clean the output looks.

## The 2×2 = 0 cross-check is necessary, not sufficient

A correct build must return **0** at 2×2, not weizigo's PSK **+1**
(`retrograde-3x3.md:224-245`). Returning +1 means PSK was implemented by
accident → **FAIL**. But returning 0 proves only that basic-ko legality was
implemented; it says nothing about the cycle verdict, which is the actual claim.
Do not let a passing cross-check stand in for Part B.

## Possible verdicts

- **PROVEN** — 7-11 all met, nothing in 1-6 triggered, and the
  wrong-answer-pass-probability is stated and low.
- **INCOMPLETE** — Part A sound, Part B vacuous or missing. Salvage A, re-run B.
  *This is the most likely outcome for a console that started before the
  correction, and it is not a failure.*
- **FALSE** — a genuine disagreement between the fixpoint and the brute force at
  3×2. → QA-023 is dead. **Stop the roadmap and escalate.** Do not engineer
  around it; EXP-4 through EXP-8 all fail with it.
- **UNRESOLVED** — the reviewer found a flaw in Part A that was not repaired.

## Standing instruction

A result that is *convenient* gets more scrutiny than one that is not. If
EXP-2 comes back clean on the first attempt, that is the moment to look hardest
— this session has already produced one false-looking-clean result (my own
"purely definitional" reading of the chainability violations) that survived
until it was calibrated against a known-good case.
