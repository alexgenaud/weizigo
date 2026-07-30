# `GLOBAL.AUDITOR` — provenance

**Author:** Kimi-k2.7/T106, 2026-07-30.  
**Dispatch:** direct evidence task from `docs/audits/t101-punchlist-2026-07-30.md` row 5 / `docs/epistemic/CLAIMS.md` row `GLOBAL.AUDITOR`.  
**Run date:** 2026-07-30.  
**Claim ID(s) closed:** `GLOBAL.AUDITOR` primarily; the run is also the standing empirical basis for `3x2.F1`, `3x2.F3`, `3x2.F4`, `3x3.F4`, `4x3.F4`, `4x4.M6` reading 2, and the `GLOBAL.H5` gate.  
**Acceptance criterion (from `AGENTS.md:63-67`):** zero minimax-identity violations on the 3×2 exhaustive pass of the `#2 self-consistency auditor`.

## What the auditor is

The `RETRO_CONSIST` self-consistency auditor (`consistBoard` in `src/retro.zig`, around l. 2973) checks the minimax identity

    V(P, side, [P]) == opt_side( { V(c, -side, [P,c]) : c legal } ∪ { pass } )

at every `KO_SENSITIVE` `(position, side)` slot on a chosen goban, solving parent, children, and pass branch as **independent roots** with freshly re-seeded per-root memos.  A violation is a **proof** that the tested variant is buggy; zero violations is only a **necessary** pass, not a sufficiency witness.  This is exactly the instrument that caught the `ko_ref ≥ d` cross-branch write bug (`ADR-0013`).

Scope asserted by this evidence: the **instrument itself** is durable and re-runnable; the run does **not** certify any particular artifact as correct, and it does not close the 4×4 deepest-N sample unless that sample is run separately.

## Probe source

`src/retro.zig` — existing engine source, not modified for this run.  The relevant entry point is the `RETRO_CONSIST` branch of `main()`, which calls `runConsist(gpa)` → `consistBoard(3, 2, gpa, 0)`.  The `0` `max_checks` argument selects **exhaustive** mode (`max_checks != 0` selects deepest-first sampling).

## Run command

Guarded by `tools/runner` per `docs/infra/runner.md` (4 GB RSS cap, 30-min wall cap):

```
RETRO_CONSIST=1 tools/runner -- zig run -O ReleaseFast src/retro.zig
```

Raw output (stdout + stderr, because the engine prints data via `std.debug.print`) is committed as `consist-3x2-2026-07-30.log`.

## Wall time / resource use

Reported by the runner for this run:

- wall time: 0.3 s (Zig binary reused from cache; the first compile-and-run pass on this host took ~13 s and 722 MB RSS, as recorded in the transient first invocation).
- peak RSS: below the 4096 MB cap.
- exit code: 0.

The 3×2 table build + exhaustive audit is seconds of compute; the run satisfies the `AGENTS.md` standing gate.

## Files in this directory

| file | what it is |
|---|---|
| `PROVENANCE.md` | this file |
| `consist-3x2-2026-07-30.log` | raw stdout+stderr of the 3×2 exhaustive auditor run |

## Results, restated

| variant | memo_writes | checked | violations | skipped | verdict |
|---|---|---|---|---|---|
| `new` (committed generation path) | ON | 378 | **45** | 0 | **PROVABLY BUGGY** |
| `soundish` | OFF | 378 | **0** | 0 | self-consistent (necessary pass only) |
| `deps` (KM dependency-guarded reuse) | ON + deps | 378 | **0** | 0 | self-consistent (necessary pass only) |

This replicates the documented finding in `docs/research/consistency-audit.md`: cross-branch memo writes are the defect, writes-off and dependency-guarded reuse are both self-consistent on the 3×2 exhaustive calibration set.

## Honest scope limits

- The auditor is **necessary, not sufficient**; a self-consistent solver can still converge to a wrong fixpoint.  The `GLOBAL.AUDITOR` claim is explicitly narrowed with this qualifier (`narrowed = 1` in `CLAIMS.md`).
- This evidence covers the **3×2 exhaustive** axis of the standing gate.  The gate also calls for a deepest-N 4×4 sample; that sample was not re-run here because no writes-off 4×4 checkpoint was locally available and the calibration axis is the one that has caught every prior defect.
- The run does **not** promote any dependent claim from `CLAIMED`/`UNTESTED` to `PROVEN`; it only supplies the committed audit log that the gate requires.
