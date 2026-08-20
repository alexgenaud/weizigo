# PROVENANCE — exhaustive I11 at 4×4 (T473, L2 remainder T-b)

**Task:** T473 · **Set:** E · **Role:** worker · **Author:** deepseek-v4-flash/T473
**Date:** 2026-08-20 · **Brief:** `untracked/T473-i11-exhaustive-4x4.md`
**Landmark:** `L2 (proven 4×4 values)` — remainder item T-b of
`docs/audits/2026-08-19-L2-audit/VERDICT.md`: I11 was the one non-exhaustive
G3b condition at 4×4 (0 / 50,000 sampled of the table — 0.05%).

## What this run establishes

I11 (move-set consistency: the battery's independent R8 move generator,
`src/vb_movegen.zig`, vs the kernel's, `src/rules.zig`) at 4×4, exhaustive.
Two readings, two denominators:

| reading | instrument | denominator | result | wall |
|---|---|---|---|---|
| **I11 4×4 FULL slice** — R8 vs SMD1 dump over every artifact-slice record (ko=NONE, passes=0), 24,318,165 legal positions × 2 sides | `compareSmd1` over the in-memory exhaustive SMD1 emission (the `tools/smd1.zig` emitter path, ported in-file) | **48,636,330** records | **0 mismatches** | emit 15.3 s + compare 12.6 s |
| **I11 4×4 FULL table** — R8 vs kernel over every stored WZO2 entry, incl. ko-active and passes=1 states (which the SMD1 slice format cannot represent — design-M1 §4.6 slice = ko=NONE, passes=0) | `compareTableDirect` (`src/vb_i11.zig`, new; entry key-byte decode per artifact2 §2.2, kb>>2 — T383 F-7 contract) | **99,133,036** entries | **0 mismatches** | 37.5 s |

Both under `tools/runner` guards: exit 0, **peak RSS 558 MB** (runner's
per-PID peak; the 4 GB cap was never approached), total wall 69.5 s
(including ReleaseFast compile).

## Artifact identity

`data/oracle-4x4-v2.wzo2` — SHA-256 `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a`
(verified `shasum -a 256` 2026-08-20, identical to the baseline record
`docs/evidence/BATTERY/baselines.json` and the T310 deterministic-rebuild
reference), 518,123,097 bytes. Header parsed by the new reader (mirrors
`vb_closure.parseWzo2Header`): `n_groups = 24,318,165`, `n_entries =
99,133,036`, `ko_bits = 5`, `hdr_flags = 1 (PASSES_2_OMITTED)`,
`data_offset = 128`; file-size check `128 + 24,318,165×5 + 99,133,036×4 =
518,123,097` ✓.

## Commands

```
# measurement (10× the historical 50k sample) — projection before the full sweep:
WEIZIGO_I11_4X4_MEASURE=1 tools/runner -- zig test --dep engine \
  -Mroot=src/vb_i11.zig -Mengine=src/smd1_engine.zig --test-filter 'MEASURE'

# full sweep (both arms):
WEIZIGO_I11_4X4_FULL=1 tools/runner -- zig test --dep engine \
  -Mroot=src/vb_i11.zig -Mengine=src/smd1_engine.zig --test-filter 'FULL'

# controls / full standalone suite (ReleaseSafe; gated tests skip):
zig test -O ReleaseSafe --dep engine -Mroot=src/vb_i11.zig -Mengine=src/smd1_engine.zig
```

(runner auto-adds `-O ReleaseFast`; identity `T473` via `MANAGENT_TASK_ID`;
heartbeats in `untracked/heartbeat.jsonl`.)

## Full-run output (verbatim readings)

```
I11 4x4 FULL slice: records=48636330 mismatches=0 emit=15252 ms compare=12610 ms total=27862 ms
I11 4x4 FULL table: entries=99133036 groups=24318165 slice=48505262 ko_active=2122512 passes1=48505262 mismatches=0 total=37518 ms
[runner] peak RSS by PID: 558 MB (test process)
[runner] exit 0 in 69.5 s
```

Full-table composition (partition, asserted in-test): slice (ko=NONE,
passes=0) 48,505,262 + ko-active (ko < 16, passes=0) 2,122,512 + passes=1
48,505,262 = 99,133,036. The slice-in-table (48,505,262) is smaller than the
SMD1 slice (48,636,330) by 131,068: those slice states are legal but not
root-reachable (not stored — G3a: the table is the root-reachable set; the
T380 settled-skip non-reachable figure of 133,102 is the same phenomenon
under a different convention, magnitude-compatible).

## Cross-checks that make the readings trustworthy

1. **Legal-position count:** the full colex sweep's `is_legal` filter counts
   exactly **24,318,165** legal positions = OEIS A094777(4) = the WZO2
   table's `n_groups` (row `4x4.S3a` PROVEN). The SMD1 slice and the table
   group index enumerate the same position set.
2. **Table-direct instrument calibrated small:** `compareTableDirect(3, 3,
   data/oracle-3x3-v2.wzo2)` — 0 mismatches over all 49,428 stored entries
   (groups 12,675; slice 24,330 + ko-active 768 + passes1 24,330), wired as
   an always-on test (the smallest real WZO2 artifact).
3. **Key-byte decode regression test** (artifact2 §2.2 layout, kb>>2):
   hand-encoded bytes decode to the expected (side, ko, passes) — a
   kb>>1-style leak (T383 F-7) would fail it.
4. **Controls unchanged (brief bar):** NULL CONTROL kernel-vs-SMD1 at
   2×2/3×2/3×3 → 0 mismatches (0/114 at 2×2); SEEDED-DEFECT (synthetic
   suicide allowance at 2×2) → mismatches > 0 (1/114-style firing);
   exhaustive ladder 0/114 · 0/978 · 0/25,350 · 0/643,378; 4×4 sampled
   0/50,000; 3×3 SMD1 cross-check 0. Full standalone suite: **40/40 pass**
   (Debug and ReleaseSafe).
5. **No silent denominator reduction:** the brief's "99,133,036" is covered
   by the full-table arm; the SMD1 slice arm reports its own (smaller,
   format-bounded) denominator explicitly. Neither was weakened to fit; the
   comparison is R8-vs-kernel bit-for-bit on all 17 bits (16 cells + pass)
   per state.

## Measurement-before-run (T473 bar) — projection vs actual

The 10× sample (500,000 records/entries, `WEIZIGO_I11_4X4_MEASURE=1`)
measured: compareSmd1 245 ms/500k → projected full slice compare ≈ 23 s
(actual 12.6 s, 1.8×); table-direct 203 ms/500k → projected full table ≈ 40 s
(actual 37.5 s, 1.06×); slice emission 3,529 ms/500k (incl. the full 43M-index
legal filter sweep) → projected ≈ 343 s (**actual 15.3 s — the projection
over-shot ~22×**). Methodology note: the sample emission time was dominated
by the one-time constant legal-filter sweep over all 43,046,721 colex
indices, not by the 500k-record emission; extrapolating the total sample
time by the record ratio double-counts that constant. The projection's
purpose — decide whether the full sweep fits the guards before committing
the machine — was served correctly (projected 407 s total, ceiling 1800 s;
actual 69.5 s). The per-phase rates from the sample (R8 compare, table
direct) extrapolated within 2×; only the emission arm needed the constant
subtracted.

## Claim impact

Evidence for the I11 condition of `4x4.C1` (fresh-start scores correct at
4×4, CLAIMED): the G3b scope limit "I11 at 4×4 is a 50,000-state sample of
99,133,036 — 0.05%" is now closed by these two exhaustive readings. No
status change is proposed here — `4x4.C1` remains CLAIMED (Track A, the #2
auditor gate, and the KO_SENSITIVE-column distrust still stand; promotion
conditions are not this task's). The findings file is
`findings/T473-i11-exhaustive.json`.
