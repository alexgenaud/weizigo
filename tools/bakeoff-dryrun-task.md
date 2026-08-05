# Bake-off dry-run task — plumbing proof only (not graded)

This is the T328 dry-run fixture. It exists to prove the bake-off plumbing
(dispatch → tools/runner trailer → output file) — it is NOT a quality
measurement and carries NO answer key. The real first race is a separate row
whose task choice gets its own sealed answer key (docs/infra/bakeoff.md).

**Task:** your entire answer must be exactly the single line:

    BAKEOFF-DRYRUN-OK

Nothing else: no prose, no markdown code fences, no trailing commentary. The
harness captures your final message verbatim to the lane's `out.md`.
