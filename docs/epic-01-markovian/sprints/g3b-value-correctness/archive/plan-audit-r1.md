# T332 — plan audit gate: G3b value-correctness pass0 PLAN, Revision 1

```
Task: T332 · Role: plan audit gate · Model: kimi-k2.7-code:cloud · Date: 2026-08-03
Plan audited: docs/epic-01-markovian/sprints/g3b-value-correctness/pass0/plan.md
Revision: 1 · Commit: d05d582 · Status: PROPOSED
```

## Findings

| ID | grade | file:line | finding |
|---|---|---|---|
| F1 | critical | `pass0/plan.md:60-77`, `:99-102` | The C-A1/C-A2 closure design assumes the loaded table is keyed by `(colex, side, ko, passes)` and contains ~146 M entries, with membership by binary search over that key and a visited bitset of ~18 MB. The actual sprint artifact is `data/oracle-4x4.checkpoint.wzo`, whose header is `WZO1`, `total = 3^16 = 43,046,721`, `column_count = 6`, with no `ko` or `passes` dimension. A binary-search lookup of `(colex, side, ko, passes)` is therefore undefined for the table that G3b must verify, and the visited-bitset size is computed for a non-existent index. This makes the core C-A1/C-A2 mechanization unsound without a reconciliation step (e.g., expand WZO1 into a full state table, or redefine closure membership over the WZO1 `(colex, side)` slice and account for ko/passes children explicitly). |
| F2 | must | `pass0/plan.md:271`, `:435` vs `pass0/spec.md:433-439` | The row table contains only `I5-4x4`. Spec §7.2 requires the first I5 seeded-defect control to run at 3×2 because the 2×2 all-legal graph is entirely cycle-reachable. The effort table mentions “calibration at 3×2 (max SCC = 1 676)”, but no row, `needs` edge, or wave assigns the 3×2 run. The ladder requirement is therefore not mechanized and could be skipped. |
| F3 | must | `pass0/plan.md:275` vs `pass0/spec.md:197-202` | Spec edge 5 states the discharge row needs `M1-invert … M10-invert`. The plan substitutes `DISCHARGE needs KEY-4x4, CLOSURE, I4-4x4, I5-4x4, I11, BATT-HEALTH` — the check rows expected to kill the mutants. The mutation-adequacy currency is the mutant kills, not the check rows themselves; the current `needs` relation can pass even if a mutant-inversion label is missing or stale. Either the row table should surface the seven mutant-kill prerequisites explicitly, or the spec edge should be renegotiated via a plan-amendment halt. |
| F4 | should | `pass0/plan.md:325` | The differential invariant / key-agreement comparison harness is described as written by “a third author (or A)”. Allowing the kernel author (A) to also write the comparison harness weakens the independent-comparison guard that the QA-023 rules were written for. The harness author should be required to be distinct from both MG-KERN (A) and R8 (B). |
| F5 | could | `pass0/plan.md:84-89` | The ≤40-sweep budget is justified by “T134's EXP-3 census converged in 29 sweeps,” but T134's precedent is the I5 SCC/Tarjan memory plan, not the C-A1/C-A2 closure sweep. The number is plausible, but the citation is misattributed; the accept.md should record the actual closure sweep count as a measurement rather than lean on the cited precedent. |

## Verdict

**NEEDS-FIX.**

The plan is coherent on the feasibility decisions, scope boundaries, R8 independence discipline, third-language ruling, and third-language escalation trigger. The row table covers all five spec §3 dependency edges, TDD ordering, and the `build.zig` serialization choke point. However, F1 is load-bearing: the closure algorithm is written against a table schema that the actual checkpoint does not have. Until the artifact format (WZO1) is reconciled with the closure membership predicate, the C-A1/C-A2 checks cannot be correctly implemented, and the memory budget is built on an incorrect row count. F2 and F3 are must-fix because they leave required ladder/edge mechanizations implicit. F4 and F5 are lower-grade but should be addressed in the same revision.

## Auditor identity and method

Fresh-session document review against `pass0/spec.md` Revision 2 (RATIFIED), `sprint.md`, `DIRECTION.md` + Amendments 1 & 2, `PHASES.md`, `AXIOMS.md`, `pass0/design-M1.md` §4.6, `pass1/mutants.md`, and the artifact header of `data/oracle-4x4.checkpoint.wzo`. No `untracked/msg/` channel traffic, prior audits, or author framing was read before forming findings. Every finding cites a file:line range. The artifact header was verified with `xxd` and a short Python parse (`magic=WZO1`, `total=43046721`, `column_count=6`).

## Gate-holder disposition (Orcha/Fable, 2026-08-04)

Verdict accepted: **NEEDS-FIX** — the plan returns to the builder for Revision 2; round 2
of 2 re-audits after. One finding added by the gate-holder (F6).

| ID | disposition |
|---|---|
| F1 | **confirmed, escalated into the spec, and re-rooted** — the auditor parsed the wrong-artifact's header and was right that it can't hold the k=1 state; the deeper defect is that **spec §2.3 named that artifact** (`data/oracle-4x4.checkpoint.wzo`, WZO1, 2026-07-21 — PSK-era residue ruled untrustworthy at the pivot). The sprint's artifact is `untracked/oracle-v2/oracle-4x4-v2.wzo2` (WZO2, 518,123,097 B, SHA-256 `0c3366f0…`, header count 24,318,165 = A094777 — verified by the gate-holder with xxd). Spec amended to Revision 3 (sprint-owner authority). Plan Rev 2 must: name the WZO2 artifact + sha; rebuild the closure membership predicate and memory budget against the real WZO2 schema (the oracle-v2 format doc is the authority, not AGENTS.md's 258 MB figure — that is the WZO1 file size); keep the fallback trigger. |
| F2 | **accepted** — plan Rev 2 mechanizes the I5 first-seeded-control-at-3×2 as part of the I5 row's bars (red-then-green shown before the 4×4 reading), not effort-table prose. |
| F3 | **accepted as a text fix** — DISCHARGE's bar becomes the seven mutant assertions inverted in `vb_mutants.zig` (mechanized, checkable), not merely the six check rows closed; the `needs` edges stay row-level because managent edges are rows. |
| F4 | **accepted** — the comparison-harness author must be distinct from both MG-KERN's and R8's authors; "(or A)" is dropped. |
| F5 | **accepted** — the EXP-3 citation is relabelled an analogy; the actual closure sweep count is an accept.md measurement. |
| F6 | **gate-holder finding (new, must)** — ko-dimension coverage of the move relation is nowhere explicit: SMD1's slice is `ko=NONE, passes=0` at every rung, so I11 never compares at a ko-active state and the spec's ko-recapture seeded control was blind by construction (spec §7.2 amended in Rev 3: suicide mutant on the slice). Plan Rev 2 must commit MG-INV's exhaustive 2×2/3×2/3×3 comparison to the full `(pos, side, ko, passes)` space including ko≠NONE, with a ko-recapture mutant caught at a ko-active state. This is the T265 defect family. |
