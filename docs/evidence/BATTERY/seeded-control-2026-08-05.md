# Battery seeded-defect control — 2026-08-05 (milestone M2 hands-on test)

Run by the Orchestrator seat (Opus 5) at HEAD `c1afcb9`. This is the hands-on test
`docs/audits/2026-08-05-handover/MILESTONES.md` §M2 prescribes — *"corrupt one byte of a copy of
the artifact and run the battery against it — it must fail loudly"* — executed, with the
null control taken first so the pass reading means something.

Isolation: the readings were taken in a **detached `git worktree` at HEAD**, not the main
checkout. The main tree carried T363's uncommitted `src/vb_*.zig` edits at the time, and a
binary built from it panicked in `verify_battery.zig:825`; a live console's uncommitted source
makes the working tree an invalid instrument for anyone but that console. The worktree
technique is the same directory-boundary isolation the race protocol uses.

## 1. Null control — clean committed artifact reproduces the golden master exactly

`verify-battery 3x3 artifacts/oracle-3x3.wzo` (built at `c1afcb9`, Debug) against
`docs/evidence/BATTERY/baselines.json` (recorded by T292, 2026-08-03):

| invariant | reading | baseline | agrees |
|---|---|---|---|
| I1 | pass 16652 / 25350 | pass 16652 / 25350 | yes |
| I2 | pass 0 / 12675 | pass 0 / 12675 | yes |
| I4 | pass 0 / 15742 | pass 0 / 15742 | yes |
| I5 | pass 0 / 8698 | pass 0 / 8698 | yes |
| I7 | **fail 822 / 25350** `artifact-bad` | **fail 822 / 25350** `artifact-bad` | yes |
| I12 | pass 0 / 25350 | pass 0 / 25350 | yes |

Trailer: `exit_code 1`, pass 7 / fail 1 / not-applicable 4. **I7's failure is a recorded
characteristic of the old WZO1 3×3 artifact, not a regression** — the baseline's own
`comparison_rule.known_failing` says a recorded `fail` is a characteristic and that a change in
*either* direction is what must be adjudicated. Nothing changed in either direction.

## 2. Seeded control, first attempt — caught by the container, not the invariants

One byte flipped at offset 70878 / 118130 (`0x00 → 0xff`) on a **copy**:

```
error: artifact decode: error.BadChecksum
trailer: exit_code 3, error 1, exit_class_counts {battery_bad: 1}
```

Loud, and M2's literal test is satisfied — but the corruption never reached a single invariant.
WZO1 carries a CRC-32/ISO-HDLC over the payload at header bytes 28–32 (`src/artifact.zig:206`),
so a blind byte flip is refused at load. **This control therefore proves the checksum works, not
that the answer key is checked.** Recorded so nobody mistakes one for the other.

**Defect worth a row (classification, not correctness):** a corrupt *input* is reported as
`exit_class = battery-bad` — the class meaning "the battery cannot be trusted" — when the honest
class is `artifact-bad`. Gates dispatch on `exit_class`, so a bad artifact currently reads as a
broken instrument.

## 3. Seeded control, second attempt — value mutation with the checksum repaired

To reach the invariants, one **value** was changed and the CRC recomputed so the loader accepts
the file: `vb[7117] : 9 → 7` (a legal cell; 12,675 of 19,683 cells are legal). Same binary, same
command, same denominators:

| invariant | clean | value mutant | verdict |
|---|---|---|---|
| I2 | pass 0 / 12675 | **fail 1 / 12675** | fired |
| I4 (Bellman residual) | pass 0 / 15742 | **fail 4 / 15742** | fired |
| I1, I5, I6, I7, I9, I12 | unchanged | unchanged | correctly quiet |

Trailer: `exit_code 1`, pass 5 / fail 3, `artifact_bad 3`. Denominators are identical across the
two runs, so the counts are directly comparable.

**Reading:** the battery detects a single wrong value in a 99,133,036-scale artifact class by the
invariants themselves — one changed byte of *meaning*, not of format, moved I2 by 1 and I4 by 4
and left the six unrelated invariants exactly where they were. The clean-run pass in §1 is
therefore a licensed reading, not an unfalsifiable one.

**Scope, stated honestly:** this licenses the battery's I2 and I4 cells at 3×3 on WZO1. It says
nothing about 4×4, about the WZO2 format, or about the closure and cycle-containment cells that
T363 is closing — those need their own controls at their own rungs, and the 4×4 I4/I5/I7 cells
are baselined as `error`/`battery-bad` (unsupported goban) today.

## Reproduce

```sh
git worktree add /tmp/head-wt HEAD && cd /tmp/head-wt && zig build
./zig-out/bin/verify-battery 3x3 artifacts/oracle-3x3.wzo          # null control
# value mutant: change one legal vb cell, recompute crc32 over bytes[32:], write to bytes[28:32]
./zig-out/bin/verify-battery 3x3 /tmp/mutant-3x3.wzo               # seeded control
```

Noise observed and not chased: the Debug build reports four `DebugAllocator` leaks at exit
(`verify_battery.zig:434` and `:825`) on every run, clean or mutant. Cosmetic for these
readings; it does not touch any count above.
