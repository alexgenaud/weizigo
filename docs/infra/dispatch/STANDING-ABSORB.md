<!--managent set=H type=infra-->
# STANDING-ABSORB — absorb the closed partition

**Landmark:** advances `L4 (the ledger is clean)` — crisis-triggered absorption pass for findings on closed tasks; a non-zero reading means someone went around the close gate (absorption-spec §8, T481).

Auto-registered standing task. Trigger: the **closed partition** reads above
**zero** (T486, absorption-spec §8) — any findings file on a done/failed/
archived task that is non-conforming or carries unabsorbed proposals.
`managent standing` joins claimlint's `c7 --json` per-file report against the
kanban + archive (T481 §7) and fires on the first such file, printing the
per-file composition so the bypass is triaged before work starts.

The open partition — findings of still-open tasks, at any count — is healthy
in-flight work and never triggers. The closed partition is a crisis: with the
close gate in place (T485), a non-zero reading can only mean a side door
(hand-edited register, post-close findings edit, deleted rejection entry).

## Task

Absorb the closed partition into the epistemic register:

- Read the composition from `managent standing` / `managent audit` (the count
  is claimlint's `c7 --json` joined against the kanban — do not reimplement
  it, T481 §7).
- For each closed-partition entry: reconcile the proposed status against
  `docs/epistemic/CLAIMS.md`; ratify it (update/add the row, citing the
  findings file) or disposition it in `findings/rejections.json` with a
  reason-carrying entry.
- Context dumps (a task's `-context.json` repeating its findings file) are
  noise in the count: when a dump's claims are already carried by the same
  task's findings file, disposition the duplicates rather than absorbing them
  twice.
- **Never widen a claimlint floor to admit a citation.** When a finding cites
  a path under `/tmp/` or `untracked/`, that evidence is alive only until the
  next prune or reboot.  Rescue the file into tracked evidence under
  `docs/evidence/` and re-point the citation in the findings or the claim
  row; NEVER raise a C2/floor to accommodate a transient path.  Eleven dead
  paths in C2 are what ignoring this already cost (T337 S4, 2026-08-04).
  The floor is lowered only by the Orchestrator on evidence of a committed
  fix (ARGUS.md:97-100).

## Deliverable

Closed partition down to zero, with every remaining entry explicitly
dispositioned; the absorption reflected in `docs/epistemic/CLAIMS.md`
and/or `findings/rejections.json`, committed.
