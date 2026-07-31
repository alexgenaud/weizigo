# verify-battery spec audit — pass 0

```
Auditor:  unknown/spec-audit (independent seat, no shared context with author)
Date:     2026-07-31
Subject:  docs/infra/verify-battery/spec.md
Status:   NEEDS-FIX — 2 blockers, 3 critical, 7 must-fix, 4 should-fix
Verdict:  NEEDS-FIX
```

## Executive summary

The spec correctly diagnoses the problem (sixty unreviewed checkers = fleet-scale
corroboration of one bug) and proposes the right shape of solution (one instrument,
adversarially reviewed once, invoked sixty times). The invariant set covers the
known historical defect classes but has **two completeness gaps**, one of which is
a blocker. The acceptance criteria are mostly sharp, with A4 being the strongest.
The module decomposition is sensible but elides the cost of I5 at 4×4.

**Two blockers must be resolved before design work begins.** Five additional
findings are critical and should be resolved before strategy/design; the rest can
be addressed during design or implementation.

---

## 1. Findings — graded

### Blockers

| # | grade | what | detail |
|---|---|---|---|
| **B1** | **BLOCKER** | No invariant checks TIE value correctness | I7 checks DTT *distribution* (catches "all 255"), not whether TIE values are *correct*. A corrupted TIE column with a plausible-looking distribution passes every invariant in the set. The median(L,TIE,H) gadget, which QA-023 falsified at 3×2, exists precisely because TIE values can be wrong while L and H look sane. A defect that flips TIE signs, or writes L into the TIE column, would sail through. **Add an invariant: TIE = median(L, TIE, H) at every non-terminal, or TIE ∈ [L,H] at minimum.** |
| **B2** | **BLOCKER** | I5 feasibility at 4×4 under 4 GB is unaddressed | I5 requires Tarjan SCC over the full 4×4 basic-ko move graph. Navigator's SCC-4x4 brief (channel 054 §8) estimates ~9–13 bytes per node for 51,419,046 states — roughly 460–670 MB for node data alone, plus the frame stack and adjacency generation. That *probably* fits under 4 GB, but "probably" is not a spec. The spec must state the expected memory budget for I5 at 4×4 and provide a fallback (sample-only, or skip I5 above a goban-size threshold) if the budget is breached. A requirement that cannot be met is a spec defect, not an implementation challenge. |

### Critical

| # | grade | what | detail |
|---|---|---|---|
| **C1** | **CRITICAL** | No invariant checks the move set stored in the artifact | The artifact stores a move relation (or implies one via the fixpoint kernel's traversal). If the stored move set differs from the true legal move set — dropped moves in serialization, a stale move generator — L and H can still satisfy I4 (Bellman residual on the *truncated* move set) while being wrong. I5 partially covers this (it derives moves from the graph, not the artifact), but only for the cycle-reachability subset. **Add an invariant: for a sample of states, the artifact's move set equals the rules engine's legal move set.** |
| **C2** | **CRITICAL** | Known-bad fixture strategy for I5 is unspecified | R2 requires every invariant to have a known-bad fixture. I5 (`KO_SENSITIVE ⊆ cycle-reachable`) is a structural containment. What does a known-bad fixture for this look like? No obviously-constructable fixture exists — you can't easily produce an artifact where the containment fails without also failing other invariants. The spec should either (a) describe the fixture approach, (b) exempt I5 from R2 with explicit rationale, or (c) provide a constructed counterexample (an artifact with a ko-sensitive flag outside the cycle-reachable set, produced by corrupting a known-good artifact at a single slot). |
| **C3** | **CRITICAL** | "v1 artifact" is not identified by path or hash | A3, A4, I6, and I7 all refer to a "v1" 4×4 artifact with known properties (UNDEF census 24,187,097/65,534/65,534; DTT uniformly 255). The spec never says which file this is. `data/` contains three 4×4 `.wzo` files: `oracle-4x4.checkpoint.wzo` (writes-ON build, the AGENTS.md foreclosure), `oracle-4x4-parallel.checkpoint.wzo`, and `oracle-4x4-basicko-tie-area.wzo`. Is "v1" the checkpoint? The basicko-tie-area build? Something else? A4 is the sharpest acceptance criterion; its target must be unambiguous. **State the path and SHA256 of the v1 artifact.** |

### Must-fix

| # | grade | what | detail |
|---|---|---|---|
| **M1** | **MUST** | R5 doesn't state which invariants are exhaustive at which gobans | "Exhaustive by default; sampling only where exhaustive is infeasible" — but feasibility differs by goban and invariant. I4 (Bellman residual) at 4×4 means evaluating Φ on ~99M slots; that's expensive but feasible. I5 at 4×4 means Tarjan over 51M nodes — also feasible but uncalibrated. I4 at 5×4 would not be. The spec should state the expected evaluation mode per invariant per goban. Without this, two implementers of the same invariant will make different exhaustiveness choices. |
| **M2** | **MUST** | A2 "every artifact in `data/`" is underspecified | `data/` contains only 4×4 artifacts. The five gobans include 2×2, 3×2, 3×3, and 4×3 — their artifacts are in `artifacts/`. Does A2 mean `data/` literally (only 4×4), or all artifacts the project has? If the former, A2 contradicts "all five gobans." If the latter, the spec should say `data/` and `artifacts/`. Also: the root directory has `oracle-4x4.wzo` and `oracle-4x4.checkpoint.wzo`, and `untracked/` has additional `.wzo` files. Which are in scope? |
| **M3** | **MUST** | I5 exit-code behaviour on containment failure is ambiguous | If `KO_SENSITIVE ⊆ cycle-reachable` fails, the spec (R6) requires non-zero exit. But §7 says this is "a finding larger than this sprint" — suggesting it might not be the battery's defect. Does the battery exit non-zero (failing the run) or emit the finding and exit zero (the battery is working correctly; the artifact is suspect)? The spec should distinguish "invariant failed → artifact is bad" from "invariant failed → battery is wrong." Two exit codes, or a result field. |
| **M4** | **MUST** | I8: the 24 truncation-gap fixture states are not located | The spec says "the 24 known 2×2 fixpoint-vs-truncation mismatch states" but doesn't say where they are committed. Are they in a file the battery can load? A constant in source? ADR-0020 mandates them as a standing fixture but the spec doesn't give the battery a way to find them. |
| **M5** | **MUST** | A2 requires "exit codes and denominators recorded" — where? | The spec says the tool emits results plus proposed claim rows (R4, §2) but doesn't define the output schema. A2 adds a requirement on *what* is recorded without saying *how*. This is design territory, but the spec must at minimum require that the output format includes exit code and denominator fields, and that M1's schema covers them. |
| **M6** | **MUST** | No score-range sanity invariant | L and H values should be bounded: for a goban of area N, scores are in [−N, +N]. A buffer-overflow or sign-extension bug could produce values outside this range. None of I1–I9 would catch a score of +127 on a 2×2 goban. **Add: L,H ∈ [−area, +area] for all legal slots.** |
| **M7** | **MUST** | The spec doesn't state whether the battery imports shared code | The battery needs a move generator, colex addressing, and artifact loader. If it imports these from `src/` (the same code the solver uses), a bug in shared code is invisible to every invariant. The QA-023 chain proved that independent re-implementation is the only thing that finds defects. A5 partially addresses this (one invariant re-implemented), but if the battery's move generator is buggy, I4 (Bellman residual) will compute Φ wrong and still report 0 violations. **The spec should state the shared-code policy: which modules may be imported, which must be re-implemented.** |

### Should-fix

| # | grade | what | detail |
|---|---|---|---|
| **S1** | **SHOULD** | I5 should be separately invocable, not mandatory per-run | I5 reads no stored values and requires the full move graph (51M nodes at 4×4). It is the most expensive invariant and the only one independent of the artifact. Running it on every invocation for every artifact is wasteful — the move graph doesn't change per artifact. Make I5 an optional flag or a separate subcommand. The fleet run (M5) invokes it once per goban, not once per artifact per goban. |
| **S2** | **SHOULD** | A5 should require the chosen invariant to exercise the move relation | A5 requires one invariant re-implemented, auditor's choice. If the auditor picks I1 (pin_L == pin_H), that's comparing two integers from the same table — trivial, and it exercises none of the code that has historically contained defects. The spec should require the auditor's chosen invariant to be one that exercises the move relation: I4, I5, or I7. The precedent is clear: `2B-3-AUDIT` stopped one function call short of the defect and verified everything around it. |
| **S3** | **SHOULD** | No check on pass-dimension consistency | The artifact has three pass tables (passes=0,1,2). A pass transition moves from (board, side, ko, p) to (board, opponent, none, p+1). None of I1–I9 checks that the values across pass dimensions are consistent with this transition. A defect could write correct pass=0 values and garbage pass=1 values. |
| **S4** | **SHOULD** | M4 is the long pole; the spec should say so | M4 (graph invariant I5) needs Tarjan SCC over 51M nodes fitting under 4 GB. This is substantially harder than M2 (table lookups) or M3 (fixpoint checks on the artifact's stored move relation). The spec's concurrency claim ("M2, M3 and M4 are concurrent") is technically true but misleading — M4 will dominate the schedule, and its design work should start before M1's schema is frozen, not after. |

### Could-fix

| # | grade | what | detail |
|---|---|---|---|
| **O1** | **COULD** | I5 containment direction should be explicit | `KO_SENSITIVE ⊆ cycle-reachable` — but which direction is the inclusion? The spec says "every ko-sensitive slot must be cycle-reachable." That's correct per the structural theorem in channel 054 §2. But there's a subtlety: the ko-sensitive flags are computed by the fixpoint kernel on the artifact's move graph, while cycle-reachability is computed on the true move graph. If they use different move generators, a slot could be correctly cycle-reachable in the true graph but not in the artifact's graph. The spec should note that I5's soundness depends on the move graph being the same one used by the fixpoint kernel. |
| **O2** | **COULD** | The "sixty cells" count should be explicit | §1 says "roughly a dozen verification questions across five gobans: sixty cells." What are the dozen questions? The spec doesn't list them. The fleet run (M5) needs to know what to run. This can be deferred to design, but a one-sentence summary of the questions would help the auditor assess whether the invariant set covers them. |
| **O3** | **COULD** | No invariant checks the ko_point encoding | The artifact stores a ko_point per state. Is it always a legal point (0..N-1 or the "none" sentinel)? Is it consistent with the goban position (the ko point should be a location where a single-stone capture just occurred)? A corrupted ko_point could cause I4 to pass (Bellman on the corrupted move set) while the artifact is wrong. |
| **O4** | **COULD** | R7 concurrency limit has no enforcement mechanism | "At most two 4×4-scale invocations at once" — who enforces this? The runner? The battery itself? The spec should say. If the answer is "the human," the spec should state that explicitly so nobody assumes the tool self-throttles. |

---

## 2. Answers to the spec's five questions (§8)

### Q1: Is the §4 invariant set complete? Name what a defect could look like that none of I1–I9 would catch.

**No, it is not complete.** The most concerning gap (B1) is a corrupted TIE column with a
plausible-looking distribution. I7 catches the "all 255" case; it does not catch TIE
values that are wrong but varied. A defect that swaps the TIE and L columns, or writes
`TIE = (L+H)/2` instead of the correct fixpoint TIE, would pass every invariant.

Additional gaps:
- **Corrupted move set** (C1): if the artifact's stored successors omit legal moves, I4
  computes Φ on the truncated set and passes.
- **Score range violation** (M6): values outside [−area, +area] pass all invariants.
- **Pass-dimension inconsistency** (S3): garbage in passes=1 with correct passes=0
  passes I1–I9 because each pass table is checked independently.
- **Ko-point corruption** (O3): an invalid ko_point passes if it doesn't affect the
  invariants that read it.

### Q2: Is I5 in the right tool? It reads no artifact and needs the whole move graph — arguably a different instrument.

**Keep it in the battery, but make it optional.** The arguments for inclusion are
strong: (a) it is the only invariant that does not trust the artifact, making it the
single most valuable cross-check; (b) it answers the "21.32% ko-sensitive" question
with an independent instrument, which is exactly what the standing rules demand; (c)
the move graph is the same one M3 needs for I4 (Bellman residual), so the cost is
shared.

The argument for separation — it's expensive and doesn't depend on the artifact — is
addressed by making I5 separately invocable (S1). The fleet run invokes it once per
goban, not once per artifact per goban. This keeps it in the same codebase and result
schema while avoiding redundant computation.

### Q3: Does A5 (one invariant re-implemented) buy enough, or does the load-bearing one need re-implementing in full?

**One is enough as a gate, but which one matters critically.** If the auditor picks
I1 (pin_L == pin_H), the re-implementation is two integer comparisons and exercises
nothing. This is precisely the `2B-5` positive-control failure: the check passed but
covered none of the defective call site.

The spec should require (S2) that the auditor's chosen invariant be one that exercises
the move relation — I4 (Bellman residual) or I5 (SCC containment) — because those are
the invariants that (a) require building or traversing the move graph, (b) have
historically contained defects, and (c) are the load-bearing checks. I7 (DTT sanity)
is also acceptable: it caught the v1 defect and requires understanding the DTT column
semantics.

**Re-implementing all load-bearing invariants in full is not necessary** if A5 is
scoped to the right one. The point of A5 is to break the shared-blind-spot problem,
not to duplicate the entire battery.

### Q4: Is the M1-blocks-M2/M3/M4 serialisation worth its cost?

**Yes, with one caveat.** The harness (M1) defines the result schema, artifact loading,
and output format. Without a stable schema, M2/M3/M4 authors invent their own output
formats and M5 (fixtures + fleet run) parses N different formats. The serialisation
cost is one module's implementation time; the deserialisation cost of skipping it is
perpetual.

**Caveat:** M4 (graph invariant I5) is substantially harder than M2 or M3. It needs
iterative Tarjan over 51M nodes fitting under 4 GB, calibrated against committed
figures (3×2: max SCC = 1,676). The spec should acknowledge that M4's *design* work
(not implementation) can and should start before M1's schema is frozen. The schema
fields M4 needs — goban size, a flag for whether the move graph is reachable-from-empty
or all-legal, SCC census output — are stable enough to anticipate.

### Q5: §1 argues one instrument beats sixty. Where does that argument break down — is there a class of defect that only diverse implementations would find?

**Yes, there is.** The one-instrument argument breaks down when:

1. **Shared code between the battery and the solver.** If the battery imports the
   solver's move generator, colex addressing, and artifact loader, a bug in any shared
   module is invisible to every invariant. The QA-023 kernel audit found the defect
   precisely because the auditor reimplemented the fixpoint kernel in Python — no Zig
   code imported. The spec does not currently forbid shared dependencies (M7).

2. **The invariant set has a systematic blind spot.** If all nine invariants read the
   artifact through the same deserialization path, a bug in that path (e.g., wrong
   endianness, off-by-one in the table offset) makes every invariant agree on wrong
   data. This is the EXP-4-through-EXP-7 pattern: many implementations of the same bug.

3. **The battery is reviewed by one model/one seat.** The QA-023 chain proved that a
   model reviewing its own output is insufficient — the White-branch pin passed 1,133
   TIE evaluations. A5 addresses this in part (one invariant independently
   re-implemented), but the *review* of the battery as a whole should also be
   independent. The spec's "adversarially reviewed once" is good, but the reviewer
   should be a different model than the implementer, with no access to the
   implementation source beyond the spec and the result schema.

4. **The known-bad fixtures are constructed by the same person who implements the
   invariant.** A fixture that is too easy (e.g., an all-zeros artifact for I7 — which
   catches the "all 255" case but not subtler corruptions) passes R2 while providing
   false confidence. The spec should require that fixtures be reviewed independently,
   or that at least one fixture be constructed by someone other than the invariant's
   author.

The spec's A5 partially mitigates all four: an independent re-implementation of one
load-bearing invariant breaks the shared-code, shared-blind-spot, and same-model
problems for that invariant. Whether one invariant is enough depends on which one (Q3)
and whether the auditor has access to the battery's shared dependencies.

---

## 3. Requirement-by-requirement assessment

| id | grade | notes |
|---|---|---|
| R1 | PASS | One binary, parameterised. Correct shape. |
| R2 | **NEEDS-FIX** | I5 known-bad fixture is unspecified (C2). The spec needs a fixture strategy for the graph invariant or an explicit exemption. |
| R3 | PASS | Denominator discipline is correctly mandated. |
| R4 | PASS | Correctly prevents register corruption. |
| R5 | **NEEDS-FIX** | Exhaustiveness boundaries per invariant per goban not stated (M1). |
| R6 | PASS | Non-zero exit + named failure. Good. |
| R7 | **NEEDS-FIX** | Feasibility of I5 at 4×4 under 4 GB not established (B2). Concurrency enforcement mechanism not specified (O4). |

## 4. Invariant-by-invariant assessment

| id | grade | notes |
|---|---|---|
| I1 | PASS | Production-proven tell. Trivial to implement. |
| I2 | PASS | Production-proven. Exhaustive at all sizes. |
| I3 | PASS | Basic sanity. Exhaustive. |
| I4 | PASS | Load-bearing fixpoint check. Needs the move relation (shared with M3). Bellman residual is the right check. |
| I5 | **NEEDS-FIX** | See B2, C2, S1. Keep in battery; make optional; address feasibility. |
| I6 | PASS | Production-proven at 4×4. Exhaustive by construction. |
| I7 | PASS | Caught the v1 defect. Distribution report is good. But see B1 — does not check TIE *values*, only distribution. |
| I8 | **NEEDS-FIX** | Fixture states not located (M4). The battery needs to know where the 24 states are. |
| I9 | PASS | Anchor check for pipeline regression. Correctly notes the 4×4 +1 vs MIGOS +2 discrepancy as non-failure. |
| — | **MISSING** | TIE value correctness (B1) |
| — | **MISSING** | Score range sanity (M6) |
| — | **MISSING** | Move-set consistency with rules engine (C1) |

## 5. Acceptance-criterion assessment

| id | grade | notes |
|---|---|---|
| A1 | **NEEDS-FIX** | Depends on R2; same I5 fixture gap (C2). |
| A2 | **NEEDS-FIX** | "Every artifact in `data/`" contradicts "all five gobans" (M2). Output schema doesn't specify exit-code and denominator fields (M5). |
| A3 | PASS | Three sharp calibration targets with committed numbers. But note: the "v1 UNDEF census" target shares the v1 identification gap (C3). |
| A4 | **NEEDS-FIX** | Sharpest criterion, but v1 artifact not identified (C3). |
| A5 | **NEEDS-FIX** | Good principle, but should require the chosen invariant to exercise the move relation (S2). |
| A6 | **NEEDS-FIX** | Depends on I5 feasibility at 4×4 (B2). |

## 6. Module decomposition assessment

| id | grade | notes |
|---|---|---|
| M1 | PASS | Harness correctly scoped — no invariants, schema + CLI only. |
| M2 | PASS | Table invariants are independently implementable once schema is stable. |
| M3 | PASS | Fixpoint invariants need move relation — correct grouping. |
| M4 | **NEEDS-FIX** | See B2, S1, S4. M4 is the long pole; its design should start before M1 is frozen. I5 should be separately invocable. |
| M5 | PASS | Fixtures + fleet run correctly depends on M2/M3/M4. |

---

## 7. Summary of required changes before design

1. **Add TIE-value invariant** (B1) — blocker.
2. **Address I5 feasibility at 4×4 under 4 GB** (B2) — blocker. State expected memory budget; provide fallback if breached.
3. **Identify the v1 artifact by path and SHA256** (C3) — critical.
4. **Add move-set consistency invariant or state why it's out of scope** (C1) — critical.
5. **Specify known-bad fixture strategy for I5** (C2) — critical. Construct, exempt, or describe.
6. **State exhaustiveness boundaries per invariant per goban** (M1).
7. **Clarify A2 artifact scope — `data/` only, or `data/` + `artifacts/`?** (M2).
8. **Add score-range sanity invariant** (M6).
9. **State shared-code policy** (M7): which `src/` modules may the battery import?
10. **Locate the 24 truncation-gap fixture states** (M4).
11. **Distinguish "artifact-bad" from "battery-bad" exit codes** (M3).
12. **Require A5's chosen invariant to exercise the move relation** (S2).

## 8. Verdict

**NEEDS-FIX.** The spec's architecture is sound and its diagnosis of the problem is
correct. The two blockers (missing TIE invariant, unaddressed I5 feasibility) must be
resolved before design work begins. The three critical items (v1 identification, move-set
invariant, I5 fixture strategy) should be resolved before or during strategy. The
must-fix items can be resolved during design without blocking strategy work.

The spec earns its central claim — one reviewed instrument beats sixty — but only if
the invariant set is complete and the battery shares no code with the solver. Both
conditions are currently unsatisfied.
