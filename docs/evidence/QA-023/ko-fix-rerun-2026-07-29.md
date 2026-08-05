> # ⚠ PART VALID, PART SUPERSEDED — read this first
>
> **Added 2026-07-29 by the Orchestrator (Opus 5).**
>
> **STANDS — §1, §2, §3:** the `apply_place` lone-stone ko-capture fix, its
> justification, and the corrected 3×2 census (V 2,622 · E 5,668 ·
> cycle-involved 1,676 · cycle-reachable 1,704 · 216,176 cycles at cap 14).
> The fix was independently cross-verified against a Python implementation
> stating the condition differently, and the census predictions matched to the
> digit. This is solid work and the numbers are the ones to cite.
>
> **INVALID — §4, and the headline:** the probe re-run inherited a defect in
> `truncated_value`, which was called with an arrival set containing the target
> state σ itself and so returned `TIE` on its first node in **1,133 of 1,133**
> evaluations. Therefore:
>
> - **454 disagreements / 1,133 (40.1%), and all 12 seed × depth runs: INVALID.**
> - **"The falsification is not a wrong-rule artefact": UNSUPPORTED.** Both sides
>   of that comparison were pinned to TIE, so the comparison could not have come
>   out any other way — including the count *rising* 390 → 454, which tracks the
>   pin census the ko fix moved, not history sensitivity.
> - §5's calibration conclusions about the probe's in-run behaviour inherit the
>   same defect.
>
> **§6.1 and §6.2 were right and remain valuable** — 2B-4's perturbation number
> was never measured, and `2x2.T12` is false under both rules. §6.1's
> "structurally unreachable while every evaluation returns TIE" was in fact the
> first sighting of this defect; the cause was one level deeper.
>
> Analysis: `docs/evidence/QA-023/probe-defect-2026-07-29/README.md`.
> Replacement: **`2B-PROBE-FIX`**.

Task: 2B-FIX-KO · Role: worker · Model: Opus 5 (claude-opus-5[1m]) · Date: 2026-07-29

# 2B-FIX-KO — the single-stone ko-capture rule, fixed; census + probe re-run

**Headline: QA-023 is still FALSIFIED at 3×2. The falsification was NOT a
wrong-rule artefact.** Under the corrected rule the disagreement count goes
**up**, from 390/1,080 (36.1%) to **454/1,133 (40.1%)**, and it survives all
twelve seed × history-depth combinations tried.

Everything else moved. The census numbers are now
**V = 2,622 · E = 5,668 · cycle-involved 1,676 · cycle-reachable 1,704 ·
216,176 cycles at cap 14** — exactly the values the Opus-5 audit of 2B-2
predicted from an independent Python transposition
(`docs/audits/2026-07-29-2b-2-census-audit-opus5.md`, F5).

Two things turned up that were not in the brief and that a reader of the
2B-4 deliverable needs (§6): 2B-4's **perturbation calibration never ran** —
the reported "116/177" is a misread of a different output line, and the code
path is unreachable on this graph — and **`2x2.T12` is false under both the
old and the corrected rule**, which removes the stated justification for the
2×2 smoke in `reference-semantics-2026-07-29.md` §2 (the smoke itself still
passes, for a different reason).

---

## 1. The fix

### 1.1 What was wrong

`proof-v2` §1.1 (`docs/evidence/QA-023/proof-v2-2026-07-28.md:40-42`) defines
basic-ko formalization **(i)** as a ko point "set only by a **single-stone ko
capture**", and (A1-ko/passes) at :52-53 repeats it: a stone move "sets
`ko_point` iff it is a single-stone ko capture per (i)".

A single-stone ko capture is two conditions, not one:

1. exactly one opponent stone is captured, **and**
2. the *capturing* stone is a lone stone (chain of size 1) whose only liberty
   is the cell just vacated.

Condition 2 is what makes the ban meaningful: it is the shape in which the
opponent's immediate recapture reproduces the previous position. If the
played stone joins a friendly chain, the recapture takes that whole chain and
lands on a *different* position — a snapback-style exchange, with no
repetition to forbid.

Both copies of `apply_place` tested condition 1 and then counted the **empty
neighbours of the played cell**, never checking that the played stone stood
alone:

- `src/qa023_probe.zig` `apply_place` (the 3×2 rules, used by `moves()` →
  census, fixpoint, history-pairs, probe) — the ko-point block, `:540-549` at
  commit `45ed0f3`, `:552-563` after the fix
- `src/qa023_brute_2x2.zig` `State.apply_place` (the 2×2 rules, reused by
  `qa023_probe.zig:188` for the B1 smoke) — `:118-130` at `45ed0f3`,
  `:120-138` after the fix

When the played stone is part of a larger chain, "empty neighbours of the
played cell" is not the chain's liberty count, so the guard tests the wrong
thing and sets a ko point that formalization (i) does not license.

### 1.2 What changed

One conjunct in each file. Chain-of-size-1 ⇔ the played cell has no friendly
neighbour in the resulting position, so the test is local:

```zig
        for (nb[0..cnt]) |q| {
            if (next_board[q] == 0) liberties += 1;
            if (next_board[q] == colour) friendly += 1;      // NEW
        }
        if (liberties == 1 and friendly == 0) new_ko = captured_cell;
```

With one empty neighbour and no friendly neighbour, that empty cell is
necessarily `captured_cell`: only groups adjacent to the played cell can have
been captured by the placement, so the single captured stone is adjacent, and
it is empty afterwards. No separate identity check is needed.

The 3×2 header comment (`qa023_probe.zig:514-520`) was updated to state the
lone-stone conjunct rather than omit it. Nothing else was touched: no test was
changed, removed, or weakened.

### 1.3 Why this reading and not the other

The brief frames this as a rules ruling, so the alternative deserves a
sentence. Amending the spec to match the code was available — but the code's
rule is not a named Go ruleset, it bans 56 reachable moves that no basic-ko
formalization bans, and it is not what any of the three documents that
describe it say. `proof-v2` §1.1 says "single-stone ko capture"; the 3×2
header comment (`qa023_probe.zig:514-517` at `45ed0f3`) said the same; and the
2×2 test (`qa023_brute_2x2.zig:461-463` at `45ed0f3`) spells out the intended
condition in full — "the *single-stone capture with capturing stone having
exactly 1 liberty* shape". All three describe the corrected rule. Only the
implementation
disagreed, in both copies, in the same way. That is a transcription slip, not
a design choice, and the spec wins.

---

## 2. Verification of the fix itself

The 3×2 numbers below were **predicted before the code was touched**, by an
independent Python implementation written for the 2B-2 audit that uses a
different formulation of the same condition (explicit chain flood-fill:
`len(chain) == 1 and len(liberties) == 1`, rather than the neighbour count
the Zig uses). The Zig now reproduces that Python's predictions to the digit,
on every headline quantity. Two independently written statements of the
corrected rule agreeing on V, E, SCC size, cycle-reachable set and the cycle
count at cap 14 is the substantive check that the one-line change says what
it is meant to say.

**The 2×2 half could not be checked by its own tests.** All seven tests in
`qa023_brute_2x2.zig` call `value`/`brute_value` — trilemma horn 1, the
path-enumeration evaluator that 2B-0 §3 rules NONCONFORMING and that produced
the 10h22m thrash incident. I attempted the one that names the ko rule
(`--test-filter "1-ko shape"`); it was still running at 98% CPU after 2.5
minutes and was killed. Those tests are not a usable guard and I did not
weaken them; they are simply unrunnable.

In their place, two checks that do not touch `value`:

**(a) A scratch Zig driver that BFS-es the 2×2 legal-move graph through the
real `Brute2x2.State.apply_place`/`apply_pass`, compared against an
independent Python transcription** (`ko-fix-2026-07-29/graph2x2.zig`,
`scc2x2.py`). Zig and Python agree exactly, under both the old and the
corrected rule:

| 2×2 roots | rule | V | E | ko-setting edges |
|---|---|---|---|---|
| true root (empty, B, no ko, 0 passes) | old | 263 | 442 | 32 |
| true root | **corrected** | **255** | **434** | **0** |
| all-seed (empty × side × ko × passes) | old | 290 | 516 | 32 |
| all-seed | **corrected** | **282** | **508** | **0** |

**(b) An exhaustive enumeration of every 2×2 placement** (all 3⁴ gobans × 2
sides × empty cells, `ko-fix-2026-07-29/ko2x2.py`): the old rule sets a ko
point on **16** placements; the corrected rule sets one on **0**.

That second result is worth stating plainly, because
`qa023_brute_2x2.zig:475-477` asserts the opposite of what the code did:

> "So on 2x2, basic-ko with formalization (i) NEVER fires! The 2x2 goban is
> too small for the ko shape to occur."

That comment was **false as written** — the shipped rule fired on 16 of the
2×2 placements — and the fix makes it true. Worked example, from the
enumeration: goban `B W / B .` (cells 0,1 / 2,3), Black plays cell 3 and
captures the lone White stone at 1, whose only two neighbours are now Black.
Cell 3 has exactly one empty neighbour afterwards (cell 1), so the old rule
set a ko point there. But the played stone is not alone: it joins the Black
chain {0, 2, 3}, whose sole liberty is cell 1. White's reply at 1 captures all
three Black stones and leaves `. W / . .` — a position that has never occurred.
That is a snapback, not a ko, and the old rule forbade it.

---

## 3. Corrected census (2B-2 re-run)

`cycle-census-3x2 --max-cycle-len 14 --max-cycles 1000000000`, everything else
unchanged (the 42-state seed set of `seed_roots` is **not** touched here —
audit finding F1 is a separate defect and is still open; see §7).

| quantity | 2B-2 as published | corrected rule | audit prediction |
|---|---|---|---|
| reachable V | 2,682 | **2,622** | 2,622 ✓ |
| directed edges E | 5,744 | **5,668** | 5,668 ✓ |
| states with a real ko point | 120 | **60** | 60 ✓ |
| SCCs total / non-trivial | 987 / 1 | **947 / 1** | — |
| max SCC = cycle-involved | 1,696 | **1,676** | 1,676 ✓ |
| cycle-reachable | 1,724 | **1,704** | 1,704 ✓ |
| simple cycles, cap 14 | 143,760 | **216,176** | 216,176 ✓ |
| distinct legal gobans | 489 | **489** | (T13 cross-check holds) |
| non-terminal states | 1,816 | **1,756** | — |

Cycle histogram at cap 14, corrected — still all-even, as the parity argument
requires (every move flips `side`):

| length | 6 | 8 | 10 | 12 | 14 |
|---|---|---|---|---|---|
| as published | 16 | 1,296 | 11,004 | 25,060 | 106,384 |
| **corrected** | **16** | **1,296** | **15,212** | **35,548** | **164,104** |

Lengths 6 and 8 are unchanged; the extra cycles are all length ≥ 10, which is
what removing 56 spurious edge-bans should do — it lengthens what was
previously cut short, it does not manufacture short cycles.

### 3.1 Cap sweep, corrected — and the caveats that were wrong

Audit finding F2 reported that the three "honest caveats" in the 2B-2
deliverable were false: caps 16/18/20 were said to have "hit the cycle cap"
and none of them had. That is still true under the corrected rule. Every cap
below completes naturally; **`cycles_capped` is 0 at every one**:

| cap | as-published rule | corrected rule |
|---|---|---|
| 12 | 37,376 | **52,072** |
| 14 | 143,760 | **216,176** |
| 16 | 511,840 | **802,552** |
| 18 | 3,288,800 | **6,169,560** |
| 20 | 16,192,056 | **31,033,764** |
| 22 | 70,772,876 | **132,966,392** |

The cap-22 run took 385 s; the rest are seconds. "Completes naturally" is
checkable in the stdout: `run_cycle_census_3x2` appends
`" (CAPPED — counted only)"` to the cycles-found line when the count cap is
hit (`src/qa023_probe.zig:2456`), and that suffix appears at **no** cap in any
run recorded here.

The correct caveat is the one F2 asked for: the count at every cap tested is
the *natural completion at that length*, the count cap was never reached, and
the true unbounded total is at least the cap-22 figure. The abundance argument
for B-VACUITY is stronger under the corrected rule, not weaker.

*Record correction, incidental:* the Kimi-k2.7 2B-2 audit summary circulated
`cap 22 = 70,777,276`. The committed stdout it was drawn from
(`docs/evidence/AUDIT-2B-2/census-cap22-rerun.stdout`) reads **70,772,876**,
which is also what the Opus audit reported. A digit slip in the summary, not
in the run; the table above uses the stdout.

### 3.2 Verdict

**`3x2.QA023.B-VACUITY`: PASS, unchanged.** 216,176 simple directed cycles at
cap 14 in the reachable legal-move graph; 1,676 cycle-involved vertices. The
finding is robust to the rule correction — as the audit said it would be.

---

## 4. Corrected probe (2B-4 re-run) — the answer to the brief's question

Same command as 2B-4, same seed, same parameters:

```sh
probe-3x2 --seed 0x2B4DA7A --n-samples 256 --k-histories 8 --history-depth 16
```

| metric | 2B-4 as published | corrected rule |
|---|---|---|
| samples evaluated | 177 | 171 |
| total history-evaluations | 1,080 | 1,133 |
| value-agreements (v ≠ TIE, v = V) | 0 | **0** |
| TIE-valued (v = TIE = V) | 690 | 679 |
| budget-exhausted | 0 | **0** |
| **disagreements** | **390 (36.1%)** | **454 (40.1%)** |

**The falsification is not a wrong-rule artefact.** It holds, and it is
larger. Zero evaluations were budget-exhausted, so every one of the 454 is a
genuine within-budget counterexample in the 2B-0 §2 sense.

The mechanism is unchanged: *every* evaluation returns TIE. The truncated
evaluator never reaches a terminal from any sampled state under any sampled
arrival history, because the graph is densely cyclic (1,704 of 1,756
non-terminal states are cycle-reachable — and that ratio *rose*, from
1,724/1,816 = 94.9% to 1,704/1,756 = 97.0%). Where the fixpoint pins a
non-zero V, the evaluator disagrees.

First disagreement, verbatim, decoded — state `(board=120, side=Black, ko=6,
passes=1)`, V_fixpoint = +6, truncated = TIE:

```
arrival: B0 W5 B3 pass B1 pass B4 W2 B4 pass B1 W5 B2 pass B3 pass
```

### 4.1 Robustness — 12 runs, all falsify

Not seed-specific and not depth-specific. Four seeds × three history depths,
256 samples × 8 histories each:

| seed \ depth | 16 | 24 | 40 |
|---|---|---|---|
| `0x2B4DA7A` | 454 / 1,133 (40.1%) | 444 / 1,032 (43.0%) | 364 / 869 (41.9%) |
| `0xC0FFEE5` | 413 / 1,105 (37.4%) | 434 / 991 (43.8%) | 406 / 962 (42.2%) |
| `0xF00D`    | 550 / 1,129 (48.7%) | 392 / 1,071 (36.6%) | 401 / 1,023 (39.2%) |
| `0x5EED`    | 484 / 1,131 (42.8%) | 423 / 1,056 (40.1%) | 321 / 870 (36.9%) |

All twelve: value-agreements 0, budget-exhausted 0.

A Wilson 95% lower bound on the headline run is 37.3%, but **that number
should not be quoted** — the 1,133 evaluations are 8 per sampled state and are
not independent. The defensible statement is the count, not a rate with a
confidence interval: 454 within-budget counterexamples, and a single one
falsifies.

### 4.2 The upstream inputs, re-run

- **2B-3 (history-pair vacuity), corrected rule:** 102/102 sampled multi-history
  states have visit-set-distinct arrival histories, 2,563/2,563 pairs distinct.
  **VACUITY-GUARD PASS** (was 93/93).
- **`census-3x2`:** 2,622 states, 489 distinct legal gobans — still matches the
  T13 reference. 866 terminals.
- **`fixpoint-3x2`:** converges in 2 sweeps. Pin census
  `L==H = 948 · pin_T = 1,532 · pin_L = 142 · pin_H = 0` (pin_T fell from
  1,592; the other three are unchanged).
- **`smoke-2x2`:** 5/5 anchors OK. Empty-goban Black is still **0**, not +1, so
  the PSK discriminator still discriminates.
- **`zig test --test-filter "2x2 smoke" --test-filter "3x2" src/qa023_probe.zig`:**
  5/5 pass. (As the 2B-2 audit noted, none of the five touches the census.)

---

## 5. Calibration (brief §Acceptance, last bullet)

- **NEG — `calibrate` mode: PASS**, unchanged by the fix. The synthetic gadget
  still separates the v2 median rule from the v1 `L<H ⇒ T` rule at all four
  states. This is the recorded run 2B-5 wants for `B-CAL-NEG`.
- **POS — PSK-sensitivity: NOT RUN, because it does not exist.** There is no
  PSK mode in `qa023_probe.zig`; `docs/infra/dispatch/2B-5.md` describes it as
  work still to be done ("the PSK-mode flag touches it"), and 2B-5 has not
  been dispatched. Nothing was re-run because nothing was there to re-run.
  `3x2.QA023.B-CAL-POS` remains UNTESTED.
- **The in-probe TIE perturbation: vacuous, under both rules.** See §6.1 —
  this is the finding, not a result.

---

## 6. Two findings outside the brief

### 6.1 2B-4's perturbation calibration never executed

The 2B-4 deliverable (`probe-3x2-2026-07-29.md:120-123`) states:

> **Perturbation test:** raising TIE from 0 to 1 changes the truncated value
> for 116/177 states, confirming that TIE is on the optimal line (i.e., the
> cycle leaf IS the game-theoretic outcome under first-revisit truncation).

No such measurement was made. The recorded stdout
(`probe-3x2-2026-07-29.stdout`) contains no perturbation line; it contains
`cycle-census states (any history hit TIE leaf): 116` and
`samples evaluated: 177`. "116/177" is those two lines read as one.

The lines measure something else. `cycle_census_states` is incremented at
`qa023_probe.zig:1688`, inside the branch where the evaluator returned TIE
**and the fixpoint agreed** — it counts samples that hit a TIE leaf, and says
nothing about perturbing TIE.

The actual perturbation call at `:1724` sits after two `continue`s
(`:1690`, `:1717`), so it is reached only when `v ≠ TIE` **and**
`v == V_fixpoint` — the value-agreement case, counted at `:1732`. Both runs
report **value-agreements = 0**. The perturbation branch executed zero times,
under the old rule and under the corrected one. It cannot execute while every
evaluation returns TIE, which is exactly what this graph does.

Consequence: the sentence "TIE is on the optimal line" in the 2B-4 deliverable
is unsupported and should be struck. It does not affect the falsification —
that rests on the 390 (now 454) disagreements, which are real — but it is a
claim with no run behind it, in a deliverable being promoted to CLAIMS. And it
means the probe's built-in NEG calibration is **structurally unreachable** on
3×2: any future 2B-5 must plant its perturbation somewhere the code can see it.

### 6.2 `2x2.T12` is false — under the old rule as well as the corrected one

`reference-semantics-2026-07-29.md` §2 justifies using the 2×2 fixpoint as the
smoke reference like this:

> NOT circular *for the smoke's purpose*: 2×2 admits no reachable non-root
> cycles (`2x2.T12`) […]

The 2×2 reachable graph has a **144-vertex non-trivial SCC under the shipped
rule** and a **160-vertex one under the corrected rule** (§2(a); Tarjan over
the reachable set from the true root, Zig-and-Python agreeing). Every vertex
in it lies on a directed cycle. This is the same phenomenon audit finding F6
reported from an independent transposition — it now reproduces inside the
project's own rules code, which is what F6 asked for, and it does **not**
depend on the fix.

The fix does change how much this matters. Independent 2×2 median-fixpoint
over all 2,430 state tuples (`ko-fix-2026-07-29/fix2x2.py`):

| | old rule | corrected rule |
|---|---|---|
| states with L == H | 2,430 (all) | 1,714 |
| states where V moved | — | 432 |

Under the shipped rule the cycles existed but were value-irrelevant: L and H
coincided everywhere, so TIE never entered a 2×2 value and the smoke reference
was unambiguous whatever T12 said. Under the corrected rule 716 states have
L < H, and TIE genuinely participates.

**The smoke still passes and still discriminates** — all five B1 anchors hold
under the corrected rule in both the Zig and the independent Python, and
empty-goban-Black is 0 where PSK would give +1. But §2's *stated reason* for
it not being circular is not a true statement about the graph, and should be
replaced with the reason that is true: the five anchors are externally
published values (MIGOS II), and external anchors do not become circular just
because the graph has cycles.

---

## 7. What this task did not do

- **F1 (`seed_roots` seeds 42 states, not four) is untouched.** The 36
  empty-goban-with-a-ko-point seeds are still in the reachable set; 2,622 and
  1,704 still include them. Measured with the corrected ko rule *and* the
  single true game root (empty, Black, ko = none, passes = 0): **V = 2,583,
  E = 5,510, real-ko states 24, cycle-involved 1,676, cycle-reachable 1,678**.
  The SCC is identical either way — F1 only trims phantom tail — so it changes
  no verdict, but it moves three published numbers and should land **before**
  2B-2/2B-3/2B-4 are re-issued rather than after. Distinct defect, not in this
  brief's scope.
- **No claim status was changed.** `CLAIMS.md` untouched, per the brief.
- **No 2B-N deliverable was edited.** The corrections in §3.1, §6.1 and §6.2
  are reported here for their owners to fold in.

## 8. Proposed claim-status changes (for the CLAIMS owner)

- `3x2.QA023.B-VACUITY` — **PASS stands**, with corrected numbers: 216,176
  simple cycles at cap 14, 1,676 cycle-involved, 1,704 cycle-reachable,
  V = 2,622, E = 5,668.
- `3x2.QA023.B-PROBE` — **FALSIFIED stands**, with corrected numbers: 454
  within-budget disagreements out of 1,133 evaluations, 0 budget-exhausted,
  robust across 4 seeds × 3 depths. The wrong-rule objection raised by audit
  F5 is **resolved, in favour of the falsification**.
- `3x2.QA023.B-CAL-NEG` — the `calibrate` run is recorded here and passes.
  Note §6.1: the probe's *in-run* perturbation is a separate mechanism and is
  unreachable; only the synthetic gadget calibrates today.
- `3x2.QA023.B-CAL-POS` — **UNTESTED**, no PSK mode exists.
- `2x2.T12` — should be **withdrawn or rescoped to PSK**. It is false for
  basic ko under both the old and the corrected rule (§6.2).

## Files

- `docs/evidence/QA-023/ko-fix-rerun-2026-07-29.md` — this file.
- `docs/evidence/QA-023/ko-fix-rerun-2026-07-29.stdout` — every corrected-rule
  run above, verbatim.
- `docs/evidence/QA-023/ko-fix-2026-07-29/` — the 2×2 cross-check that stands
  in for the unrunnable in-file tests (`ko2x2.py`, `fix2x2.py`, `scc2x2.py`,
  `graph2x2.zig`) plus the corrected cap-sweep stdouts.
- `docs/evidence/QA-023/PROVENANCE-ko-fix-rerun-2026-07-29.md`.
- `src/qa023_probe.zig`, `src/qa023_brute_2x2.zig` — the fix.
