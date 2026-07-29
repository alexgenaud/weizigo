<!--managent set=H-->
# STANDING-REEVIDENCE — re-evidence claims with growing C3 debt

Auto-registered standing task. Trigger: `claimlint` C3 debt grew since last measurement.

## Task

Re-run evidence generation for claims whose C3 bracket has widened.
Trace each C3 claim back to its producing code and verify the bracket is still valid.
If the bracket is correct but wide, document why.
If the bracket is wrong, re-run the evidence generation.

## Deliverable

Updated C3 brackets in `docs/evidence/` with fresh runs, or documented justification for the gap.
