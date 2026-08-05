# Race 3 · Packet R3-P3 — "solve it backwards"

*Exam item for EPISTEMIC-RACES race 3 (prior-art mapping). Below is a plain-language description of a method the project uses. Identify the literature: the established name of the method family, the canonical citations, and what the literature offers that the project has not imported.*

---

## The description

Forward search from the start position explodes exponentially, so the other direction is
used: start from the terminal positions whose values the rules decide outright, and work
backward — compute the value of every position one move from a terminal, then every position
one move from those, and so on, storing each result in a table. Once the table is complete,
play is a lookup, and the table is an answer key rather than a search. This is how chess
endgames, checkers, and small-board Go have been solved exactly. The project's solver and its
[L,H] bracket tables are an instance of this family, and the 99,133,036-entry 4×4 table is the
artifact the whole verify-battery audits.

## Task

1. **Name the method family** (the established literature name — the project's own coinage is
   "retrograde value iteration") and give the canonical citations (the two classic
   touchstones: the origin and the first large-scale application).
2. In 2–4 sentences: what does the literature offer that the project has not imported?
