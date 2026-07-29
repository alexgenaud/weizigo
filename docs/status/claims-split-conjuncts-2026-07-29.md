# CLAIMS-SPLIT-CONJUNCTS — completion note

**Agent:** DSPro/CLAIMS-SPLIT-CONJUNCTS · **Date:** 2026-07-29

## Changes made

Three conjoined rows in `docs/epistemic/CLAIMS.md` were split into separate
rows per `docs/infra/dispatch/CLAIMS-SPLIT-CONJUNCTS.md`:

### `GLOBAL.H1` → `GLOBAL.H1-MARKOV` + `GLOBAL.H1-COMPUTABLE`

| half | status | depends-on | why |
|---|---|---|---|
| `GLOBAL.H1-MARKOV` | **UNTESTED** | `d:GLOBAL.CHAIN-KO`, `n:GLOBAL.C2/C3/C4` | The Markovian claim survives. C1 has never been tested with contrasting histories (`2B-3-AUDIT`). Cross-reference `QA-023`. |
| `GLOBAL.H1-COMPUTABLE` | **FALSE-AS-SCOPED (3×2)** | `d:GLOBAL.LONGCYCLE` | The converge machinery with a pointwise tie-pin does not compute the history-conditioned value. |

### `GLOBAL.ONEMISMATCH` → `GLOBAL.ONEMISMATCH-DIAG` + `GLOBAL.ONEMISMATCH-CURE`

| half | status | depends-on | why |
|---|---|---|---|
| `GLOBAL.ONEMISMATCH-DIAG` | **CLAIMED** | `—` | The diagnostic observation (symptoms consistent with one mismatch) is an interpretation. It does not depend on the cure being correct. |
| `GLOBAL.ONEMISMATCH-CURE` | **FALSE-AS-SCOPED (3×2)** | `d:GLOBAL.H1-COMPUTABLE` | The cure half assumed the long-cycle fixpoint works. It does not. |

### Alias rows re-pointed

- `QA-011`: re-pointed `d:GLOBAL.H1` → `d:GLOBAL.H1-MARKOV`; claim text now
  names both halves of the split.
- `QA-010`: re-pointed `d:GLOBAL.ONEMISMATCH` → `d:GLOBAL.ONEMISMATCH-DIAG`;
  claim text now names both halves.

### Convention added

§8 now carries a bullet on conjoined-row detection: a row whose claim text
joins two independently-falsifiable assertions with "and" is a latent version
of this defect. The register cannot lint for it (it is prose), but the rule
and the split precedent are recorded.

## claimlint before/after

| metric | before | after | Δ |
|---|---|---|---|
| rows parsed | 254 | 256 | +2 |
| C1a orphans | **14** | **10** | −4 |
| C1b alarms | 0 | 0 | — |
| C2 dangling evidence | 10 | 11 | +1 (new `AUDIT-DSPro` citation in `ONEMISMATCH-CURE` evidence; file exists but git-ignored) |
| calibration | PASS | PASS | — |

### The four removed orphans

| removed | chain |
|---|---|
| `GLOBAL.H1` | `d:GLOBAL.LONGCYCLE` [FALSE] → row replaced by split |
| `GLOBAL.ONEMISMATCH` | `d:GLOBAL.H1` → `d:GLOBAL.LONGCYCLE` [FALSE] → row replaced by split |
| `QA-011` | `d:GLOBAL.H1` → `d:GLOBAL.LONGCYCLE` [FALSE] → re-pointed at `H1-MARKOV` (UNTESTED) |
| `QA-010` | `d:GLOBAL.ONEMISMATCH` → `d:GLOBAL.H1` → `d:GLOBAL.LONGCYCLE` [FALSE] → re-pointed at `ONEMISMATCH-DIAG` (no FALSE ancestor) |

### The 10 remaining orphans

Unchanged — all pre-existing through `GLOBAL.C3` or `GLOBAL.F1` chains. None
trace through the three conjoined rows. This is correct: the split isolated the
`GLOBAL.LONGCYCLE` falsification so it only reaches rows that genuinely depend
on the computability half.

## Acceptance checklist

- [x] Three rows split, statuses assigned per half with citations.
- [x] Inbound edges re-pointed; **zero** rows left depending on a retired conjoined ID.
- [x] `bin/weizigo-claimlint` run, C1a before/after reported.
- [x] The convention note added to §8.
- [x] Nothing was upgraded or marked FALSE whole.
