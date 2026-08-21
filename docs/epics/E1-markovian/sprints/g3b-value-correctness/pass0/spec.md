# G3b value correctness — pass0 SPEC

```
Task: T323 · Role: worker · Model: not stated at dispatch · Date: 2026-08-03
Revision: 5 · Status: RATIFIED (Rev 2 ratified 2026-08-03 via spec audit T329 at 68a3b71; Rev 3, 2026-08-04, corrects the artifact identity — T332 F1, a premise defect found by the plan audit's artifact parse, missed by document review twice, sprint.md:93 confirmed again; Rev 4, 2026-08-04, repoints the artifact to its deployed path per human ruling — §2.3 only, no numbers changed)
Sprint owner: Orchestrator
```

**This is the spec bookend for the G3b value-correctness sprint** — prose only,
no code. It states the goal, the check inventory, the dependency edges, the
independence discipline, the known defects in the path, the feasibility
questions for plan.md, and the ladder rungs. The plan (`plan.md`) is a later
row, written after this spec is audited and ratified.

**Inputs.** `AGENTS.md` · `DELEGATEE.md` · `sprint.md` ·
`077-orcha-to-all.md` (commissioning draft) · `DIRECTION.md` + Amendments 1
and 2 · `PHASES.md` §The G3 gate is split ·
`sprints/verify-battery/pass1/spec.md` (check inventory I4, I5, I11, C-A1,
C-A2, R8, SMD1) · `sprints/verify-battery/pass1/mutants.md` (seven
known-unkilled mutants) · `findings/T273-kernel-ko.json` (kernel already
has ko/stateKey) · `AXIOMS.md` (requirement tree).

---

## 1. The goal — the sentence it changes

**From** (`PHASES.md` §The G3 gate is split, honest summary):

> The artifact is structurally complete, value-unverified.

**To:**

> The L/H values in the 4×4 table are the fixpoint values of ruleset R, closed
> under the Bellman operator, with no fabricated or fallback rows.

This means:

- **I4 passes with zero Bellman violations** on every non-terminal slot in the
  reachable state graph, where the Bellman operator Φ is computed by the battery's
  independent move generator (R8), not by the solver's.
- **C-A1 forward closure passes with zero children-missing** — every child of
  every reachable state under R is present in the table, via the kernel move
  generator.
- **C-A2 backward closure passes with zero reachable-not-present** — every
  state reachable from the fresh-start root under R is present in the table,
  via the kernel move generator computed backward from the root.
- **I11 move-set consistency passes with zero mismatches** — the battery's
  independent legal-move set (R8) agrees with the solver's at every state in
  the sampled space, via SMD1 as the solver-side truth source.
- **Where L==H, the value is the game-theoretic fresh-start score under R;**
  where L<H, the bracket [L,H] is the true bracket under the loopy-game
  fixpoint (the bracket rate is a measurement, not a violation; per E3,
  `GLOBAL.AXIOM-BRACKET`).

### 1.1 Discharges or demotes

On success, this sprint discharges **G3b** (the gate is cleared) and promotes
the following from their current status:

| claim ID | current status | target status after G3b |
|---|---|---|
| `4x4.C1` (fresh-start scores correct at 4×4) | UNTESTED | CLAIMED (value-correctness verified by closure + Bellman) |
| `GLOBAL.H4` (partial Bellman verification) | CLAIMED | CLAIMED — claim text updated to remove "partial"; no status change because CLAIMED is the ceiling pending Phase 3 |
| `4x4.FP1` (L/H are least/greatest fixpoints) | UNTESTED (checks 1–2); check 3 PASSES | CLAIMED (Bellman residual = 0 verifies fixpoint property) |

The seven known-unkilled mutants from `mutants.md` that invert (M1, M2, M3, M4,
M8 — plus M9 and M10 which are meta) move from EXPECTED-to-invert to KILLED,
and the five dependency edges from DIRECTION Amendment 2 are satisfied for the
claims above.

On demotion: a check that finds violations demotes `4x4.C1` and `4x4.FP1` to
FALSE-AS-SCOPED (scoped: the specific entries are wrong) and revises or retires
`GLOBAL.H4` so it no longer claims completeness; G3b stays open.

### 1.2 What this sprint does NOT claim

- **Not a real-game oracle.** The table remains fresh-start only; C2 is
  FALSE-AS-SCOPED at 3×2 and this sprint does not touch it.
- **Not a PSK oracle.** Positional superko is not the generation target
  (ADR-0013).
- **Not history-independent.** The L==H region is fresh-start exact (C1), not
  real-game exact — T13 falsified C2 at 3×2.
- **Not verified by the #2 auditor.** The auditor is a separate gate; this
  sprint checks the artifact against the axioms, not the solver against itself.
- **Not a cross-size claim.** 4×4 value-correctness is not evidence at any
  other goban size.

---

## 2. Check inventory

Each check carries a pass condition stated as **violation vs measurement** (per
T287: a wrong pass condition is itself a defect). A check that cannot fail is
not a check.

### 2.1 Check table

| check | claim ID served | runnable now? | pass condition (violation threshhold) | measurement (non-violation) | calibration control |
|---|---|---|---|---|---|
| **C-A1 forward closure** | `Z-STATE-REACH`, `Z-COMPLETE-ENUM` | **NO** — needs kernel move generator | Every child of every reachable state is in the table: `children_not_in_table == 0` | count of reachable states, total children, average branching factor | Synthetic mutant: one entry deleted → `children_not_in_table > 0` must be caught. Seeded at 2×2 first (ladder discipline). |
| **C-A2 backward closure** | `Z-STATE-REACH`, `Z-COMPLETE-ENUM` | **NO** — needs kernel move generator | Every state reachable from the fresh-start root under R is present: `reachable_not_in_table == 0` | reachable-set size, % of colex space reachable | Synthetic mutant: same deleted-entry mutant as C-A1 — the missing entry must be flagged by both directions. |
| **I4 Bellman residual** | `Z-CONVERGE-FIX` | **NO** — needs battery R8 move generator (the sprint deliverable) | At every non-terminal in the reachable graph: `L ≠ Φ(L)` or `H ≠ Φ(H)` count == 0 | bracket rate, pin census, sweep-equivalent measurement | Synthetic mutant: one slot's value corrupted → Bellman violation > 0. 2×2 first. |
| **I11 move-set consistency** | `Z-R-MOVE` | **NO** — needs SMD1 (solver-side dump) AND battery's R8 move generator | At every state in the sampled space (sample size and distribution are plan.md decisions): battery's legal-move set == solver's legal-move set, `mismatches == 0` | sample size, denominator, mismatch rate | **Null control + seeded-defect control before first reading counts** (see §4). 2×2 exhaustive first. |
| **I5 SCC containment** | `Z-CONVERGE-FIX` | **NO** — needs battery R8 move graph | Every KO_SENSITIVE slot is cycle-reachable: `ko_not_cr == 0` | KO_SENSITIVE count, cycle-reachable count, KO_SENSITIVE rate | Synthetic mutant: KO_SENSITIVE spuriously set on a non-cycle-reachable slot → I5 must catch it. Per `mutants.md` M3, the 2×2 all-legal graph has every state cycle-reachable, so the first seeded-defect control runs at 3×2. |
| **G1/G3 key agreement** | `Z-R-STATE`, `Z-STATE-KEY` | **NO** — needs kernel state-key encoder (T273 has the production one; the battery's consumer encoder is R8, needed for comparison) | Producer key == consumer key at every state: `key_mismatches == 0` | total states checked, denominator | Synthetic mutant: one bit flipped in the key → must be caught. This is the T178/T193/T265 defect family — three historical defects, zero current battery coverage. |
| **R8 move-generator correctness** | `Z-R-MOVE` (supports I4, I5, I7, I11) | **NO** — is the sprint deliverable, not a pre-existing check | The battery's independent move generator agrees with the kernel's at 2×2 exhaustive + the sampled 4×4 space: `mismatches == 0` | sample size, denominator | Synthetic mutant: a known-incorrect move (e.g. ko-violating recapture allowed, suicide allowed) → must be caught. The kernel's move generator is compared against the battery's at every ladder rung. |

### 2.2 Checks carried forward from the battery that this sprint does NOT re-specify

These are specified in `pass1/spec.md` and run as part of the battery; they are
not this sprint's deliverable but their pass/fail on the 4×4 artifact is
**input** to the G3b verdict:

| check | already specified in | note for G3b |
|---|---|---|
| I1 pin census | pass1/spec.md §3.1 | measurement only; no pass/fail |
| I2 colour inversion | pass1/spec.md §3.1 | expected to pass on all artifacts; already killed M5, M7 |
| I3 L ≤ H | pass1/spec.md §3.1 | expected to pass; L<H is expected per E3, only L>H is a violation |
| I6 UNDEF census | pass1/spec.md §3.1 | expected to pass; legal position counts vs OEIS |
| I7 DTT sanity | pass1/spec.md §3.1 | expected to pass on the checkpoint; known to fail on v1 (baseline) |
| I8 truncation-gap regression | pass1/spec.md §3.1 | 2×2 only; n/a at 4×4 |
| I9 anchors | pass1/spec.md §3.1 | root=+1 at 4×4; measurement if no committed anchor |
| I10 TIE median | pass1/spec.md §3.1 | TIE ∈ [L,H] at every non-terminal; expected to pass |
| I12 score range | pass1/spec.md §3.1 | L,H,TIE ∈ [−area, +area]; expected to pass |

### 2.3 What constitutes "G3b passes"

All of these must hold simultaneously against the 4×4 oracle-v2 artifact
(**`data/oracle-4x4-v2.wzo2`**, WZO2, 518,123,097 bytes, SHA-256
`0c3366f0…` — the artifact G3a's structural-completeness evidence chain
(T266/T277) verified, reproducible nine independent ways). **Not**
`data/oracle-4x4.checkpoint.wzo`: that is the 2026-07-21 WZO1 checkpoint from
the abandoned PSK era (header `total = 3^16`, no ko/passes dimension — it
cannot even represent the k=1 state this epic is about), named here in
Revisions 1–2 by mistake and corrected by amendment 2026-08-04 (T332 F1).

**On the path** (Rev 4, human ruling 2026-08-04). Revision 3 named the sprint
build path `untracked/oracle-v2/oracle-4x4-v2.wzo2`, which made `untracked/` —
`sprint.md:62`'s "where evidence goes to die" — load-bearing in a ratified
spec. The oracle-v2 spec §4 F9 had already ratified `data/oracle-4x4-v2.wzo2`
as the deployed path with a hash-then-deploy rule; the file had simply never
been promoted out of the build area. It now is: the `data/` copy was verified
against the recorded build hash (`shasum -c artifacts/SHA256SUMS`, 12/12 OK)
and loads in the engine (24,318,165 groups / 99,133,036 entries, 0 misses, 0
fallbacks). **The `untracked/` build remains in place and is the hash of
record**, so the as-run reproduction commands in the T266/T277/T309 evidence
documents still resolve; new work reads the `data/` path. Both are listed in
`artifacts/SHA256SUMS` and are byte-identical, so a check may read either — but
it must assert the SHA-256 it read, not the path it read it from, because the
path is now ambiguous and the hash is not.

The conditions:

1. **I4:** 0 Bellman violations on every non-terminal slot reachable from the
   fresh-start root, with Φ computed by the battery's independent move
   generator (R8). KO_SENSITIVE-set slots with KO_SENSITIVE children:
   documented as a measurement, not a violation (the child's value is the
   fixpoint value — the Bellman equation still holds with the stored values,
   but the battery's Φ recomputation may diverge at cycle boundaries if it
   uses a different cycle-breaking convention; any divergence is a finding, not
   automatically a violation).
2. **C-A1:** 0 children-not-in-table — for every state in the table reachable
   from the fresh-start root, every child state reachable by a legal move under
   R (kernel move generator) is present in the table.
3. **C-A2:** 0 reachable-not-in-table — every state reachable from the
   fresh-start root via the kernel move generator is present in the table.
4. **I11:** 0 mismatches between the battery's legal-move set and the solver's
   at the sampled states (sample size and distribution are plan.md decisions;
   exhaustive at 2×2, 3×2, 3×3; sampled at 4×4).
5. **Key agreement (G1/G3):** 0 mismatches between producer and consumer keys
   at every state in the sampled space.
6. **All seven T291 known-unkilled mutants invert to KILLED** — M1, M2, M3, M4
   (G1/G3), M8 (G2/C-A1/C-A2), M9 (meta: battery-stubbed), M10 (meta:
   alias-control). M9 and M10 are meta-gaps acknowledged in `mutants.md` §5;
   they must be addressed (a battery-health check and an
   independent-reimplementation check) before G3b discharges.

### 2.4 The KO_SENSITIVE I4 caveat — written so it is not misread

The foreclosure states: "The committed ko-sensitive values are NOT trustworthy"
(`AGENTS.md`). The checkpoint artifact's KO_SENSITIVE column is distrusted. The
I4 Bellman check on KO_SENSITIVE-set slots may produce violations for one of
two reasons:

- **(a) Genuine value corruption** — L ≠ Φ(L) at a state whose children are not
  KO_SENSITIVE. This is a real violation and G3b fails.
- **(b) Cycle-boundary recomputation divergence** — the battery's Φ recomputes
  the Bellman step from stored child values, but at a KO_SENSITIVE-set child,
  the stored value is distrusted, so the recomputed Φ may not match. This is a
  **measurement**, not a violation, until the KO_SENSITIVE column is
  regenerated with `memo_writes=false` and audited.

**Rule for plan.md:** I4 must report KO_SENSITIVE-clear and KO_SENSITIVE-set
violation counts separately. The KO_SENSITIVE-clear count is the verdict; the
KO_SENSITIVE-set count is a measurement. The plan.md must decide how to handle
cycle boundaries where a KO_SENSITIVE-clear state has a KO_SENSITIVE-set child
— the child's stored value is used, and any divergence is reported but does not
fail the sprint.

---

## 3. Dependency edges as `needs` — not prose

Each edge from DIRECTION Amendment 2, stated as a task-level `needs` relation.
These mechanize as `managent set <task> needs=<id>`.

### Edge 1: C-A1/C-A2 closure checks ← kernel move generator

```
C-A1/C-A2 row needs kernel-movegen-row
```

The kernel move generator is the critical path. Without it, C-A1/C-A2 closure
checks cannot be run. The move generator must be extracted from the solver
(`src/exp6_solve.zig`) into the Phase 2 kernel (`src/rules.zig`), headed by a
prose spec sentence and claim ID, with TDD per §6.

### Edge 2: kernel move generator extraction ← defect-reproducing invariant

```
kernel-movegen-row needs movegen-invariant-row
```

The extraction is licensed only by an invariant that seeds a known-incorrect
mutant in the move relation and kills it. This is the T265 test pattern
applied to the move generator: write a differential test that compares the
kernel's move generator against the solver's, seed a known-incorrect mutant
(e.g. allow suicide, allow ko recapture), and verify the invariant catches it.
An invariant that passes without exercising the moved code is a tautology, not
a prerequisite (`differential.zig:269-272` precedent; GRAND-AUDIT §1a).

The T267 key-agreement invariant machinery (`differential.zig`) is the
preferred vehicle — it already compares solver vs kernel and has the
regression-guard pattern. The plan.md decides whether to reuse it or write a
move-generator-specific invariant.

### Edge 3: I11 move-set consistency ← SMD1 + battery R8 move generator

```
I11-row needs SMD1-row
I11-row needs battery-movegen-row (R8)
```

The solver-side move-set dump utility (SMD1) is specified in pass0 design §4.6
and does not exist. Without it, I11 can only compare the battery against itself
— vacuously true. SMD1 must dump the solver's legal-move set in a format the
battery can read; the format is a plan.md decision.

### Edge 4: I4 Bellman residual ← battery R8 move generator

```
I4-row (4×4) needs battery-movegen-row (R8)
```

I4 at 4×4 needs the battery's independent Φ, which needs the battery's move
generator. I4 already runs at smaller gobans with a trivial (exhaustive) move
generator; the 4×4-scale implementation is the new work.

### Edge 5: promotion past CLAIMED ← covering mutants killed

```
G3b-discharge-row needs M1-invert, M2-invert, M3-invert, M4-invert, M8-invert, M9-invert, M10-invert
```

The seven T291 known-unkilled mutants are the promotion currency. No claim in
§1.1 passes CLAIMED until its covering mutants are dead. This is the
mutation-adequacy criterion from Amendment 2. A mutant that stays unkilled is a
finding; a killed mutant is a gate passed.

### 3.1 Serialization — file ownership, not phase order

Per Amendment 2, **phase number is not a dependency.** Concurrency across
phases is permitted. The real serializer is file ownership via managent sets:

| file | owner | holds |
|---|---|---|
| `src/rules.zig` (kernel move generator) | kernel-movegen-row | set=g3b-movegen |
| `src/differential.zig` (invariant) | movegen-invariant-row | set=g3b-movegen |
| `src/vb_movegen.zig` or equivalent (battery R8 move generator) | battery-movegen-row | set=g3b-battery |
| `src/vb_closure.zig` or equivalent (C-A1/C-A2) | closure-row | set=g3b-battery |
| `tools/smd1.zig` or equivalent (SMD1) | SMD1-row | set=g3b-tools |
| `build.zig` (wiring) | **single writer — serializes through Orchestrator** | — |

Rows in different sets may run concurrently; rows in the same set serialize.
`build.zig` is the single-writer choke point: every row that adds a build step
must declare it in plan.md and the Orchestrator serializes those touches.

---

## 4. R8 independence — I11 gets a null control and a seeded-defect control

`pass1/spec.md` §5 marks I11 as "runnable after Phase 2" — it needs the kernel
move generator AND SMD1. But the battery's independent move generator (R8) is
**itself a sprint deliverable**, not a pre-existing module. `sprint.md:100`
calls independent re-implementation the only gate that finds real defects and
notes it is **untested in this project**. I11 compares the battery's move
generator against the solver's; if both are wrong in the same way, I11 passes
vacuously.

### 4.1 Null control — I11 must fail when the comparison is against itself

Before I11's first reading counts, run I11 with the battery's move generator
replaced by an alias of the solver's. The null control **must** report 0
mismatches (vacuously) — confirming that without independence, I11 sees nothing.
If it reports mismatches, the comparison machinery itself is broken.

Then run I11 with the battery's real independent implementation against the
solver's. The real reading is the one where the two implementations differ in
authorship and model. The null control is recorded as a calibration artifact,
not a pass — it proves the harness is sensitive to independence.

### 4.2 Seeded-defect control — I11 must catch a known-incorrect move generator

Construct a synthetic defective move generator: one that, at a single known
state, reports a legal move that the solver does not (e.g. allows a ko
recapture, allows suicide, or omits a pass). Feed it through I11. The control
**must** report `mismatches > 0`. If it reports 0, I11 is blind and its real
reading is meaningless.

Both controls run at 2×2 first (ladder discipline, §6); the 4×4 reading is
taken only after the controls pass at 2×2.

### 4.3 What R8 independence means concretely

- **Different author.** The battery's move generator is written by a different
  agent/model than the kernel's. The plan.md assigns this explicitly.
- **Blind to the kernel implementation.** The battery's author sees the prose
  spec sentence and claim ID for the move rules (A1–A6, B1–B3 from AXIOMS.md
  §2), not the kernel's source code.
- **Different internal representation is allowed, same output is required.** The
  battery may choose any representation, but `legalMoves(state)` must return
  the identical set as the kernel at every state.

---

## 5. The two known defects in the path

### 5.1 `CODE.ACCEPT-KOKEY` — fourth ko copy in the acceptance harness

**Claim ID:** `CODE.ACCEPT-KOKEY` (PROVEN, T266/T277/T279).
**Location:** `src/oracle_v2_accept.zig:150-165` — carries a second, unfixed copy
of the pre-T265 ko rule. Sets a ko point on any single-stone capture without the
`liberties==1 && friendly==0` check. The acceptance harness (A1/A2/A8) therefore
builds keys the artifact was never built with, walks off-manifold, and reports
refusals while reporting passes.

**Status in this sprint:** T273 already fixed this by wiring `oracle_v2_accept.zig`
to the kernel's `rules.koAfterCapture`. The fix exists at HEAD; the defect is
documented. The sprint must **verify** that A1/A2/A8 now use the kernel ko rule
and that the acceptance battery's readings are on-manifold. The M4 mutant (same
defect, two divergent ko rules in one consumer) must invert to KILLED when
key-agreement runs.

### 5.2 `CODE.GTP-LHSIDE` — wrong-side bracket display (T283)

**Claim ID:** `CODE.GTP-LHSIDE` (PROVEN, T266/T277/T279; registered as RETIRED).
**Location:** `src/gtp.zig:1222-1225` — displays the bracket for the wrong side
to move on every genmove. Queries `bounds2` with `side` still set to the mover
after `applyMove`. Display/telemetry only — move choice is unaffected.

**Status in this sprint:** T283 is registered to fix this but may or may not be
done before this sprint runs. The defect is display-path only and does not
affect value-correctness checks. It is listed here for completeness, as the
commissioning draft names it. The M5 mutant (wrong-side query → I2 catches it
via colour-inversion break) is already KILLED by the existing battery (I2), so
this defect does not block G3b.

---

## 6. Feasibility questions flagged for plan.md — not answered here

These are open questions the plan.md must resolve. Listing them here makes the
spec honest about what it does not know.

### 6.1 Memory plan for closure over 24.3M groups

C-A1/C-A2 closure checks require computing the forward/backward closure of the
reachable state graph at 4×4. The state space is ~24.3M groups × up to 3 pass
states × 2 sides ≈ ~146M states. A naive bitmap of visited states needs ~18 MB;
the move graph (edges) needs more. Precedent: `i5-feasibility.md` (placeholder
at T293; prior analysis at `archive/i5-feasibility.md`, T134).

**Plan.md decision:** memory budget, data structure (bitmap vs sparse set vs
BFS queue), whether closure runs in-core or streams from disk, and whether the
precedent's numbers scale to 4×4. A memory-plan defect (OOM during closure) is
a `battery-bad` exit (code 2), not an artifact-bad finding.

### 6.2 C-A2: re-run reachability or certify T266's instrument?

T266 computed the reachable set from the root and reported the census. C-A2
(backward closure) asserts the same property: every root-reachable state is in
the table. The question: does C-A2 **re-run** reachability from scratch (with
the kernel move generator), or does it **certify** T266's instrument by
comparing its output?

**Criterion from the commissioning draft:** independence from the builder under
test. T266's reachability computation used the solver's move generator — the
same code that built the artifact. Re-running with the **kernel** move generator
is the independent path; certifying T266's output by replaying the same
computation is the QA-023 pattern (five audit links, four passed the artefact
through). **Recommendation for plan.md: re-run from scratch with the kernel
move generator.** The reachable set is recomputed independently; T266's census
is the expected value, not the input.

### 6.3 Parallel fixpoint — explicitly OUT OF SCOPE

T312/T314 measured parallel fixpoint performance. The commissioning draft
explicitly rules: do not couple value verification to a performance change.
Verify the artifact that exists, with the serial Bellman operator. If a
parallel fixpoint arrives later, it is a separate sprint with its own
value-correctness pass.

### 6.4 Whether the kernel move-generator extraction reuses T267's differential.zig pattern

T273's kernel extraction (`koAfterCapture`, `stateKey`) used `differential.zig`
for the key-agreement invariant and the regression guard. The move-generator
extraction can reuse the same machinery (compare kernel vs solver, seed a
defect, confirm the invariant catches it). The plan.md decides: reuse
`differential.zig` or write a move-generator-specific invariant in a new file.

### 6.5 SMD1 format and scope

The solver-side move-set dump (SMD1) is specified in pass0 design §4.6 and does
not exist. The plan.md must specify: output format (binary or text), which
states to dump (exhaustive at 2×2–3×3, sampled at 4×4 — the sampling strategy
is a plan.md decision), and how the battery reads it for I11 comparison.

### 6.6 Whether G1/G3 key-agreement runs at 4×4 scale or only on the sampled space

T267's key-agreement invariant runs exhaustively at 2×2, 3×2, 3×3
(`differential.zig` tests). At 4×4, exhaustive key agreement over ~146M states
is feasible (state-key computation is cheap compared to move generation), but
the plan.md must decide the scope and budget.

---

## 7. Ladder discipline

Every check runs and fails a seeded-defective small case before its 4×4 reading
counts.

### 7.1 Ladder rungs

| rung | goban | states (approx.) | what runs |
|---|---|---|---|
| **Rung 1** | 2×2 | 1,620 non-terminals (reachable) | All checks exhaustive. I4, C-A1, C-A2, I11, I5, key-agreement. Null controls and seeded-defect controls for I11. |
| **Rung 2** | 3×2 | ~17K reachable | All checks exhaustive. Same battery. |
| **Rung 3** | 3×3 | ~600K reachable | All checks exhaustive where feasible; I11 sampled if SMD1 exhaustive is too large. |
| **Rung 4** | **4×3** | ~5M reachable | **All checks, against the committed golden oracle `artifacts/oracle-4x3.wzo` (3.19 MB, SHA in `artifacts/SHA256SUMS`).** Exhaustive where it fits; sampled with a stated denominator where it does not. |
| **Rung 5** | 4×4 | ~146M reachable | I4, C-A1, C-A2, I11 on sampled space (sample strategy: plan.md). I5 (SCC containment) on the full graph. Key-agreement on the sampled space. |

**Why a second rectangle (Rev 5, operator ruling 2026-08-04).** Squares hide a defect class
that rectangles catch: **on a square board width and height are interchangeable**, so any
implementation that transposes `w` and `h` passes every square test. This codebase is exposed
to exactly that — the artifact header carries `w` and `h` separately and colex indexing depends
on their order. 3×2 was in the ladder for a narrower reason (it is the smallest board where the
I5 cycle-containment control is not vacuous; see §7.2), and it is small enough that a
transposition bug may not surface. 4×3 is the better structural rung: larger, asymmetric, and a
**golden oracle for it is already committed**, so the cost is running checks rather than
building an artifact.

**4×3 is also the 5×4 dress rehearsal.** 5×4 is the next resource-realistic rung — not because
it is realistic Go, but because it is where CPU, RAM and disk stop being free and the 4×4
brute-force approach must either scale or be replaced. Whatever 4×3 teaches about memory,
sweep counts and runtime transfers to that decision. **Every 4×4 reading is taken only after
its check has passed at 4×3.**

### 7.2 Calibration rule

At each rung, **before** taking the reading, seed a synthetic defect and confirm
the check catches it. The synthetic defect is:
- I4: corrupt one slot's L or H value → Bellman violation > 0
- C-A1: delete one entry → children-not-in-table > 0
- C-A2: delete one entry → reachable-not-in-table > 0
- I11: allow suicide → mismatches > 0. (The ko-recapture mutant cannot
  manifest through I11: SMD1's slice is `ko=NONE`, where every recapture is
  legal, so that seeded control would be blind by construction. Ko-dimension
  coverage of the move relation lives in the kernel-vs-R8 differential, which
  must compare at ko≠NONE states — amendment 2026-08-04.)
- Key-agreement: flip one bit in the key → mismatches > 0
- I5: set KO_SENSITIVE on one non-cycle-reachable slot → ko_not_cr > 0 (first
  seeded-defect control at 3×2; 2×2 measurement-only because all states are
  cycle-reachable)

A check that passes the clean artifact and fails the synthetic mutant is
**calibrated**. A check that passes both is **blind** — its reading is
meaningless and must not be reported as a pass.

### 7.3 Failure at a rung

If a check fails at rung 1, 2 or 3 (where the artifact is well-characterised and
the ladder sizes are exhaustive), the G3b sprint halts for adjudication. A
failure at 4×4 that passes at all smaller rungs is a finding about the 4×4
artifact, not the check.

---

## 8. Scope boundaries

### In scope

- The six checks listed in §2.1 (C-A1, C-A2, I4, I11, I5, G1/G3 key-agreement).
- The battery's independent move generator (R8).
- SMD1 (solver-side move-set dump utility).
- Kernel move generator extraction (one function in `rules.zig`, TDD, with
  defect-reproducing invariant).
- The nine carry-forward checks from the battery (§2.2) run as input readings,
  not as sprint deliverables — they already exist.
- Mutation adequacy: the seven T291 known-unkilled mutants invert to KILLED
  (M1, M2, M3, M4, M8, M9, M10).
- Null control and seeded-defect control for I11 (§4).

### Out of scope

- Parallel fixpoint (T312/T314) — verify the artifact that exists.
- Repairing the KO_SENSITIVE column — regenerate with `memo_writes=false` in a
  later sprint (Track A).
- The #2 self-consistency auditor — separate gate (`AGENTS.md`).
- PSK or k≥2 representations — epic-02 work.
- Real-game PSK values — not claimed.
- Repairing `CODE.GTP-LHSIDE` — T283 is a separate row; it does not block G3b.
- The v1 artifact's DTT column — known defect, baseline documented in
  `pass1/spec.md` §7.
- Cross-size inheritance — none claimed.
- Dihedral symmetry checks beyond I2 (colour inversion).

### Not yet decided — plan.md decisions

- Memory plan for 4×4 closure (§6.1).
- C-A2: re-run reachability vs certify T266 (§6.2).
- SMD1 format and sampling strategy (§6.5).
- G1/G3 key-agreement scope at 4×4 (§6.6).
- Whether `differential.zig` is reused for the move-generator invariant (§6.4).
- Phase ordering and parallelism (plan.md sections).
- Sample size for I4, I11, C-A1/C-A2 at 4×4.

---

## 9. Standing rules

- **Builds go through `tools/runner`.** Every `zig build` / `zig build-exe` /
  `zig test` invocation runs under `tools/runner -- <command>`.
- **stdout = data, stderr = diagnostics.** `util.out(...)` for parseable output,
  `util.note(...)` / `util.warn(...)` for diagnostics.
- **Findings propose claims at CLAIMED.** Nobody edits `CLAIMS.md` directly.
- **Evidence under `docs/evidence/<claim-id>/`**, never `untracked/`.
- **Numbers cite their run and state their denominator.**
- **One writer per engine file** — `src/rules.zig`, `src/retro.zig`,
  `oracle.zig`, `solve.zig`. `build.zig` serializes through Orchestrator.
- **No silent writes to `data/` or `artifacts/`.**
- **Scores are ALWAYS Black-positive.** Side-to-move picks the array, never the
  sign.
- **Per-goban epistemic independence.** A result at one size is not evidence at
  another.
- **Commit via `tools/git-commit-mine <paths> -m <msg>`.**

---

## 10. Amendment log

| date | amendment | by |
|---|---|---|
| 2026-08-03 | Initial spec — T323 | unknown/T323 |
| 2026-08-03 | Rev 2 — spec audit T329 (PASS-WITH-EDITS), all ten findings dispositioned; nine fixed as proposed, F3 fixed with the I4 independence-shortcut parenthetical rejected. Ratified at `f0769ac` | claude-fable-5 (Orcha) |
| 2026-08-04 | Rev 3 — artifact identity corrected (T332 F1): the sprint artifact is the WZO2 oracle-v2 build, **not** `data/oracle-4x4.checkpoint.wzo` (WZO1, PSK-era, no ko/passes dimension). §7.2's ko-recapture seeded control was blind by construction on SMD1's `ko=NONE` slice and was replaced with a suicide mutant on the slice; the ko-dimension gap became gate-holder finding F6 on the plan. Ratified at `ead66d0` | claude-fable-5 (Orcha) |
| 2026-08-04 | Rev 4 — §2.3 artifact path repointed from the sprint build path to the deployed `data/oracle-4x4-v2.wzo2` (human ruling: a ratified spec must not make `untracked/` load-bearing; oracle-v2 spec §4 F9 had already ratified the deployed path). Copy hash-verified against the recorded build and engine-loaded before the repoint; the `untracked/` build stays as the hash of record. No check, number, edge or decision changed. Amendment rows for Rev 2 and Rev 3 added retroactively — they were recorded only in the header line | claude-opus-5 (Orcha) |
| 2026-08-04 | Rev 5 — **4×3 inserted as ladder rung 4**, 4×4 becomes rung 5, on operator ruling. Two reasons, neither of them Go realism: squares cannot catch width/height transposition because `w` and `h` are interchangeable on them, and this format carries `w`/`h` separately with colex order depending on both; and 4×3 is the resource rehearsal for 5×4, the next rung where CPU/RAM/disk stop being free. A golden 4×3 oracle is already committed (`artifacts/oracle-4x3.wzo`), so the cost is running checks, not building an artifact. **No 4×4 reading is taken until that check has passed at 4×3.** §7.3's halt condition extended to rung 3. | claude-opus-5 (Orcha) |
