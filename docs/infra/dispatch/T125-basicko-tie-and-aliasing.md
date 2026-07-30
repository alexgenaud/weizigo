<!--managent set=A holds=docs/epistemic/CLAIMS.md-->
# T125 — the frontier result is not in the register; the aliasing withdrawal is not either

**Type:** register edit · **Holds:** `docs/epistemic/CLAIMS.md` · **Needs:** T124
(same file)

## Part 1 — three proposed claim IDs, never assigned

Deliverables handed these to the register seat and were never picked up.
`grep BASICKO-TIE docs/epistemic/CLAIMS.md` returns 0 hits.

| proposed ID | source | content |
|---|---|---|
| `3x3.BASICKO-TIE` | `docs/evidence/QA-026/3x3/PROVENANCE.md:3` | 3×3 root **+9** under basic-ko + TIE=0; matches the MIGOS II anchor; 73,758 states, 0 UNDEF, colour-symmetric |
| `4x4.BASICKO-TIE` | `docs/evidence/QA-026/4x4/PROVENANCE.md:7` | 4×4 root **+1**, bracket [+1,+16] — *not* the expected +2 anchor. 147M states, 31 sweeps |
| (two unnamed) | `docs/evidence/QA-026/PROVENANCE.md:10` | "Both proposed; owner `CLAIMS.md` assigns IDs" |

The 4×4 root value is the project's current frontier result and it has no row.
T104 verified H=+16 genuine — 0 violations over 99,133,036 states, 0 map
misses, exhaustive inversion clean — and concluded the +2 gap is a **ruleset
difference (basic ko vs PSK), not a bug**. Record that as the row's reading;
do not record +1 as contradicting the +2 anchor without it.

## Part 2 — the aliasing withdrawal has no row at all

T102 found a successor-buffer aliasing defect in `brute_value_2x2`
(`docs/audits/audit-2x2-mismatch-2026-07-30.md`). All 24 EXP-4 2×2 "mismatches"
were an artifact of the *checker*, not a divergence in the thing checked;
fixpoint and truncation agree on all 172 reachable non-terminal 2×2 states.

The consequence reaches further than the 24 states, and it is currently
recorded only in `model-perf.md`: **every brute-force corroboration in the
EXP-4 → EXP-7 chain is unsound.** Meanwhile the QA-026 PROVENANCE files still
list brute-force agreement under "Calibration / Known-good".

What survives, and must be distinguished from what does not:

- **Stands** — the fixpoint results, independently verified by T102 (2×2),
  T104's Python kernel (2×2 / 3×2 / 3×3), and the MIGOS II anchor at 3×3.
- **Withdrawn** — brute-force cross-check as corroboration anywhere in the
  EXP chain.

## Task

1. Assign the `BASICKO-TIE` rows; resolve the two unnamed QA-026 proposals.
2. Add a register row for the aliasing withdrawal, with its scope stated as
   above. It is a methodological FALSE, in the shape of `GLOBAL.E1`.
3. Re-tag the QA-026 PROVENANCE calibration sections so brute-force agreement
   is not presented as a known-good.
4. `bin/weizigo-claimlint`.

## Deliverable

New rows, re-tagged PROVENANCE files, claimlint output.
