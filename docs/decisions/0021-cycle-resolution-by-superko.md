# ADR-0021 — Resolving the bracketed region under positional superko: the layered re-convergence (evaluation of the operator's proposal)

**Status:** PROPOSED (evaluation; recommendation for the Orchestrator to rule on)
**Date:** 2026-08-06 · **By:** flash/T386
**Relates to:** ADR-0009 (fixpoint + certification), ADR-0010 (bracket-guided finisher),
ADR-0013 (Track A/B, `ko_ref ≥ d` bug), ADR-0020 (loopy-game fixpoint semantics),
`GLOBAL.R1` (PSK exact-solve intractability), `GLOBAL.F1` (writes-ON finisher
unsoundness), T380 (ko audit; F-5/F-6), scaling-census (Track A/B cost wall)
**Evidence:** `findings/T386-cycle-resolution.json`, `findings/T386-context.json`,
instruments `src/t386_engine.zig`, `src/t386_coherence.zig`, `src/t386_shrink.zig`,
`src/t386_layers.zig` (hashes in the findings context)

## The proposal, as stated (2026-08-06)

> Pass 1: enumerate positions, legality, link successors. Pass 2: retrograde from terminal.
> **Pass 3: retrograde-BFS until a depth with brackets; resolve those to terminal under
> positional superko (PSK); then repeat Pass 2 for the next layer.** Expect fewer instances
> each round.

**First, the honest answer to the operator's own question: yes, this is close to what the
finisher already is.** `retro.zig` describes it as *"a forward fresh-start solve (oracle.zig:
full history + `ko_ref` rule + eye-prune) whose memo is pre-seeded with every certified
value, so it terminates the moment it leaves the ko-tangled region."* Same shape — bracketed
region only, history-aware, seeded by certified values, terminating early. Two differences
worth the row: the finisher uses the `ko_ref` rule rather than full PSK, and it is not
organised as layered re-convergence. **The second difference is real and is measured below:
it changes the economics of the bracket region substantially (F-4).** The first difference
is what this ADR evaluates.

This ADR's measurements are all at the fresh-start key (position, side, ko = none, passes = 0)
— the slice the proposal's "positions" and the table's oracle value both refer to. Every
number carries its denominator. All "pins" in the experiments are idealized forward PSK
solves (values taken from the validated PSK oracles `artifacts/oracle-3x3.wzo`,
`artifacts/oracle-4x3.wzo`); the experiments measure solve-**count** economics, not
solve-**cost**. Per-solve cost at 4×4 is the subject of §4, where the measured wall lives.

## 1. It defines a new ruleset — and that ruleset is declared here

**Name: the PSK-grafted fresh-start construction.** Not a playable ruleset — a
table-construction rule. The table it produces assigns every reachable legal (position,
side) a fresh-start value by:

1. the k=1 (basic-ko legality, TIE=0 cycles) retrograde fixpoint of ADR-0020, wherever it is
   single-valued (L == H); and
2. the positional-superko fresh-start value wherever the fixpoint is bracketed (L < H),
   re-propagated through the k=1 Bellman operator with the resolved keys held fixed.

This is **neither basic-ko Go nor PSK Go**: basic-ko Go has no PSK resolution, PSK Go has
no k=1 regions, and — the point the MIGOS `+2` epitaph teaches — a table's values are only
comparable to the ruleset they were generated under. **The graft's values are not
comparable to either parent's real-game scores, and nothing here restores C2 or C3**
(history-independence and real-game bracket bounds remain falsified at 3×2 and 3×3
respectively). It is a fresh-start table like the current deliverable, with a different
answer inside the bracket region.

**The coherence argument, made explicitly.** The graft is *value-coherent* in the only
sense that matters — it changes nothing the fixpoint already determined, and contradicts no
bound the fixpoint makes:

- **(a) Where L == H, the PSK fresh-start value is the same value.** Measured exhaustively:
  3×3, 0 divergent at L == H of 24,330 checked (680 divergent total, all at L < H);
  4×3, **0 divergent at L == H of 635,190 checked** (2,792 divergent total, all at L < H).
  The fact survives the projection check the brief asked for. So grafting PSK resolution
  onto the undetermined region changes nothing that was determined.
- **(b) Where L < H, the PSK fresh-start value lies inside [L, H].** Measured: 0 values
  outside the bracket at both 3×3 (24,330 checked) and 4×3 (635,190 checked). The graft
  never contradicts a bound the table already makes.

This is the strongest measured statement of coherence available, at two goban sizes. What
it is **not** is a proof: the L == H ⇒ cycle-rule-independence step remains the ADR-0009
honesty clause (strong structural evidence, not a theorem — `GLOBAL.FP2`), and the
per-goban independence rule forbids inheriting either measurement across sizes. The
coherence of the graft stands on these two runs; it must be re-measured at any new size.

**One further honesty clause, earned by the measurements:** the graft is value-coherent
but **not PSK-exact without verification**. The re-propagation step certifies most of the
bracket region "for free" (see §3), and 2.9% (3×3: 80 of 2,748) / 0.97% (4×3: 496 of
51,318) of those free certifications carry the wrong value — a value inside [L, H] but not
the PSK fresh-start value, at positions that were bracketed at round 0 (all of them
divergent at 3×3; 456 of 496 divergent at 4×3), error direction symmetric (40/40 up/down
at 3×3, 248/248 at 4×3). Pinning the drifters makes the final table **exactly** the PSK
oracle in one further round with no cascade (0 mismatches at all 24,330 / 635,190 checked
slots). Two consequences: (i) the proposal's "repeat Pass 2" output must not be shipped as
"the PSK table" without a verification pass, and (ii) the verification requires the PSK
value — which is the forward solve. **The propagation savings are real for the count of
solves (§3); they are not a licence to skip the solves for exactness.**

## 2. The relationship to the existing finisher (ADR-0010)

The finisher solves every bracket-valued root **independently** against a certified-only
baseline (per-root journal-reverted memo; `Finding 2` discipline — a finished ko-sensitive
fresh-start value is history-sensitive and must not seed another root's search). The
proposal's re-convergence is different in exactly this respect: a resolved position's value
is held as a **fixpoint constant** and re-propagated by Pass 2, so resolved values DO flow
into other positions' computation. That is not the Finding-2 hazard (no cross-arrival memo
reuse; the fixpoint treats pins as data, and the graft's definition is precisely that the
pinned position has that value). It is a genuinely new mechanism with its own failure mode
(the drifters of §1).

**The one thing the proposal shares with the finisher is the per-root PSK solve**, and
that is where the cost wall lives (§4). The layered re-convergence reduces the *number* of
such solves (F-4/F-5: 16.7% of brackets at 3×3, 6.0% at 4×3, including the verification
drifters); it does not reduce the *cost* of any one of them, and the deepest-first order
it inherits from the retrograde meets the measured-worst roots first at 4×4 (F-6).

## 3. Cost, measured (3×3, 4×3) and projected (4×4)

### The bracket region itself (measured)

| goban | fresh-start bracket entries | denominator (slots with fresh-start value) | fraction |
|---|---|---|---|
| 3×3 | 3,204 | 24,330 | 13.17% |
| 4×3 | 54,074 | 635,190 | 8.51% |
| 4×4 | 1,962,142 (1,913,925 positions) | 48,505,262 entries (24,318,165 positions) | 4.05% of entries; 7.87% of positions |

(4×4 numbers reproduce T380 F-5 exactly; 4×3 is the engine's fresh construction, gated at
3×3. Layer distribution, per stone-count layer — the retrograde's "depth":

| layer | 3×3 | 4×3 | 4×4 |
|---|---|---|---|
| 0 (empty) | 0 (certified) | 2 (of 2 — bracketed) | 2 (B [1,16], W [−16,−1]) |
| 1 | 8 | 16 | 8 |
| 2 | 84 | 128 | 168 |
| 3 | 320 | 624 | 976 |
| 4 | 688 | 2,246 | 6,182 |
| 5 | 856 | 6,196 | 24,344 |
| 6 | 688 | 10,600 | 72,520 |
| 7 | 360 | 13,848 | 167,920 |
| 8 | 200 | 11,116 | 304,472 |
| 9 | — | 6,076 | 420,368 |
| 10 | — | 2,274 | 434,904 |
| 11 | — | 948 | 321,312 |
| 12 | — | — | 153,030 |
| 13 | — | — | 45,656 |
| 14 | — | — | 8,424 |
| 15 | — | — | 1,856 |

The 4×4 bracket region is **bell-shaped, mid-game-heavy** (peak L10: 434,904 entries;
width mean 13.28, deep-tangle width ≥ 24 concentrated at L6–L12). The opening layers are
thin (L0–L3 total: 1,154 entries) and the near-terminal layers are moderate (L13–L15
total: 55,936). The empty 4×4 goban is bracketed at [1,16] (Black) — inside which the
published anchors lie.)

### Does resolving a layer shrink the next? (measured at 3×3 and 4×3)

**Yes — the operator's optimism is confirmed, dramatically, at both sizes.** The layered
loop (pin the deepest bracket layer's fresh-start keys to their PSK values, re-converge,
repeat) collapses the bracket region in **3 rounds** at each size:

| goban | round 1 | round 2 | round 3 | direct pins | propagated (never solved) |
|---|---|---|---|---|---|
| 3×3 | pin L8 (200) → 448 cert. | pin L7 (168) → 1,624 cert. | pin L6 (88) → 676 cert. | 456 | 2,748 (85.8%) |
| 4×3 | pin L11 (948) → 6,932 cert. | pin L10 (864) → 25,864 cert. | pin L9 (944) → 18,522 cert. | 2,756 | 51,318 (94.9%) |

The shrink is structurally non-increasing (pins lie inside [L, H], so L only rises, H only
falls, and a certified key stays certified); the *measured* content is the rate, and the
rate **improves with goban size** (85.8% → 94.9% propagated). Exactness (verify-then-pin,
§1) adds one round and 80 pins at 3×3 / 496 at 4×3, with no cascade:

| goban | total solves for the exact PSK table | as % of brackets |
|---|---|---|
| 3×3 | 536 | 16.7% |
| 4×3 | 3,252 | 6.0% |

### Projection to 4×4 — **PROJECTION, NOT MEASURED**

If the count economics transfer (they do not transfer by right — per-goban independence;
the measured trend improves, which is the only warrant), the 1,962,142-entry 4×4 bracket
region would need of order **1.2×10⁵–3.3×10⁵ forward PSK solves** (6–17% of brackets),
each one an idealized pin. **Every other term at 4×4 is dominated by the per-solve cost,
which the layering does not reduce** — see §4. The layer census bounds the shape of the
work: the deepest-first order resolves L13–L15 (55,936 entries) in its first three rounds,
and that is the band where the sound forward search is measured to blow up.

## 4. GLOBAL.R1, scoped honestly

`GLOBAL.R1` — 118,475,182 ban-set states on the **empty 2×2**, budget-exceeded — measures
**whole-game PSK exact-solving from the root with full history**. **The proposal is not
that.** It resolves isolated bracketed roots whose forward searches are bounded by bracket
cuts and certified/pinned seeds, and the measured experiments at 3×3 and 4×3 show the
count side collapses in 3 rounds. R1's specific number does not transfer.

**But the underlying phenomenon does.** The per-root forward PSK solve at 4×4 is the
project's measured wall, and the proposal must cross it per-root:

- the **sound** path (no unsafe cross-arrival reuse — Track A, and the only path a
  PSK-resolution search can take, since ban-set memo keys are 5.4 MB at 4×4) was measured
  to blow up on **capture-reopening roots** at near-terminal layer 15: a few roots exceed a
  500M-node budget, 3–6 minutes each (scaling-census); the 4×4 writes-off regen is
  **untested** (D3, the single gate on Track A);
- T380 F-6's 4×4 PSK sample: **782 of 1,591 roots budget-excluded** (49.1%) at a 200K-node
  budget, with the divergent class concentrated in the excluded half;
- the Exact ban-set solver is unusable at 4×4 (5.4 MB per memo key);
- the writes-ON finisher that *did* complete 4×4 (1.08×10⁹ nodes, 367 s, zero skips) is
  precisely the unsound path F1 convicted.

At 4×4 the deepest bracketed layers (L13–L15, 55,936 entries) are the capture-reopening
band — the deepest-first order the retrograde suggests resolves **those first**. An
alternative shallowest-first order (opening band first: L0–L3 total 1,154 entries) would
make the deep-layer searches cheaper by pinning their capture-children, but then the empty
goban — the width-15 R1-class root — is resolved first. **Either order, the per-root PSK
solve at 4×4 is the wall; the layering reduces the count of solves, not their difficulty.**

## 5. GLOBAL.F1: does full PSK dissolve the unsoundness or relocate it?

F1 is a **memo-reuse discipline** bug: the writes-ON finisher stores a score computed under
one history and reuses it at an arrival where the history (and hence the legal
continuations) differs; the `ko_ref ≥ d` guard was the insufficient attempt to certify
subtree self-containment. Adopting full PSK does not repair the guard — under PSK the
history that matters is the whole ban set, so the guard's job is strictly harder. What
happens instead:

- **the unsafe reuse class becomes unreachable**: a PSK search's memo would need ban-set
  keys (5.4 MB each at 4×4), so the forward search is writes-off by necessity — the F1 bug
  evaporates because the memo it lived in cannot exist;
- **the cost relocates to the sound path**: writes-off is exactly the path measured to
  explode on capture-reopening roots (§4) and whose 4×4 regen is untested;
- **the layered construction's pinning is a different mechanism entirely** — pins are
  fixpoint constants, not search-memo cutoffs — so it carries no F1-class hazard; its
  failure mode is the value-infidelity of propagation (§1), detectable only by comparing
  against the PSK value, which requires the solve.

Net: full PSK **dissolves F1 by making unsafe reuse impossible and relocates the problem
to the sound-search cost wall**, and adds the drift-detection requirement. No free lunch.

## 6. Recommendation (for the Orchestrator to rule on; not decided, not implemented)

1. **The layered re-convergence is a genuine, measured improvement over the per-root
   finisher for the COUNT of forward solves** — 85.8% / 94.9% of the bracket region
   certifies without a solve at 3×3 / 4×3, in 3 rounds. If the finisher is ever rebuilt
   (e.g., Track A regeneration of the committed ko-sensitive values under a tractable
   rule), **the layered driver should be the design**, with the verify-then-pin pass made
   mandatory (the drifters are 0.33% / 0.078% of slots but undetectable without the solve).
2. **As a route to "exact 4×4 PSK fresh-start scores", the proposal is blocked by the
   measured per-solve wall, not by its structure.** The count side is favourable and
   improving; the per-solve side at 4×4 (capture-reopening roots, sound path, budget
   exclusions) is the same wall Track A/Track B have been on since ADR-0013, and the
   layered order meets the worst band first. The proposal should be **accepted as a
   driver, not as a solver**: it does not make PSK resolution tractable at 4×4.
3. **Before any PSK-graft build at 4×4, the per-root cost model must be measured** — the
   single cheapest gate is the outstanding D3 (4×4 writes-off regen): without a sound
   per-root cost at 4×4, the projection's 10⁵–10⁶ solves is an unbounded cost, not a
   number.
4. **If the operator wants the single-score table now, the tractable deliverable is
   unchanged**: the loopy-fixpoint fresh-start table (current WZO2) with the honest
   [L, H] bracket, exactly as ADR-0020 and the foreclosures state. The PSK-graft is a
   declared-ruleset option whose values are not comparable to either parent — worth
   keeping on the shelf, not on the critical path.
5. **Do not call the grafted table "the PSK value of the goban"** — it is a fresh-start
   construction; C2/C3 stand falsified; the MIGOS-epitaph rule applies.

**Landmark:** advances `L2 (proven 4×4 values)` — the operator's proposed route is now
measured, not hoped: the layered re-convergence provably collapses the bracket region's
*solve count* (3 rounds, 85–95% propagated, at 3×3 and 4×3), but it is not PSK-exact
without verification (80/2,748 and 496/51,318 drifters), does not reduce per-solve cost,
and at 4×4 meets the capture-reopening wall in its first rounds — so L2 remains blocked
by the same per-root cost wall as Track A/B, with the proposal's count economics as a
genuine improvement to bank for any future finisher rebuild.
