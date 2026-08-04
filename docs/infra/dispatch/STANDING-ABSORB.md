<!--managent set=H-->
# STANDING-ABSORB — absorb the findings backlog

Auto-registered standing task. Trigger: claimlint's C7 unabsorbed-findings count
exceeds the threshold (5) — `managent standing` fires when
`C7 unabsorbed findings` in `bin/weizigo-claimlint`'s summary is above it, and
prints the per-file composition so triage is done before work starts.

Absorption has been registered by hand three times in two days (T279, T288,
T293) because the Orchestrator happened to notice C7 climbing. This trigger
makes that a mechanism (T294, 2026-08-03).

## Task

Absorb the unabsorbed findings into the epistemic register:

- Read the count and its per-file breakdown from `managent standing` (the
  count is claimlint's own — do not reimplement it).
- For each UNABSORBED entry: reconcile the proposed status against
  `docs/epistemic/CLAIMS.md`; ratify it (update/add the row, citing the
  findings file) or disposition it in `findings/rejections.json` with a
  reason-carrying entry.
- Context dumps (a task's `-context.json` repeating its findings file) are
  noise in the count: when a dump's claims are already carried by the same
  task's findings file, disposition the duplicates rather than absorbing them
  twice.
- Do not absorb what is not yours to absorb: the CLAIMS.md owner is the
  claims-register seat; confirm scope before editing.
- **Never widen a claimlint floor to admit a citation.** When a finding cites
  a path under `/tmp/` or `untracked/`, that evidence is alive only until the
  next prune or reboot.  Rescue the file into tracked evidence under
  `docs/evidence/` and re-point the citation in the findings or the claim
  row; NEVER raise a C2/floor to accommodate a transient path.  Eleven dead
  paths in C2 are what ignoring this already cost (T337 S4, 2026-08-04).
  The floor is lowered only by the Orchestrator on evidence of a committed
  fix (ARGUS.md:97-100).

## Deliverable

C7 unabsorbed down to at or below the threshold, with every remaining entry
explicitly dispositioned; the absorption reflected in `docs/epistemic/CLAIMS.md`
and/or `findings/rejections.json`, committed.
