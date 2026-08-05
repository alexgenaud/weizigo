# Race 3 · Packet R3-P1 — "does the check actually check?"

*Exam item for EPISTEMIC-RACES race 3 (prior-art mapping). Below is a plain-language description of a method the project uses. Identify the literature: the established name of the method, the canonical citation, and what the literature offers that the project has not imported.*

---

## The description

You want to know whether a check actually tests what it claims to test — not merely whether it
passes. Deliberately corrupt the thing under test in one small, known way (change one
condition, drop one field, restore one old rule), then run the check. If the check still
passes, it was not checking that property. Repeat with many small corruptions, each standing
in for a real bug the project once suffered; the result is a table: which checks catch which
corruptions, and which corruptions nothing catches. The project runs this against its
verify-battery invariants, one corruption per historical defect. Several historical defects
survive all current checks — and that measured failure is itself the finding that names the
battery's blind spots.

## Task

1. **Name the method** (the established literature name) and give its canonical citation.
2. In 2–4 sentences: what does the literature offer that the project has not imported?
