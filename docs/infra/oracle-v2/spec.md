# oracle-v2 — SPEC

```
Status:   PROPOSED — awaiting independent audit, then human ratification
Author:   Opus/Navigator (claude-opus-5[1m]) · 2026-07-31
Process:  docs/infra/sprint.md (un-retirement proposed in channel msg 062)
Tier:     A — new state representation + format contract + verifier changes
Audit:    this document, before any strategy or design work begins
```

## 1. The problem

The 4×4 solve is correct and verified. **The artifact is not the solve.**

`src/exp6_solve.zig` computed the value of every state on the key
`(goban, side, ko_point, passes)` — 99,133,036 compact states — and Kimi-k3/T104
verified the result exhaustively: **0 / 99,133,036 Bellman violations**.

`src/exp6_solve.zig:1316-1339` then wrote the artifact through two filters:

```zig
if (passes != 0) continue;      // discards every one-pass state
if (ko != KO_NONE4) continue;   // discards every ko-pending state
```

**48,505,262 of 99,133,036 values reach disk.** The shipped key is
`(pattern, side)` — dense over `3^16` raw colex, two columns. There is nowhere
in it to record that a ko is pending or that a pass is standing.

Three consequences, all measured (channel msgs 058–060):

1. **The engine refuses the table.** `weizigo-oracle` logs `UNCHAINABLE` and
   plays a history-free fallback on **10 of 10** opening plies with the v1
   artifact, against **0 of 6** with the old PSK artifact. EXP-9's Bellman
   identity checks (A1 at the node, A2 at the chosen child) fail because a
   parent's optimal child is often a ko-pending or one-pass state whose value
   was discarded; the slice substitutes the no-ko value of the same pattern.
2. **The depth-to-terminal column was never computed** — `@memset(db, 255)` at
   `src/exp6_solve.zig:1311`, never written again. All 43,046,721 slots are
   `DTT_FAR`, in both v1 and the old PSK artifact.
3. **The cycle convention is baked in.** Only the pinned `V = median(L, 0, H)`
   is stored; `L` and `H` are discarded except for one `KO_SENSITIVE` bit. A
   different cycle convention requires a new solve.

Net: the current 4×4 engine is a **regression** against the PSK artifact it was
meant to replace, and no pin-rule result can repair it — ADR-0020's Markov key
has four components and the artifact carries two.

## 2. What to build

An artifact and a consuming engine that preserve the full Markov key, plus the
value bracket, plus a real progress measure.

**This spec does not choose the layout, the encoding, or the algorithm.** Those
are `design.md`. This document states requirements and how they will be checked.

## 3. Requirements

| id | requirement | rationale |
|---|---|---|
| **R1** | The artifact key is `(goban, side, ko_point, passes)`. No dimension is projected away. | §1 — the defect |
| **R2** | Store `L` and `H`, not a pinned `V`. The cycle convention is applied by the **reader**, not baked into the data. | one artifact answers TIE=0, no-result and score-on-cycle; decouples this sprint from the pin-rule reconciliation (Wave 1 task 1) |
| **R3** | Depth-to-terminal is **computed** during the fixpoint and stored. | §1(2); a value table is not a policy — under TIE=0 a winning player can shuffle forever without a progress measure |
| **R4** | The format is self-describing: `rules_id`, layout version, and the key encoding documented in the format contract, not inferable only from source. | v1's projection is documented nowhere; `rules_id = 2` was written by a tool the reader did not know about |
| **R5** | The engine tracks the ko point at play time and looks up the **matching** key. | otherwise R1 buys nothing |
| **R6** | Legality enforcement is selectable at run time: `basic-ko` \| `psk` \| `ssk`. Default and behaviour on mismatch with `rules_id` must be stated and logged. | the human's 2026-07-31 directive; enforcement need not be Markovian because the engine holds the history |
| **R7** | One documented command regenerates the artifact from a clean clone, byte-identical to a recorded SHA-256. | `data/` is gitignored and no `.wzo` is in history — the recipe ships, not the artifact |
| **R8** | Any relaxation of a reader/verifier check is called out explicitly in `design.md` and audited. | the `decode` widening of 2026-07-31 went in un-audited; verifiers are where this project has been burned |

**Out of scope**, explicitly: solving a new ruleset; the SCC-scoped memo; any
goban other than those already solved; performance work beyond the budget in
R9 below; changing the value semantics of the solve itself.

## 4. Acceptance criteria

Falsifiable, numeric, and each states what a **wrong** answer scores. Any
criterion that today's artifact passes trivially is marked so — it proves
nothing on its own.

| id | criterion | today's v1 artifact scores |
|---|---|---|
| **A1** | **Refusal rate.** On a scripted 20-ply self-play opening, `UNCHAINABLE` refusals ≤ the old PSK artifact's rate on the same script. | **10/10 refused — FAIL.** Old PSK: 0/6. This is the headline criterion. |
| **A2** | **Bellman residual = 0** on the full key, measured **after a decode round-trip**, not on the in-memory solve. Report the denominator. | untestable — the key does not exist on disk |
| **A3** | **Colour inversion, exhaustive:** `L(−pos, −side) == −H(pos, side)` and `H(−pos, −side) == −L(pos, side)` for every stored state. | untestable — `L`/`H` not stored |
| **A4** | **Pin census reported:** `L==H`, `pin_T`, `pin_L`, `pin_H`, with `pin_L == pin_H`. | never run at 4×4. The invariant whose violation (`pin_L=142, pin_H=0`) exposed the `fixpoint_kernel` bug |
| **A5** | **Round-trip identity:** `decode(encode(x)) == x` for every state, exhaustively at 2×2/3×2/3×3, sampled with a stated denominator at 4×4. | passes trivially for v1 — proves nothing about R1 |
| **A6** | **Known-bad calibration:** a deliberately corrupted artifact (one perturbed value, one dropped ko state, one zeroed DTT column) **fails** A1–A5, and the failure is named. | not run |
| **A7** | **Gate chain reproduced** from the new pipeline end to end: 2×2 = 0, 3×2 = 0, 3×3 = +9. A pipeline that cannot reproduce known anchors is not trusted at 4×4. | v1 passes — carry it forward, do not treat as new evidence |
| **A8** | **DTT is non-constant** and consistent: terminals have DTT 0, and every non-terminal's DTT exceeds at least one child's. Report the distribution. | **1 distinct value across 43,046,721 slots — FAIL** |
| **A9** | **Reproducibility:** clean clone → documented command → SHA-256 match. | never attempted |
| **R9** | **Budget:** peak RSS ≤ 4 GB (the `tools/runner` cap; the host kernel-panicked at 12.5 GB on 2026-07-29), wall ≤ 4 h, artifact ≤ 600 MB. | v1: 3.1 GB, 53 min, 258 MB |

**Sizing note for the auditor, not a design decision.** EXP-3 measured 4×4 at
51,419,046 `(goban, side, ko)` triples over 29,497,329 distinct `(goban, ko)`
addresses and projected 177 MB at 6 B/address, 354 MB with `passes` folded. The
ko dimension adds ~12% over the 45,734,854 no-ko reachable states. R9's 600 MB
ceiling is set against those numbers with headroom, not from first principles.

## 5. Modules — the delegable units

Four modules, **disjoint file ownership**, so they can be held by different
agents concurrently under the one-writer rule.

```
        M1 FORMAT  (blocks everything)
         /      \
   M2 SOLVER   M3 ENGINE
         \      /
       M4 ACCEPTANCE
```

| id | module | owns | depends on |
|---|---|---|---|
| **M1** | **Format.** The WZO2 key encoding, column schema (`L`, `H`, DTT, flags), header, `encode`/`decode`, round-trip tests. Includes the R8 verifier review. | `src/artifact2.zig` (new), `docs/infra/oracle-v2/format.md` (new) | — |
| **M2** | **Solver side.** Compute DTT during the fixpoint; serialise the full key with no projection. | `src/oracle_v2_build.zig` (new) | M1 design ratified |
| **M3** | **Engine side.** Reader integration; track `ko_point` and `passes` at play time; full-key lookup; the R6 enforcement modes. | `src/gtp.zig` | M1 design ratified |
| **M4** | **Acceptance harness.** A1–A9 as runnable checks, plus the A6 known-bad fixtures. | `src/oracle_v2_accept.zig` (new), `docs/evidence/ORACLE-V2/` | M2, M3 |

**M1 blocks M2 and M3 and must not be parallelised with them.** Two agents
improvising a format concurrently is the EXP-4→EXP-7 buffer-aliasing failure
waiting to happen. M2 and M3 may run concurrently once M1's `design.md` has
passed audit.

**No module may touch** `src/retro.zig`, `src/oracle.zig`, `src/rules.zig`,
`src/solve.zig`. M3 touches `src/gtp.zig`, which is therefore held for the
duration and must not be given to another sprint.

**Overlap declared:** M4 duplicates invariants that `verify-battery`
(`docs/infra/verify-battery/spec.md`) will also implement. This is deliberate
and time-boxed — coupling the two sprints would serialise them. A later task
merges M4's checks into the battery; that task is out of scope here.

## 6. What would falsify success

Stated so the audit can check that success is not tautological:

- **A1 does not improve.** If a full-key artifact still refuses at the old
  artifact's rate or worse, then the projection was not the cause and §1's
  diagnosis is wrong. That is the single most important negative result this
  sprint can produce and it must be reported, not worked around.
- **A2 fails after round-trip while the in-memory solve passes.** Serialisation
  is lossy in a second, unidentified way.
- **R9 is breached** — the full key does not fit the budget, and the sprint
  becomes a compression problem rather than a serialisation one.
- **A6 passes when it should fail** — the harness cannot detect corruption, and
  every other criterion becomes uninterpretable.

## 7. Dependencies outside this sprint

- **Wave 1 task 1 (pin-rule reconciliation)** — *informational, not blocking.*
  R2 stores `L` and `H`, so whichever way the reconciliation lands, the artifact
  does not change; only the reader's selection rule does. If the reconciliation
  had blocked this sprint, R2 would be the wrong requirement.
- **The rule-mismatch ruling** (channel 056 §0.1) — the human's call on whether
  the player enforces the table's rule. R6 makes it a run-time flag, so the
  ruling sets a default rather than gating the build.

## 8. For the auditor

Per `DELEGATOR.md` rule 5 you should know less than the author. Grade findings
**blocker / critical / must / should / could**; return **PASS / NEEDS-FIX /
REDO**. Write to `docs/design/oracle-v2/pass0/spec-audit.md`.

Questions worth asking, offered without answers:

1. Is A1 the right headline criterion, or is a refusal-rate improvement
   achievable without fixing the underlying defect?
2. Does R2 (`L`/`H` instead of `V`) actually decouple this sprint from the pin
   rule, or does something downstream still need a single value?
3. Is the M1-blocks-M2/M3 serialisation necessary, or is it caution that costs
   a day?
4. Are the "today's v1 scores" in §4 honest — is any criterion one that a wrong
   implementation would also pass?
5. R9's budget derives from EXP-3's projection. Is that projection load-bearing
   enough to verify before committing to it?
