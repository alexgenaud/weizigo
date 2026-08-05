Task: 2B-FIX-KO · Role: worker · Model: Opus 5 (claude-opus-5[1m]) · Date: 2026-07-29

# PROVENANCE — 2B-FIX-KO: ko-rule fix + census/probe re-run (3×2)

## Commit

**Parent commit at run time: `45ed0f318ed116efa7af24b225628029d7ef8294`.**
Every run below was made on a working tree equal to that commit plus the two
`src/` edits described in the deliverable §1.2 — nothing else.

Pinning the commit is a convention change the Opus 2B-2 audit asked for: the
`src/qa023_probe.zig` hash recorded in
`PROVENANCE-census-3x2-2026-07-29.md` (`efb86db8…`) no longer resolves to any
file at HEAD, so the hash alone cannot be used to reproduce that run. A hash
plus a commit can.

## Artifacts

| path | role | SHA-256 |
|---|---|---|
| `docs/evidence/QA-023/ko-fix-rerun-2026-07-29.md` | the deliverable | n/a (not a reproducer) |
| `docs/evidence/QA-023/ko-fix-rerun-2026-07-29.stdout` | every corrected-rule run, verbatim | `72beca484d82d888d2d8397d30bb9430010fe7c7438d3bcd8f791ac6c4973650` |
| `src/qa023_probe.zig` | 3×2 rules + census + probe (after the fix) | `46b874685467188b94e35f0b35043c514c4b6f62fce8a310fa927b05ede236f5` |
| `src/qa023_brute_2x2.zig` | 2×2 rules (after the fix) | `e25795bea26b9af6a67a96e10b536bbbe2e249e75c98013bafaa0ee887f18f8e` |
| `…/ko-fix-2026-07-29/indep_3x2.py` | independent 3×2 graph (as-implemented rule) | `87d0e7c54e2b20d972e9e4bd49bc3a9bab885ac8d02b3e3838afae8f736b26b1` |
| `…/ko-fix-2026-07-29/corrected.py` | the same, with the lone-stone ko condition | `bc26d7ab2922d2da94324d358206f3762112943ab59f8859a08e8850fab95ef2` |
| `…/ko-fix-2026-07-29/ko2x2.py` | exhaustive 2×2 ko-firing count, both rules | `690911f5b0c8c7fd9a5905bfce7d185dcf9495209c476e69e347959bd4e8e95f` |
| `…/ko-fix-2026-07-29/fix2x2.py` | independent 2×2 median fixpoint, both rules | `284fb50b288d09988dbb678dd1eb9a4fa03fe0aabd3b3454e041c14aaab6bcef` |
| `…/ko-fix-2026-07-29/scc2x2.py` | reachable 2×2 SCC, both rules | `3b1c784412bc0c1027d29c5c0221c4adc7d10805ff0175c68115fc90f151b880` |
| `…/ko-fix-2026-07-29/graph2x2.zig` | 2×2 graph through the real Zig rules | `3e8a58daec189e7a192ab78449328db647971a7790ee1f9c141931dcf6660cdd` |
| `…/ko-fix-2026-07-29/census-cap{12,14,16,18,20,22}-fixed.stdout` | the corrected cap sweep | (in tree) |
| `…/ko-fix-2026-07-29/probe-seed-depth-sweep.stdout` | 4 seeds × 3 depths | (in tree) |

## Build

```sh
tools/runner -- zig build-exe src/qa023_probe.zig -femit-bin=<scratch>/probe_fixed
```

Zig 0.16.0, `-O ReleaseFast` (auto-added by `tools/runner`, the B-2 RSS guard
per `docs/infra/host/incident-2026-07-29.md`). Peak RSS 339 MB during
compilation, 44–45 MB at runtime for the census, <2 MB for the probe. No
guard kill in any run.

## Commands

```sh
# headline census (deliverable §3)
tools/runner -- <bin> cycle-census-3x2 --max-cycle-len 14 --max-cycles 1000000000

# cap sweep (§3.1); cap 22 took 385 s, the rest seconds
for c in 12 14 16 18 20 22; do
  tools/runner -- <bin> cycle-census-3x2 --max-cycle-len $c --max-cycles 100000000000
done

# headline probe — 2B-4's command verbatim (§4)
tools/runner -- <bin> probe-3x2 --seed 0x2B4DA7A --n-samples 256 \
    --k-histories 8 --history-depth 16

# robustness (§4.1): seeds 0x2B4DA7A 0xC0FFEE5 0xF00D 0x5EED x depths 16 24 40

# upstream inputs (§4.2)
tools/runner -- <bin> census-3x2
tools/runner -- <bin> fixpoint-3x2
tools/runner -- <bin> history-pairs-3x2
tools/runner -- <bin> smoke-2x2
tools/runner -- <bin> calibrate
tools/runner -- zig test --test-filter "2x2 smoke" --test-filter "3x2" src/qa023_probe.zig
```

Independent cross-checks (no Zig, or Zig-without-`value`):

```sh
python3 docs/evidence/QA-023/ko-fix-2026-07-29/corrected.py   # 3x2, both root sets
python3 docs/evidence/QA-023/ko-fix-2026-07-29/ko2x2.py       # 2x2 ko firings
python3 docs/evidence/QA-023/ko-fix-2026-07-29/fix2x2.py      # 2x2 fixpoint diff
python3 docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py      # 2x2 reachable SCC
# graph2x2.zig: see its header — needs a scratch dir with a copy of src/
```

## Code change

Two files, one conjunct each — the lone-stone test on the ko-point condition:

- `src/qa023_probe.zig` `apply_place`, 3×2 — ko-point block `:552-563` (was
  `:540-549` at `45ed0f3`) + header comment `:514-520`.
- `src/qa023_brute_2x2.zig` `State.apply_place`, 2×2 — `:120-138` (was
  `:118-130` at `45ed0f3`).

No other behaviour touched. No test was changed, removed, or weakened. No
`CLAIMS.md` edit; no 2B-N deliverable edited.

## Hazard note (why the 2×2 tests are not in the cross-check list)

All seven tests in `src/qa023_brute_2x2.zig` call `value`/`brute_value` — the
path-enumeration evaluator that `reference-semantics-2026-07-29.md` §3 rules
NONCONFORMING and that caused the 10h22m thrash. `--test-filter "1-ko shape"`
was attempted, ran 2.5 min at 98% CPU, and was killed. The 2×2 half of the fix
is verified by `graph2x2.zig` + `ko2x2.py` + `fix2x2.py` + `scc2x2.py`
instead, none of which calls `value`.

## Dependencies

- `docs/audits/2026-07-29-2b-2-census-audit-opus5.md` — finding F5 (the bug),
  and F1/F2/F6 referenced in the deliverable.
- `docs/evidence/QA-023/proof-v2-2026-07-28.md` §1.1 — the governing rule text.
- `docs/evidence/QA-023/reference-semantics-2026-07-29.md` — 2B-0 semantics.
- `docs/evidence/QA-023/census-3x2-2026-07-29.md` — 2B-2, superseded numbers.
- `docs/evidence/QA-023/probe-3x2-2026-07-29.md` — 2B-4, the falsification
  under test.
- `docs/infra/dispatch/2B-FIX-KO.md` — the brief.
