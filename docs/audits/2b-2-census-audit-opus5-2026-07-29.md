---
**Model of record:** Claude Opus 5 (1M context), acting as Auditor.
**Date:** 2026-07-29.
**Scope:** task 2B-2 — the 3×2 reachable-state census and cycle census
(`docs/evidence/QA-023/census-3x2-2026-07-29.md`, MiniMax-M3, commit `a8961f5`).
**Dispatch:** user-requested, out of band. A formal brief exists at
`docs/infra/dispatch/2B-2-AUDIT.md` (addressed to Kimi-k2.7); this audit
answers its four questions but is filed under a distinct name so it does not
collide with, or pre-empt, that deliverable. Two independent audits of the same
artefact is the desired state, not a duplication.
**Method:** independent re-implementation, not review-by-reading. Verdicts below
rest on my own code reproducing (or failing to reproduce) each number.
---

# 2B-2-AUDIT (Opus 5) — the 3×2 cycle census

## Verdict summary

| # | Item | Verdict |
|---|---|---|
| 1 | The 1,696-vertex SCC / the `lowlink` caveat | **VERIFIED** — 1,696 is correct; the caveat's *narrative* is self-contradictory across artefacts |
| 2 | 143,760 simple directed cycles at cap 14 | **VERIFIED as a number; the cap-artifact discussion is WRONG** (three false statements) |
| 3 | 1,724 cycle-reachable vertices | **PARTIAL** — reproduced exactly, but 24 of the 28-vertex "tail" are artefacts of impossible seed states, and the deliverable's account of the residual 92 states is false |
| 4 | The no-escalate decision | **VERIFIED, and robust** — survives both defects found below |

**One-line answer to the brief's closing question.** 2B-4's falsification may
rest on the *vacuity verdict* — 3×2 genuinely hosts cycles, and that conclusion
survives every perturbation I tried. It may **not** rest on the census's
*quantities*: 1,696 / 1,724 / 143,760 are properties of a graph that over-bans
56 ko edges relative to the governing spec (`proof-v2` §1.1), and under the
spec's rule they are 1,676 / 1,704 / 216,176 instead. See F1 and F2.

## How this was verified

I did not audit by reading the report. I transcribed the *semantics* of
`apply_place` / `apply_pass` / `moves` / `seed_roots`
(`src/qa023_probe.zig:525-597`, `:2660-2671`) into an independent Python
implementation, rebuilt the reachability fixpoint, and wrote an independent
Tarjan SCC and an independent simple-cycle enumerator (C, for the cap sweep).
Nothing was shared with the Zig beyond the rules as documented.

Independent results on the graph **as implemented**:

| quantity | m3 | this audit | |
|---|---|---|---|
| reachable V | 2,682 | **2,682** | ✅ |
| directed E | 5,744 | **5,744** | ✅ |
| SCCs total / non-trivial / max | 987 / 1 / 1,696 | **987 / 1 / 1,696** | ✅ |
| cycle-involved | 1,696 | **1,696** | ✅ |
| cycle-reachable | 1,724 | **1,724** | ✅ |
| distinct legal boards | 489 | **489** (all 489 legal) | ✅ |
| ko=none / ko=cell | 2,562 / 120 | **2,562 / 120** | ✅ |
| side B / W, terminals | 1,341 / 1,341, 866 | **1,341 / 1,341, 866** | ✅ |
| cycles at cap 12 | 37,376 | **37,376** | ✅ |
| cycles at cap 14 | 143,760 | **143,760** | ✅ |
| histogram 6/8/10/12/14 | 16 / 1,296 / 11,004 / 25,060 / 106,384 | **identical** | ✅ |

The published *sample cycles* also match my enumerator vertex-for-vertex and
in traversal order (`census-3x2-2026-07-29.md:71-73`), which additionally
confirms the dense vertex numbering and adjacency ordering are identical.

I re-ran the documented command at `HEAD` and it reproduces the committed
stdout exactly. (`[runner]` reported 362 MB / 5.4 s against the deliverable's
45 MB / 0.6 s at `census-3x2-2026-07-29.md:140-141` — a cold vs. warm `zig`
compile cache, not a discrepancy in the result.)

**Semantic validation, which the deliverable did not do.** The deliverable
declines to decode its own samples ("These are NOT human-readable board
sequences", `:75`). I decoded all three back into move sequences and checked
every edge against the rules and that the cycle closes on the same
`(board, side, ko, passes)` tuple. All three are genuine legal Go cycles. The
length-6 one, in full:

```
.XO/X..  B plays a1              →  XXO/X..
XXO/X..  W plays b2, capturing 3 →  ..O/.O.
..O/.O.  B plays b1              →  .XO/.O.
.XO/.O.  W plays c2              →  .XO/.OO
.XO/.OO  B plays a2, capturing 3 →  .X./X..
.X./X..  W plays c1              →  .XO/X..   ← start
```

This is worth recording because it identifies *what makes 3×2 cyclic*:
**multi-stone capture and recapture**, which basic ko does not ban. That is
precisely the phenomenon QA-023 is about, so the test surface is not merely
non-empty, it is non-empty *for the right reason*. This is the strongest
positive result in the audit and it is stronger than what 2B-2 claimed.

---

## Item 1 — the SCC and the `lowlink` caveat: VERIFIED

The committed Tarjan implementation is correct. Both `lowlink` updates match
the textbook recursive reference:

- back-edge to a stack ancestor uses `index_arr[w]` — `src/qa023_probe.zig:2197`
- backtrack to the parent uses `lowlink[v]` — `src/qa023_probe.zig:2220`

My independent Tarjan returns 987 SCCs, one non-trivial, max size 1,696.
**The 1,696-vertex SCC stands.**

**F0 (documentation, material). The caveat's narrative contradicts itself
across artefacts, and the version in the handoff summary asserts the opposite
of the truth.** The deliverable says the buggy first attempt *over-split*
SCCs and produced a max size of 7 (`census-3x2-2026-07-29.md:108-110`,
consistent with `PROVENANCE-census-3x2-2026-07-29.md:32-33`). The task summary
circulated to the user says the bug *over-merged* SCCs "into a single
1,696-vertex chunk" — i.e. that the published headline was the buggy output.
Only the deliverable's version is mechanically coherent (substituting
`index_arr[v]` for `lowlink[v]` at the backtrack step suppresses deep
back-edge propagation and over-splits). My reproduction settles it: 1,696 is
the correct value, and the summary's account is wrong. A reader who saw only
the summary would reasonably distrust the headline. Repair belongs to whoever
owns the message, not to me.

## Item 2 — the cycle count: number VERIFIED, cap discussion WRONG

143,760 is exactly right *as the count of simple directed cycles of length
≤ 14*, and "distinct simple directed cycles" is a sound object for a claim of
the form "> 0" — it is cap-monotone, so any cap yielding a positive count
establishes the claim. Parity reasoning at `:63-67` is correct (each move
flips `side`, so a returning walk has even length), and lengths 2 and 4 are
genuinely zero.

**F2 (documentation, material). The cap-artifact discussion is not honest
about the caps, in three separate statements.** I ran the sweep to natural
completion at every cap the deliverable discusses; with a 10⁹ total cap none
of them is capped:

| cap | true total (this audit) | capped? |
|---|---|---|
| 12 | 37,376 | no |
| 14 | 143,760 | no |
| 16 | 511,840 | no |
| 18 | 3,288,800 | no |
| 20 | 16,192,056 | no |
| 22 | 70,772,876 | no |

Against that:

- `PROVENANCE-census-3x2-2026-07-29.md:60-63`: "the cap is not the natural
  completion at any length tested (16, 18, 20 all hit the cycle cap)" —
  **false for all three.**
- `census-3x2-2026-07-29.md:176-177`: "At cap 18 the count is 3,288,800 (cap
  hit)" — the number is exactly right, the "(cap hit)" label is **false**.
  A capped run cannot report the uncapped total.
- `census-3x2-2026-07-29.md:177-178`: "At cap 20 the count is ≥ 100 million
  (cycle cap hit)" — **false**; the true figure is 16,192,056, low by ~6×.
- `:179-182`: "Length 14 is the smallest cap at which the total cap is not
  hit … the true cycle count is at least 3.3M (cap 18, the smallest cap that
  still hits the total cap)" — the ≥3.3M bound is *true* but its stated
  justification is **false**, and the real bound is ≥ 70,772,876.

None of these auxiliary runs has committed stdout, so none is reproducible
from the evidence; I had to re-derive them to find they were wrong. The
deliverable's own conclusion — "The headline is robust to all these caps" —
is correct, which is why this is a documentation defect rather than a wrong
claim. But it sits under a heading reading **"Honest caveats"**, and three of
the four sentences under it are inaccurate.

**F3 (documentation, minor). The headline sentence is false as written.**
`:16-18` states flatly that "3×2 has 143,760 distinct simple directed cycles
in the reachable legal-move graph", with no cap qualifier in the sentence.
The cap appears only in the table (`:41-42`) and the caveats. The true count
exceeds 70 million. The direction of the error is conservative for
B-VACUITY, so the verdict is unaffected — but the sentence most likely to be
quoted downstream is the one that is wrong.

## Item 3 — the 1,724 cycle-reachable vertices: PARTIAL

Reproduced exactly. Two problems with it as the population 2B-4 samples from.

**F1 (implementation, material — inherited, not m3's). The seed set contains
36 states that cannot occur in any game, and "reachable" is therefore not
what the census counts.** `seed_roots` (`src/qa023_probe.zig:2660-2671`) and
the identical block in `run_census_3x2` (`:675-687`) seed the empty board
across 2 sides × 3 pass-counts × **all 7 ko values** = 42 states. Both call
this "the four roots" in comment and prose (`:2656-2659`, `:675-677`;
repeated at `census-3x2-2026-07-29.md:94-96`) — it is neither four nor
confined to coherent states. An empty board can never carry a ko point: a ko
point is set only by a capture, and a capture always leaves the capturing
stone on the board. 36 of the 42 seeds are unreachable positions.

Measured effect (my implementation, same rules, varying only the seeds):

| seeds | V | E | cycle-involved | cycle-reachable | cycles @14 |
|---|---|---|---|---|---|
| 42, as implemented | 2,682 | 5,744 | 1,696 | **1,724** | 143,760 |
| 6 coherent (ko=none) | 2,646 | 5,600 | 1,696 | 1,700 | 143,760 |
| 1 true game root | 2,643 | 5,586 | 1,696 | **1,698** | 143,760 |

So: **24 of the 28-vertex "tail" are phantoms.** The deliverable presents the
28 as the "drainage into the SCC" (`:183-185`) and offers the 1,724 to 2B-4
as its sampling target (`:159-161`); a sampler drawing from it will draw
states that no game can produce. The SCC, the cycle count and the histogram
are entirely unaffected — cycles cannot pass through a source — so B-VACUITY
does not depend on this. The reachable-state count 2,682, quoted throughout
EXP-2B and cross-checked against T13, is nonetheless not a count of reachable
states.

**F4 (documentation, minor). The account of the residual 92 states is
false.** `:162-164` describes "the 92 reachable states that are in
unreachable positions (posts, not in the 489 distinct legal boards)". The
number is right — 2,682 = 1,724 cycle-reachable + 866 terminals + 92 — but
the explanation is not. All 92 have legal boards drawn from the same 489; I
checked each. They are 12 near-full positions whose only move is a pass
(e.g. `.OO/OOO`, Black to move, ko=a1, out-degree 1) plus 80 `passes = 1`
states, all of which drain to a terminal without meeting a cycle. There is no
such thing here as a reachable state with an illegal board.

## Item 4 — the no-escalate decision: VERIFIED and robust

Cycles > 0, so 3×2 hosts a non-trivial QA-023 test and no escalation to 3×3 is
warranted on vacuity grounds. I stress-tested the verdict against every defect
above and one more (below); it survives all of them. The 1,696-vertex SCC is
reachable from the single true game root, so the claim does not depend on the
seeding convention at all.

---

## F5 — the defect that does threaten downstream work

**The ko-point rule as implemented deviates from the governing spec, and 56
reachable edges are banned that basic ko does not ban.**

`proof-v2` §1.1 (`docs/evidence/QA-023/proof-v2-2026-07-28.md:40-42,52-53`)
defines formalization (i) as a ko point "set only by a **single-stone ko
capture**". A single-stone ko capture requires two things: exactly one stone
captured, *and* the capturing stone being a lone stone with exactly one
liberty — otherwise the opponent's recapture does not recreate the prior
position and there is nothing to ban.

`apply_place` (`src/qa023_probe.zig:540-549`) tests the first condition
(`opp_before - opp_after == 1`) and then counts the **empty neighbours of the
played cell**. It never checks that the played stone is a lone stone. When the
played stone joins a friendly chain, that count is not the chain's liberty
count and the guard is the wrong test.

Quantified over the reachable graph: 232 edges set a ko point; in 184 of them
the placed stone is not a lone stone. Restricting to cases where the ban
actually removes an otherwise-legal move:

- 128 — ban has no bite (the move at the ko cell is illegal anyway)
- 48 — ban has bite and textbook simple ko agrees
- **56 — ban has bite, and simple ko would not ban it**

Example: from `XXO/XX.` Black plays c2, capturing the lone White stone at c1.
The placed stone joins a five-stone chain whose sole liberty is c1. White's
reply at c1 captures all five and yields `..O/...`, which is not the prior
position — a legal snapback-style exchange, banned here.

Effect, computed rather than argued (independent harness, textbook condition
substituted, everything else held fixed):

| | as implemented | corrected simple ko |
|---|---|---|
| V (42 seeds) | 2,682 | 2,622 |
| E | 5,744 | 5,668 |
| ko=cell states | 120 | 60 |
| max SCC / cycle-involved | 1,696 | **1,676** |
| cycle-reachable | 1,724 | **1,704** |
| cycles at cap 14 | 143,760 | **216,176** |

**B-VACUITY is robust** — more cycles, not fewer, and the histogram stays
even-parity. But every quantity in the deliverable moves. This is not 2B-2's
defect: the brief instructed reuse of `run_census_3x2`
(`docs/infra/dispatch/2B-2.md:6`) and m3 correctly reused it unchanged. It is
a defect in the shared object that 2B-2 measured and that 2B-3 and 2B-4 build
on, and it needs an owner who is not the auditor. **Routing: this is a rules
question for whoever owns `proof-v2` §1.1 and the 2B-0 reference semantics,
and it should be resolved before 2B-4's falsification is promoted to CLAIMS —**
a QA-023 disagreement found on a graph with 56 spurious ko bans cannot be
distinguished, from the evidence as it stands, from an artefact of the wrong
rule.

## What a wrong answer would have scored

Per `AUDITOR.md`: the deliverable's own validation is the five `zig test`
cases plus the 489-board agreement with T13. I confirmed 5/5 pass
(`--test-filter "2x2 smoke" --test-filter "3x2"`, as the hazard note requires)
— and **none of the five touches the cycle census.** They cover rank/unrank
round-tripping, `area_score` on three boards, and the calibration gadget
(`src/qa023_probe.zig:1766-1822`). The 489-board check constrains only the
board enumeration, which is upstream of everything the census computes. A
census that returned the over-split max-SCC-of-7 from m3's own first attempt
would have scored 5/5 and matched T13 on 489 boards. The cycle census has
**no test that a wrong cycle census would fail**; its correctness rested
entirely on there being a second implementation, which until now there wasn't.

## Lesser findings (code, not claim-bearing)

- **`rank_in_scc` does not confine the DFS to its SCC.**
  `src/qa023_probe.zig:2280-2283` allocates it at size V and fills
  `0xFFFFFFFF` for every vertex outside the current SCC; the guard at `:2310`
  is `rank_in_scc[w] < rank_in_scc[start]`, which `0xFFFFFFFF` never
  satisfies. The DFS therefore walks out of the SCC. It cannot inflate the
  count — leaving an SCC is irreversible, so such a path can never close, and
  `cycle_involved_flag` is written only on closure (`:2320`) — so this is
  wasted work only, and my counts confirm the totals are unaffected. It is
  the likely reason the larger caps felt expensive enough to be reported as
  capped (F2): my confined enumerator reaches cap 20 in 21 s.
- **Histogram labels are wrong away from cap 14.** The bucket index is
  `@min(len - 2, 12)` (`:2318`), so index 12 aggregates *all* lengths ≥ 14
  regardless of cap; the struct comment at `:2051` says "length 2..12; index
  12 = length >= 12" (off by two) and the printed header at `:2449-2453`
  announces "index 13 = length >= 14" for an array with indices 0..12. At the
  cap actually used the printed numbers are right, so the committed stdout is
  correct; at any other cap the labels mislead.
- **`sample_cycles` is returned `undefined`** (`:2517`) beside a populated
  `sample_cycles_count` (`:2518`). No caller reads it today; it is a live
  trap for the next one. Sample capture is also hard-wired to lengths
  2/3/4/5/6/8/14 (`:2321-2337`, `:2474`), so a run at another cap silently
  publishes no samples.
- **The census fixpoint in `main` has no sweep bound.** `:2567` loops
  `while (new_marks > 0)` where `run_census_3x2` caps at `MAX_SWEEPS = 64`
  (`:699-700`). It terminates by monotonicity; it is the brief's "node budget
  that fails loudly" that is missing.

## Provenance and reproducibility

Both hashes in `PROVENANCE-census-3x2-2026-07-29.md:7-8` verify:
the committed stdout is `68b420cb…76df1` as stated, and
`efb86db8…b908e6` is `src/qa023_probe.zig` **as of `a8961f5`**, the census
commit. At `HEAD` the file hashes `91c3e21e…d716d5` — 2B-3/2B-4 have since
edited it — so the recorded hash no longer identifies anything a reader can
check out by path. I confirmed by diff that the later edits touch only
`ProbeParams` and `run_probe_3x2` (`:1234`–`:1738`) and leave the rules,
`run_census_3x2` and `run_cycle_census_3x2` untouched, and that the documented
command still reproduces the committed stdout exactly at `HEAD`. **Suggestion
for the PROVENANCE convention, not a defect in this one: pin the commit
alongside the file hash**, since a file hash in a living tree stops resolving
the moment the next task lands.

## Claim register

`3x2.QA023.B-VACUITY` does not exist in `docs/epistemic/CLAIMS.md`. That is
correct process — commit `e8d6d5e` states promotion waits on this audit plus
2B-5 and 2B-6 — but the deliverable's header reads **"Status: PROVEN"** and its
Contributes-to section says "`3x2.QA023.B-VACUITY` (this row, **PROVEN**)"
(`census-3x2-2026-07-29.md:6-9,207`), presuming a row that has not been
written. On the substance I concur that the underlying proposition is proven:
it is an exhaustive deterministic enumeration, independently reproduced here,
and robust to both formalizations.

## Unverified assertions left standing

I did not check these and they are not load-bearing for B-VACUITY; they should
not be quoted as audited:

- "T13 found 508 non-trivial PSK histories at 3×2" (`:197-198`).
- "the basic-ko state space is strictly larger than the PSK state space"
  (`:201-203`).
- The claimed `fixpoint-3x2` / `calibrate` / `smoke-2x2` cross-check outputs
  (`:130-133`) beyond the 5/5 test run, which I did reproduce.

## Correction to a cross-reference (F6, material to the framing)

`census-3x2-2026-07-29.md:194-196` states: "2×2: `2x2.T12` — 2×2 admits no
reachable non-root cycles … **Confirmed:** the 2×2 graph has 2430 states, zero
non-trivial SCCs (a separate `census-2x2` would show this)."

Three problems. The sentence says "Confirmed" while its own parenthesis
concedes the check was never run. 2,430 is the *raw* 2×2 state space
(3⁴ × 2 × 5 × 3), not a graph size — the reachable graph has 263 states from
the true root (290 under the 42-seed convention). And the substantive claim is
false: transposing this same basic-ko formalization to 2×2, my implementation
finds a **144-vertex non-trivial SCC**, and I extracted and decoded a concrete
legal 6-cycle:

```
O./..  B plays b1              →  OX/..
OX/..  W passes
OX/..  B plays a2, capturing 1 →  .X/X.
.X/X.  W passes
.X/X.  B plays b2              →  .X/XX
.X/XX  W plays a1, capturing 3 →  O./..   ← start
```

T12's actual scope is **PSK**, not basic ko:
`docs/epistemic/boards/2x2/EPISTEMIC.md:10-11` reads "No non-trivial PSK
histories exist on 2×2 (T12)" and "Cannot test — 2×2 has no reachable
non-root cycles" in a PSK column. Under positional superko the graph is
acyclic by construction, so T12 is true and trivial there and says nothing
about the basic-ko graph. The deliverable transported a PSK-scoped claim onto
the basic-ko graph and marked it confirmed.

This propagates into the deliverable's status header (`:6-9`), which invokes
"per-board epistemic independence" to explain why "the 2×2 `2x2.T12` no-cycle
falsification does not transfer". The real reason it does not transfer is the
**rule set**, not the board size — and, on my check, 2×2 basic ko has cycles
too, so there was never a tension for board-independence to resolve. This is
the definition-shift-between-documents residue `AUDITOR.md` asks for, and it
is the finding I would most want a second opinion on, since it rests on my
transposition of the rules to 2×2 rather than on any code in the repo (there
is no `census-2x2` mode). My 3×2 numbers agree with the probe's on every
figure, which is the reason to take the transposition seriously; it is still
my code, not the project's.

## Not done, by role

I wrote no repair. F1 (seed set), F5 (ko condition), F0/F2/F3/F4/F6
(documentation), and the lesser code findings are named to the line and left
for someone else, per `AUDITOR.md`. I edited nothing under `src/`, nothing in
`CLAIMS.md`, and no 2B-N deliverable. My verification scaffolding is
throwaway and was written outside the repo; if anyone wants a permanent
second implementation — and F5 plus "what a wrong answer would have scored"
argues someone should — that is a specification to be argued with and built
by another hand, not my code to install.
