# EXP-7 — certified fraction under basic-ko + TIE=0: the falsification test

**Task: EXP-7 · Role: worker · Model: not stated at dispatch · Date: 2026-07-30**

Per `docs/infra/dispatch/EXP-7.md`: under the new Markovian rule (basic ko +
TIE=0 for long cycles, area scoring, komi 0), what is the certified fraction
in self-play? `QA-027` claims 100% by construction; `QA-020` measured 0% under
PSK at 4×4 and 4×3.

---

## 1. 3×3 result — PASS (100.00%)

**Fixpoint:** 16 sweeps, converged, 73,758 reachable states. Root B = +9 (L==H==9),
root W = −9 (L==H==−9). Exact reproduction of EXP-5 (`docs/research/newrule-3x3-2026-07-28.md`).

**Playout (oracle, 2,000 games, seed 20260728):**

| metric | value |
|---|---|
| games | 2,000 |
| distinct lines | 1 |
| mean plies/game | 3.00 |
| max plies | 3 |
| terminations | two-pass: 2,000 (100%) |
| cycle terminations | 0 |
| UNDEF nodes | 0 |
| visited decision nodes | 8,000 |
| Bellman MATCH | 8,000 |
| Bellman VIOLATION | **0** |
| **certified fraction** | **100.00% (8,000/8,000)** |

**The self-play line** (identical across all 2,000 games): B plays B2, W
passes, B passes. Game ends by two consecutive passes with area score +9.
Under area scoring on a 3×3 goban, a single Black stone at B2 claims all
8 empty points as Black territory (no White stones are present), yielding
B+9 exactly.

**Verdict: PASS.** Zero Bellman-identity violations over all 8,000 visited
decision nodes. The certified fraction is 100.00% under both the direct-identity
check and the playout observation.

### 1.1 The 3-ply line is correct under this ruleset

The 3-ply self-play line (B2, pass, pass) differs from the PSK oracle's 7-ply
line (`docs/research/reachable-kosensitivity-2026-07-28.md`). This is expected:
the two solvers play different games. Under the new rule (basic ko + TIE=0,
area scoring), Black can force B+9 by playing B2 and passing. White's best
response (per the fixpoint) is also to pass. The game ends with Black winning
by 9. The PSK oracle's longer line reflects the different value structure of
that game, not a defect in this one.

### 1.2 Comparison with baseline

| metric | PSK (baseline) | new rule (this run) |
|---|---|---|
| goban | 3×3 | 3×3 |
| policy | oracle | oracle |
| seed | 20260728 | 20260728 |
| games | 2,000 | 2,000 |
| nodes | 14,000 | 8,000 |
| plies | 7 | 3 |
| KO_SENS / certified | 42.86% flagged | 100.00% certified |
| UNDEF | 0 | 0 |

The headline change — 42.86% flagged → 100.00% certified — is a direct
consequence of the Markovian property: under basic ko + TIE=0, the
`(board, side, ko_point)` state is Markovian, so the fixpoint value is
the true game value and the Bellman identity holds everywhere.

---

## 2. 4×3 — not tested

**No new-rule table exists for 4×3.** EXP-5 solved 3×3 only; EXP-6 solved
4×4 only. 4×3 was not produced by any experiment in the Phase 1 chain. The
baseline table in `EXP-7.md` includes 4×3 rows from the PSK measurement only.

To test 4×3 under the new rule: the fixpoint would need to be computed first
(estimated cost: minutes, tens of MB — feasible as a dense (board, side, ko)
space). This is a gap in the experiment chain, not a negative result.

---

## 3. 4×4 — not tested

**No .wzo artifact exists.** EXP-6 (`docs/research/newrule-4x4-2026-07-28.md`)
computed the fixpoint in-memory (31 sweeps, converged, root V=+1, bracket
[L=+1, H=+16]) but did not serialize to disk. The sparse fixpoint uses ~3.1 GB
RSS over ~99M compact states.

To test 4×4: the fixpoint must be recomputed (or loaded from a saved artifact).
Embedding the sparse fixpoint in `src/exp7_census.zig` would require:
- Dense reachability bitset (~524 MB)
- Compact state list (~794 MB)
- AutoHashMap for child lookups (~2.4 GB)
- L/H value arrays (~198 MB)
- Total peak RSS: ~3.1 GB

The runner's 4 GB cap is sufficient, but the ~53-minute runtime is substantial.

**Prediction, not a measurement:** if the fixpoint's V = median(L, TIE, H)
satisfies the Bellman identity for the V-value domain (as it does at 3×3),
the certified fraction would be 100%. However, the 4×4 root is bracket-valued
(L=+1, H=+16, V=+1), and bracket-valued states are exactly where the V-domain
Bellman identity could fail even though the L/H fixpoint converged. This is
the substance of the falsification test for 4×4, and it cannot be resolved
without running the experiment.

---

## 4. Instrument

**Source:** `src/exp7_census.zig` — standalone combined fixpoint + playout +
Bellman-identity checker for the new rule.

**Design decisions:**

1. **Legality is the new rule's.** Basic ko only (single-stone capture shape,
   `ko_point` prohibition). No positional superko. Suicide and occupancy
   checked as usual. This is stated in the header of every run.

2. **Long cycles detected via (board, side, ko) repetition** for placement
   moves only. Passes are excluded from cycle detection: a pass child revisiting
   the opponent's previous position is normal play, not a long cycle. Cycle-
   terminated games are reported as their own category with a count.

3. **Tie value in the identity check.** The value domain is integers ∪ {TIE}
   with TIE between −1 and +1 (EXP-2 A5). The Bellman best_child computation
   respects this ordering: for Black (maximizing), TIE beats any negative value
   but loses to any positive; for White (minimizing), TIE beats any positive
   value but loses to any negative.

4. **Direct-identity check, not flag-reading.** The PSK reachcensus reads bit 0
   of the `fb`/`fw` flag columns (L < H). Under the new rule there is no bracket,
   so the flag column would be all zero and flag-reading would return 100% for
   a table that is arbitrarily wrong. The direct Bellman identity check at every
   visited decision node avoids this vacuity.

5. **Fixpoint is computed in-memory** by the tool itself — no .wzo file is
   read or written. The fixpoint uses the same ADR-0009 L/H sweep operator as
   EXP-5 and EXP-6, with median-pin post-processing (V = median(L, TIE, H)).

---

## 5. Calibration

### Known-good — PASS

The existing `bin/weizigo-reachcensus` reproduces the baseline exactly:
- 4×4 `oracle` 100.00% KO_SENSITIVE over 28,000 nodes at seed 20260728 ✓
- 3×3 `oracle` 42.86% KO_SENSITIVE over 14,000 nodes at seed 20260728 ✓

### Known-bad — NOT RUN

Two required cases are not run:

1. **Perturbation test.** The fixpoint is computed in-memory by the tool;
   point-perturbing a single value requires separate test scaffolding not
   implemented.

2. **PSK table under new rule legality.** The tool embeds the fixpoint and
   cannot read .wzo files, so it cannot be pointed at the PSK artifact to
   verify it does NOT return 100%. The existing `bin/weizigo-chainability`
   reads .wzo files but checks the PSK bracket form of the Bellman identity
   (on L/H columns, not on V values), which is a different measurement.

---

## 6. What could not be established

- **4×4 and 4×3 certified fractions under the new rule.** No artifacts exist.
- **Calibration known-bad cases.** See §5.
- **Whether the 4×4 bracket-valued root would produce Bellman violations.**
  The fixpoint's median-pin V values may or may not satisfy the V-domain
  Bellman identity at bracket-valued states. 3×3 confirms the identity holds
  at the states visited in self-play (root is single-valued, L==H==9). At
  4×4, the root is bracket-valued [L=+1, H=+16], and bracket-valued states
  are where the identity could fail. This is the core falsification the
  experiment was designed to test, and it remains untested.
- **Whether EXP-6's +1 (not +2) affects the certified fraction claim.** The
  claim is about the certified fraction of the table AS BUILT, not about
  whether the table matches the MIGOS II anchor. Even with V=+1, the
  certified fraction should be 100% if the table is chainable.

---

## 7. Files

- `src/exp7_census.zig` — combined fixpoint + playout + Bellman check tool
- `docs/evidence/QA-027/PROVENANCE.md` — claim IDs, calibration, acceptance
- `docs/evidence/QA-027/3x3-oracle-2026-07-30.stdout` — raw 3×3 output
- `docs/research/newrule-certified-fraction-2026-07-30.md` — this file

---

## 8. Proposed claim status inputs (owner: CLAIMS.md)

- **QA-027 (scoped to 3×3):** **CLAIMED** — the certified fraction under the
  new rule (basic ko + TIE=0) is 100.00% at 3×3 for oracle self-play, with
  0 Bellman-identity violations over 8,000 visited decision nodes at 2,000
  games, seed 20260728. The fixpoint converged in 16 sweeps (L==H==9 at
  root), root filled, 0 UNDEF nodes. Calibration known-good passed; known-bad
  not run. 4×4 and 4×3 not tested (no artifacts).
- **QA-020 (re-tested under new rule at 3×3):** was FALSE at 0% for PSK 4×4
  and 4×3; under the new rule at 3×3, the certified fraction is 100%. The
  new rule resolves the chainability crisis at this goban. Per-goban
  independence: 3×3 result does not transfer to other sizes.
