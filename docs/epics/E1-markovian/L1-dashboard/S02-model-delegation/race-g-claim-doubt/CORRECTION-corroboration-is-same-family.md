# Correction — G20/G25 are same-family corroborations, not cross-family

**Raised by Fable, 2026-08-22, against the T612 seat's own report. Recorded here because the
error would otherwise be inherited by every reader of this race.**

The seat reported that `G20 CODE.WZO2-INCOMPLETE` and `G25 QA-022` were "corroborated by
independent refutation from different families". **The second half is false.** The two lanes
that refuted them are `claude-opus-5` and `claude-haiku-4-5-20251001` — **both Claude**.

What is true, and what is not:

- **True:** the two lanes ran independently, with no cross-talk, and reached the same refutation
  on the same claim. That is genuine corroboration and it is still the strongest signal in the
  batch.
- **False:** that the corroboration crosses families. It does not. A shared family means shared
  priors, shared training, and shared blind spots, so agreement between two Claude lanes is
  weaker evidence than the same agreement between a Claude lane and a DeepSeek one — and the
  three DeepSeek and Claude-Sonnet lanes that saw these claims all said **verified**.

Stated correctly: **G20 and G25 are the two claims where two same-family lanes independently
refuted what the other three verified.** They remain the priority reproduction targets, on the
strength of the independence rather than a diversity that was not there.

**Why the seat got it wrong, since the failure mode is reusable:** it read "two different models
disagreeing with the majority" as diversity, and did not check the families of the two models
against each other. Family independence is exactly the property this project's grading rules
(G3) are built on, and the seat asserted it without looking it up. The lesson is the project's
own: *absence of a check is not evidence the property holds.*

No ledger row carries the error — it was in a report, not in the matrix, and the matrix cell for
Race G is not written yet. The graders were told about the priority targets **without** the
family claim attached.
