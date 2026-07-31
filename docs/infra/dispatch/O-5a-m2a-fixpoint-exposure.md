<!--managent set=A-->
# O-5a — oracle-v2 M2a: expose fixpoint interface

**Gated on:** G1 (human ratification of oracle-v2 spec pass 1)
**Holds:** `src/exp6_solve.zig`
**Time box:** ≤ 1 h

## What to do

Expose the fixpoint algorithm from `src/exp6_solve.zig` as a public interface. Currently the file's sole `pub` is `main()` — StateIdx32, reachability, and the fixpoint loop are all file-private.

**This is a refactor only — zero behavioural change.**

## Acceptance

1. Public declarations for the fixpoint entry point, StateIdx32, and reachability structures
2. The existing `main()` produces byte-identical output to the committed evidence
3. The A7 chain (2×2=0, 3×2=0, 3×3=+9) reproduces exactly
4. A byte-identical 3×3 artifact is produced
5. No new logic, no changed sweep counts, no changed values

## Read first

- `src/exp6_solve.zig` (the file you hold)
- `docs/infra/oracle-v2/pass0/spec.md` §5 M2a
- `docs/infra/oracle-v2/pass0/strategy.md` §P1
- `docs/design/oracle-v2/archive/spec.audit-2.md` (F1 resolution)

## Rules

- MUTATION — holds `src/exp6_solve.zig` exclusively
- Pub-only: expose existing declarations, do not restructure the algorithm
- If no importable interface exists, state the minimal refactor needed and stop — do not improvise
- Build with `zig build install`; run under `tools/runner`
