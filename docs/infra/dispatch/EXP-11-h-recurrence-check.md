<!--managent set=A-->

# EXP-11 — H-recurrence swap check (Dabir 011's 10-minute question)

**Closes:** an open question from the Dabir's standing brief: "Fable
found v1 §4.2's H-recurrence has max/min swapped versus ADR-0009. If
that is a proof-side transcription error, fine. **If the swap is in
the code, it is a bug.** Check `src/retro.zig` against ADR-0009 and
report." (Source: `untracked/msg/milestone-01-ko-reframe/011-dabir-to-orchestrator.md`
§"One live question for a worker, ten minutes".)

**Read first:** `AGENTS.md` (foreclosures), then
`docs/decisions/0009-retrograde-value-iteration.md` (the recurrence
ADR), then `docs/evidence/QA-023/proof-v2-2026-07-28.md` §1.4 and §9.3
(Fable's note that v1's §4.2 has the swap), then `src/retro.zig` —
specifically the H-recurrence code (search for `H_B`, `H_W`, or the
Bellman update for H in the file).

**The question, stated precisely.** Does `src/retro.zig`'s H
recurrence match ADR-0009's specification? Specifically: ADR-0009
defines H as the *greatest* fixpoint of the *same* operator used for L
(Black maximises, White minimises, both sides alternate). v1 §4.2 of
the QA-023 proof had max/min **swapped** in the H-recurrence; Fable's
v2 §1.4 confirmed the swap. **Is the swap confined to v1's proof
document, or did it propagate into the code?**

**KIND:** ANALYSIS, no `holds`. Read `src/retro.zig` only.

**ACCEPTANCE — three possible verdicts, one of which:**

1. **"v1 transcription error only, code is correct"**: `src/retro.zig`
   matches ADR-0009. Cite the function and the line(s).
2. **"Code recurrence also has the swap, fix proposed"**: state the
   offending code, propose a one-line fix, do **not** apply it
   (Orchestrator's call whether to ship). Cite ADR-0009 vs the code.
3. **"Neither side has the swap; v1's wording is fine"**: cite v1
   §4.2 and ADR-0009, explain.

A verdict of "vague" or "could be either" is not acceptable — the
task is read-the-two-and-pick. If the code path is genuinely
ambiguous, **say so and stop** (the dispatcher decides the next step).

**EVIDENCE:** write findings to `docs/evidence/QA-023/h-recurrence-check-2026-07-28.md`.
A one-paragraph report + the cited lines from each source. No new
code; no engine edit.

**Do NOT** edit `src/retro.zig` or any other engine file. Do not edit
any data/ or artifacts/ file. Do not propose a fix to a different
file; this is the recurrence check, not a sweep.

**Report shape:**
- One-line verdict (one of the three above).
- Cited line(s) from `src/retro.zig` showing the recurrence.
- Cited line(s) from ADR-0009 showing the spec.
- Cited line(s) from v1 §4.2 and v2 §1.4 (the proof side).
- If a code bug: a one-line fix *proposed* but not applied.

**Task duration estimate:** 10–30 minutes, depending on how
quickly the recurrence can be located in `src/retro.zig`.
