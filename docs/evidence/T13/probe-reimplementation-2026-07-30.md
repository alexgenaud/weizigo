Task: T110 · Role: worker · Model: Opus 5 (`claude-opus-5[1m]`) · Date: 2026-07-30

# T13 re-implemented: the C2 falsification at 3×2 is reproducible again

**Headline: `3x2.T13` reproduces. All twelve recorded contradiction lines
re-execute exactly — same goban, same stored L==H value, same history-aware
value — under an independent Python re-implementation built from the durable
descriptions alone. Every census number matches (489 legal / 30 settled /
189+189 ko-sensitive / 540 L==H slots / 508 histories tested / 0 fresh-start
mismatches). The `CANNOT REPRODUCE` banner on the register row can come down.**

**And it reproduces in the committed Zig as well** (§5). `retro.ab_solve` was
never lost — only the driver that called it. Rewriting that driver
(`zig_t13_replay.zig`, 72 lines) returns all twelve recorded values from
`src/retro.zig` at HEAD, and the Python port matches the Zig L/H tables on
5,868/5,868 cell values. Three independent routes to the same twelve numbers.
The corollary is uncomfortable: the loss was a convenience script, and the
register recorded it as the loss of the experiment.

**One correction to how T13 should be read.** Its "12 mismatches" is not an
invariant of the goban — it is a count of falsifying *(slot, history)* pairs in
an order-dependent sample of one history per slot. A re-run whose enumeration
visits lines in a different order finds the same *slots* through different
lines and reports a different number (this re-implementation's own search
finds all twelve slots plus two more, for 14). Testing *every* reachable
history instead of one per slot gives the order-independent answer: **154 of
the 508 reachable L==H slots — 30.3% — are history-sensitive, not 12** (§8).
All twelve of T13's are among them. The falsification is an order of magnitude
broader than the record shows, so this strengthens C2's refutation; it does not
weaken it. See §9 for the proposed register wording.

A second result was not asked for and is worth more than the count: **the
falsification survives with the ADR-0006 eye-prune switched off** (§7), so
`3x2.T13` is not among the results that `ADR0006-FALSIFY` would contaminate.

---

## 1. What was asked, and what was actually available

`untracked/c2pilot_3x2.zig` (the probe) and `untracked/T13-minimax.md` (the raw
output) were swept with `untracked/` and are not in git. What survives is
`docs/research/c2-falsification-3x2.md`: the claim, a six-step method, a
measurement table, a ban-set-size distribution, and all twelve contradiction
lines with their colex histories. `PROGRESS.md` §3.1 and the `3x2.T13` row of
`CLAIMS.md` add nothing procedural.

This is therefore a **re-implementation from the method description, not a port
of the lost code**. That distinction is what makes it worth doing: an
independent implementation that lands on the same twelve lines is stronger
evidence than a recovered copy of the original would have been, because it
cannot inherit the original's bugs.

### What is *not* re-implemented — and why that matters

The primitives are ported line-by-line from the **committed** Zig, which was
never lost:

| Python (`t13_probe.py`) | Zig source |
|---|---|
| `colex_from_pos` / `pos_from_colex` | `src/colex.zig` `Indexer(3,2)` |
| `is_legal` | `src/enumerate.zig` `Enumerator.is_legal` |
| `pos_from_move`, `area_score`, `benson_alive`, `is_settled`, `is_own_eye` | `src/rules.zig` `Rules(3,2)` |
| `Tables.seed/_sweep/converge/finalize` | `src/retro.zig` `Retro(3,2)` |
| `Solver.solve` | `src/retro.zig` `Retro(3,2).ab_solve` with `memo=false`, `brackets=false`, `deps=false`, window `[-127,127]` |

Only the **probe driver** — steps 3–5 of the method, the part that was lost —
is a reconstruction. So a disagreement between this file and T13 is a
disagreement about the probe, never about the rules of the game.

## 2. The method, as re-executed

Verbatim from `c2-falsification-3x2.md` §Method, with the reconstruction
decisions marked **[R]**:

1. Build the 3×2 L/H retrograde tables (`seed` → `converge` → `finalize`).
2. Identify all L==H slots.
3. Enumerate short PSK-legal placement-only game lines up to 10 ply from every
   legal start position, global line budget 2,000,000 nodes.
   **[R]** "placement-only" = no pass edges in the enumerated line; "10 ply" =
   at most 10 gobans in the line including the start; the first mover from
   every start is **Black** (forced by the parity of all twelve recorded
   lines — see §4); and the move generator here is **not** eye-pruned, since
   ADR-0006 constrains optimal play and not reachability (§6 — three of T13's
   own lines fill an eye).
4. For each line ending at an L==H position, run `ab_solve` with `memo=false`,
   `brackets=false`, window `[-127,127]`, and the history pre-populated with
   every goban of the line including the endpoint.
5. Compare against the stored L==H score.
   **[R]** one history per slot — see §6.
6. Fresh-start sanity: the same solver on every L==H slot with the history
   seeded only with the root.

Alpha-beta with no memo and no bracket cuts returns the exact minimax value:
pruning never changes a root value, and with no cross-history reuse there is no
graph-history-interaction (GHI) risk. The `[L,H]` tables survive in the solver
only as a move-ordering key, which cannot affect the value returned.

## 3. Step 1–2 and step 6: every census number matches

```
$ python3 docs/evidence/T13/t13_probe.py census
tables: legal=489 settled=30 ko_sensitive_b=189 ko_sensitive_w=189 sweeps=6
L==H slots (non-settled legal x side): 540

$ python3 docs/evidence/T13/t13_probe.py sanity
fresh-start sanity: 0 mismatches / 540 L==H slots
```

| metric | T13 (2026-07-26) | this re-implementation | |
|---|---|---|---|
| Legal positions | 489 | 489 | ✓ |
| Settled positions | 30 | 30 | ✓ |
| Ko-sensitive slots | 189 B / 189 W | 189 B / 189 W | ✓ |
| L==H slots | 540 | 540 | ✓ |
| Fresh-start sanity mismatches | 0 | 0 | ✓ |
| Non-trivial histories tested | 508 | 508 | ✓ |
| Budget-unreachable histories | 0 | 0 | ✓ |

Two of these deserve a note.

**540 is not 30 + 189 + 189.** The write-up's parenthetical "(30 settled + 189 B
ko-sensitive + 189 W ko-sensitive, 489 legal positions total)" is a census
aside, not an addend list — a reader who adds it gets 408 and concludes the
write-up is inconsistent. 540 = 2 × (489 − 30 − 189) — the L==H slots are counted over **non-settled**
legal positions × two sides. Settled positions are excluded because `finalize`
assigns them their area score directly, never through the fixpoint. Including
them would give 600.

**508 was reproduced independently, and is a structural fact.** 508 of the 540
L==H slots are reachable as the endpoint of a placement-only PSK line of ≤ 10
gobans from some legal start with Black moving first; the other 32 are not.
This re-implementation's enumeration differs from the original's in both order
and scope (§6) and still lands on exactly 508 — so 508 measures the goban, not
the traversal.
The 32 slots with a ban-set of size 1 in the distribution table are the starts
themselves, tested with a trivial history; the write-up's own label calls
them "size 1 = fresh-start", which sits awkwardly against the row heading
"non-trivial histories tested". They are 32 of the 508, not 32 in addition.

## 4. Step 7 (new): all twelve recorded contradictions re-execute exactly

Each recorded line was decoded from colex, checked to be a legal placement-only
PSK line with the recorded parity, and re-solved.

```
$ python3 docs/evidence/T13/t13_probe.py replay
```

| idx | side | depth | goban | L==H | stored | T13 expected | T13 got | re-impl got | fresh-start | line legal |
|---|---|---|---|---|---|---|---|---|---|---|
| 314 | B | 9 | `BWW/..W` | yes | +6 | +6 | −6 | **−6** | +6 | yes |
| 413 | B | 9 | `.WW/.BW` | yes | +6 | +6 | +1 | **+1** | +6 | yes |
| 410 | B | 9 | `.BW/.WW` | yes | +6 | +6 | −6 | **−6** | +6 | yes |
| 459 | B | 9 | `..W/BWW` | yes | +6 | +6 | −6 | **−6** | +6 | yes |
| 267 | B | 9 | `WB./WW.` | yes | +6 | +6 | −6 | **−6** | +6 | yes |
| 433 | B | 9 | `W../WWB` | yes | +6 | +6 | −6 | **−6** | +6 | yes |
| 237 | B | 9 | `WWB/W..` | yes | +6 | +6 | −6 | **−6** | +6 | yes |
| 273 | B | 9 | `WW./WB.` | yes | +6 | +6 | +1 | **+1** | +6 | yes |
| 359 | W | 10 | `W.B/B.B` | yes | −6 | −6 | −1 | **−1** | −6 | yes |
| 346 | B | 9 | `B.W/W.W` | yes | +6 | +6 | +1 | **+1** | +6 | yes |
| 398 | W | 10 | `B.W/.BW` | yes | +6 | +6 | +1 | **+1** | +6 | yes |
| 347 | B | 9 | `W.B/W.W` | yes | +6 | +6 | +1 | **+1** | +6 | yes |

**12/12** on every column: the line is legal and its parity matches the
recorded side to move; the stored L==H value equals T13's `expected`; the
history-aware value equals T13's `got`; and the fresh-start value equals the
stored value (so each is a C2 failure, not a C1 failure).

This is the load-bearing result. It does not depend on reconstructing the
enumeration order, the tie-breaking, or anything else that was lost — the
twelve histories are given in the durable record, and they are the evidence.

### A hand-verifiable counterexample

`idx=413`, Black to move, history `0 2 26 40 110 278 57 211 413`:

```
0    .../...      (empty)
2    B../...      B 0
26   B../W..      W 3
40   B../.B.      B 4, capturing W 3
110  BW./.B.      W 1
278  BW./BB.      B 3
57   .W./..W      W 5, capturing the Black chain {0,3,4}
211  .W./.BW      B 4
413  .WW/.BW      W 2
```

At `413 = .WW/.BW` the three White stones {1,2,5} form one chain whose **only**
liberty is cell 0. Black plays 0, captures all three, and owns the board:
`area_score = +6`. That is exactly the stored fresh-start value, and the
re-implementation confirms it (`fresh-start = +6`).

But the post-capture goban is `B../.B.` — **colex 40, the fourth entry of this
very history**. Positional superko forbids it. Black's goban-winning move does
not exist in this game, and the true value collapses to **+1**.

Nothing about this requires trusting either implementation: the chain, its
single liberty, the capture, and the repeat are all checkable by eye. C2 —
"where L==H the score is the same under every reachable history" — is false at
3×2, and this is why.

## 5. The committed Zig reproduces T13 too — the loss was smaller than recorded

The re-implementation makes a stronger check available than either half alone.
`retro.ab_solve` was never lost; only the driver that called it was.
`docs/evidence/T13/zig_t13_replay.zig` supplies that driver — the twelve
recorded histories, `memo=false`, `brackets=false`, `deps=false`, window
`[-127,127]` — and runs them through the **committed** engine at HEAD:

```
$ zig build-exe -O ReleaseFast --dep retro \
    -Mmain=docs/evidence/T13/zig_t13_replay.zig -Mretro=src/retro.zig \
    -femit-bin=/tmp/t13replay && /tmp/t13replay
# idx side stored history_value fresh_value
314  1   6   -6   6      413  1   6    1   6      410  1   6   -6   6
459  1   6   -6   6      267  1   6   -6   6      433  1   6   -6   6
237  1   6   -6   6      273  1   6    1   6      359 -1  -6   -1  -6
346  1   6    1   6      398 -1   6    1   6      347  1   6    1   6
```

Every value equals the 2026-07-26 record **and** the Python of §4. And
`docs/evidence/T13/zig_dump_3x2.zig` dumps the Zig L/H tables slot by slot for
a direct diff of the other half:

```
$ /tmp/dump3x2 2>/tmp/zig-tables.txt
$ python3 docs/evidence/T13/diff_zig_tables.py /tmp/zig-tables.txt
zig header: # legal=489 settled=30 kob=189 kow=189 sweeps=6
python    : legal=489 settled=30 kob=189 kow=189 sweeps=6
rows compared: 489   cell values compared: 5868
rows differing: 0
```

All 5,868 values — `settled`, `score`, `lo.b0/hi.b0/lo.w0/hi.w0`,
`lo.b1/hi.b1/lo.w1/hi.w1`, `vb` — over all 489 legal positions are identical
between the Python port and `src/retro.zig`.

So there is now a **three-way agreement**: the 2026-07-26 record, the committed
Zig engine, and an independent Python re-implementation. Any two of them
disagreeing would have localised the fault; none do.

**This revises how the loss should be described.** `docs/evidence/README.md`
says the reproduction "cannot be executed" because its `-Mmain=` input is gone,
and that was literally true. But what was gone was a driver — a list of twelve
histories and a loop — reconstructible in an afternoon from the durable record,
against an engine that has been in git the whole time. The banner said *the
falsification cannot be re-run*; the accurate statement was *the falsification's
convenience script is gone*. Both are bad, and the `AGENTS.md` rule they
produced is right. But the register overstated the damage on its most
load-bearing row, and overstatement in that direction has its own cost: a row
marked *cannot be re-executed* invites nobody to try, and this one could have
been cleared for an afternoon's work at any point since the sweep.

## 6. Step 3–5 re-run: the same twelve, plus two the original missed

```
$ python3 docs/evidence/T13/t13_probe.py search
lines examined        : 271057
histories tested      : 508
history-aware mismatch: 14
```

| idx | side | depth | expected | got | history | in T13? |
|---|---|---|---|---|---|---|
| 410 | B | 9 | +6 | +1 | `0 8 27 32 140 272 45 122 410` | yes |
| 459 | B | 9 | +6 | −6 | `0 8 27 32 140 272 45 147 459` | yes |
| 314 | B | 9 | +6 | −6 | `0 10 51 40 204 432 57 154 314` | yes |
| 413 | B | 9 | +6 | −6 | `0 10 51 40 204 432 57 211 413` | yes |
| 237 | B | 9 | +6 | −6 | `0 10 70 48 150 470 29 99 237` | yes |
| 273 | B | 9 | +6 | −6 | `0 10 70 48 150 470 29 141 273` | yes |
| 267 | B | 9 | +6 | +1 | `0 12 63 60 214 420 37 107 267` | yes |
| 433 | B | 9 | +6 | −6 | `0 12 63 60 214 420 37 205 433` | yes |
| 359 | W | 10 | −6 | +1 | `1 55 205 403 105 385 585 64 167 359` | yes |
| 346 | B | 9 | +6 | +1 | `2 16 84 112 384 584 61 162 346` | yes |
| 398 | W | 10 | +6 | +1 | `2 16 84 112 384 584 61 219 461 398` | yes |
| 347 | B | 9 | +6 | +1 | `4 44 212 128 308 660 25 91 347` | yes |
| **331** | **B** | **9** | **+6** | **−6** | `4 44 212 128 308 660 25 83 331` | **no** |
| **429** | **B** | **9** | **+6** | **+1** | `4 44 212 128 308 660 25 133 429` | **no** |

**All twelve T13 slots recur, and two more appear** (`331 = WB./W.W`,
`429 = W../WBW`, both Black to move at depth 9). No T13 slot is missing. The
histories differ from T13's — same slots, same depths, different lines — which
is expected of any traversal with a different visit order. All twelve of T13's
own histories are *members* of the population enumerated here (§4 checks each
one: legal start, placement-only, PSK-clean, Black-first parity, ≤10 gobans);
they are simply not the member each slot was assigned first.

And the ban-set distribution now agrees **in every bucket**:

| size | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | total |
|---|---|---|---|---|---|---|---|---|---|---|---|
| T13 | 32 | 21 | 74 | 84 | 83 | 48 | 36 | 40 | 45 | 45 | 508 |
| re-impl | 32 | 21 | 74 | 84 | 83 | 48 | 36 | 40 | 45 | 45 | 508 |

Ten of ten. A histogram over which history each of 508 slots was assigned is
about as traversal-sensitive a statistic as the probe produces, so an exact
match across all ten buckets is strong evidence that the reconstructed
enumeration has the same *shape* as the original, even though it walks the tree
in a different order.

### The mistake that got this right — and it is a methodological one

The first version of this section reported **8** mismatches and a distribution
that missed on five buckets, because `enumerate_lines` applied the ADR-0006
eye-prune. That was wrong, and the way it is wrong is worth recording.

ADR-0006 is a **dominance** argument about optimal play: filling your own
Benson-alive true eye cannot improve your area score, so a *search* may skip
such moves. It says nothing whatever about which positions a real game can
reach. A reachable PSK history is exactly a line a real game can walk down, and
real games fill their own eyes. Applying a search prune to the *enumeration*
silently deletes histories from the population under test — the probe then
measures sensitivity over a subset of reality and reports the shortfall as a
smaller number.

Concretely, it deleted three of T13's own twelve lines:

| line | blocked at | move |
|---|---|---|
| `2 16 84 112 260 500 61 162 346` | ply 4→5 | B fills cell 3 of `BBW/.B.` |
| `1 19 77 325 105 253 477 64 167 359` | ply 5→6 | W fills cell 3 of `WWB/.W.` |
| `4 24 172 128 263 567 25 91 347` | ply 4→5 | B fills cell 5 of `WBB/.B.` |

(and `398`, which extends `346`). T13 did not make this mistake — its recorded
lines contain eye-fills, which is how the error was caught here. The generalisable
rule: **ADR-0006 belongs in the solver, never in a reachability enumeration.**
Any future history-sensitivity probe — `EXP-2B`, `PINRULE-SUFFICIENCY`, a 4×4
C2 attempt — that enumerates arrival histories with an eye-pruned move
generator will under-report for this reason, and its zero or its small number
will not mean what it appears to mean. `t13_probe.py` keeps an `eye_prune=True`
switch on `enumerate_lines` so the wrong answer can be reproduced deliberately.

### Two numbers still do not reconcile, and one of them is "12"

**"12" is a property of a traversal, not of the goban.** T13 tests one history
per L==H slot, so its count is over 508 draws — one per slot — with each draw
fixed by visit order. This run, walking the same population in a different
order, draws 14. Neither number measures the 3×2 goban; §8 does. "12" should
not have entered `CLAIMS.md` phrased as though it were a property of the game.

**`153,613` lines is unreconciled.** A line count is order-invariant, so the
gap against this run's `271,057` is a real difference in what was enumerated,
and it does not close under any natural reading:

| reading of "game lines examined" | count |
|---|---|
| all prefixes, Black first, ≤10 gobans, no eye-prune (this run) | 271,057 |
| …counting only maximal lines | 141,570 |
| …with the ADR-0006 eye-prune wrongly applied | 190,647 |
| …enumerating both sides to move from each start | 542,114 |
| …prefixes ending at a non-settled position | 246,201 |
| …prefixes ending at an L==H slot | 134,504 |
| …not extending a line past a settled position | 202,083 |
| …skipping settled start positions | 251,701 |
| **T13** | **153,613** |

Something in the original driver bounded the walk in a way the durable record
does not state. Given that the ban-set histogram matches in all ten buckets and
the reached-slot count matches exactly at 508, whatever it was did not change
the population of slots tested — but that is an inference, and it is recorded
here as one.

**This is why §4, not §6, is the load-bearing check.** The verbatim replay needs
no enumeration at all: the twelve histories are given, and they re-execute in
two independent implementations. The reconstruction of *how* those twelve were
found is unavoidably approximate, and nothing rests on it.

## 7. The falsification does not depend on ADR-0006

`docs/infra/dispatch/ADR0006-FALSIFY.md` states the exposure plainly:

> **Every forward search the project uses as ground truth applies this prune** —
> the 2×2/3×2 exact solver, the finisher, T13, E2. If ADR-0006 is wrong, every
> C1 proof, every C2 probe and every finisher-produced value is contaminated.

For T13 the exposure is sharper than that sentence suggests, because the two
sides of its comparison do not use the same move set. `Retro.apply_eye_prune`
is **false** (`src/retro.zig:98`), so the retrograde sweep that produces the
stored L==H value expands *every* empty point. `ab_solve` calls `is_own_eye`
(`src/retro.zig:540`), so the probe's history-aware value is computed over the
*pruned* move set. A mismatch between them is, a priori, consistent with
"ADR-0006 is unsound" and not only with "C2 is false".

Re-solving all twelve recorded lines with the prune disabled — making the
probe's move set identical to the sweep's — settles it:

```
$ python3 docs/evidence/T13/t13_probe.py adr0006
counterexamples surviving with the eye-prune OFF: 12/12
values unchanged by the prune setting: 12/12
```

Not merely "still counterexamples": **all twelve lines, in both the
history-conditioned and the fresh-start query, return bit-identical values with
the prune on and with it off.** The claim here is exactly what was measured —
the prune changes no value in any of these searches — not the stronger "the
prune never fires". `3x2.T13` is therefore invariant to ADR-0006 and should be
struck from that dispatch's contamination list. `3x2.C1`, `3x3.C3`/E2 and the
finisher are untouched by this and remain exposed.

**Not in conflict with T114.** `docs/audits/eye-prune-validation-2026-07-30.md`
(T114, same date) reports that the sound unpruned control "does not terminate
(32/32 roots unresolved at **3×2**)". That is about **fresh-start roots from a
near-empty goban**, where the unpruned tree is the whole game. The twelve
positions here carry 4–6 stones and sit under a 9–10 goban ban set, so their
remaining trees are small and both arms finish in about a second. Both
statements are true of different searches; a reader meeting them side by side
should not conclude either is wrong. T114's verdict — ADR-0006 not falsified,
further validated — is consistent with what this section measures.

Note the direction of the two eye-prune findings and do not conflate them. In
the **solver** the prune is harmless here (this section). In the
**enumeration** it is not harmless at all — it deletes reachable histories and
shrinks the answer (§6). Same ADR, opposite verdicts, because the two uses make
different demands of it.

## 8. The order-independent measurement: 154 slots, not 12

Every reachable history of every L==H slot, rather than one history per slot:

```
$ python3 docs/evidence/T13/t13_probe.py exhaustive
(slot, history) pairs tested : 134504
distinct ban-sets solved     : 134504  (summed over 17 workers)
L==H slots reached           : 508 / 540
falsifying (slot, history) pairs : 4432
L==H slots with >=1 falsifying history : 154  (30.3% of reached)
distinct falsifying values seen : -6, -3, -1, +0, +1, +3, +6
```

**154 of the 508 reachable L==H slots — 30.3%, spread over 132 distinct goban
positions — have at least one reachable PSK history under which the true value
differs from the stored fresh-start value.** That is the number that measures
the goban. It does not depend on visit order, on which history a slot is
assigned, or on where a traversal chose to stop, because every pair is tested.

Containment checks, both clean:

- All **12** of T13's slots are in the 154.
- Both extras from §6 (`331`, `429`) are in the 154.

| statistic | value |
|---|---|
| L==H slots reached / total | 508 / 540 |
| slots with ≥1 falsifying history | **154** (30.3% of reached) |
| distinct positions involved | 132 |
| falsifying (slot, history) pairs | 4,432 of 134,504 (3.3%) |
| slots admitting >1 distinct falsifying value | 62 |
| shortest falsifying history | **5 gobans** (4 moves), for 12 slots |
| stored value on falsifying slots | +6 on 112, −6 on 38, **0 on 4** |

Three things in that table are worth pulling out.

**T13 under-reported by more than an order of magnitude.** 12 versus 154 is not
a rounding difference. C2 does not fail at a handful of exotic deep positions;
it fails on roughly a third of the single-score region that a real game can
actually reach. The "certified core" framing was withdrawn on the strength of
12 counterexamples, and the withdrawal was right by a much larger margin than
the evidence then showed.

**It fails early.** Twelve slots are falsified by a history of only five gobans
— four moves from a legal start. History-sensitivity is not a deep-endgame
phenomenon that a shallow search would be safe from.

**One stated pattern does not survive.** `c2-falsification-3x2.md` observes:
*"Every mismatch is on a position whose stored L==H score is ±6."* True of the
twelve; false in general. Four slots (`350` and `355`, both sides — `B.W/B.W`
and `W.B/W.B`) carry a stored value of **0** and are falsified anyway. Any
downstream reasoning that treated "±6" as the signature of C2 failure — a
saturated-bracket heuristic, say — rests on the sample and not on the goban.

This corroborates, from a different direction, the only other surviving 3×2
C2-divergence measurement: `docs/evidence/c2-3x2/B10-minimax.md` found 138
divergences over its 540 L==H rows. B10 asks a different question (it queries
the *start* of a random walk under that walk's ban set, where T13 queries the
*end* of a deterministic descent), so the numbers are not comparable directly —
but both land on "a large fraction of the L==H region", not "a dozen".

**Cost.** 4m37s on 17 worker processes; 29m56s single-process. The parallel
path is a straight split over start positions — every reported quantity is an
aggregate over all pairs, so it cannot depend on the split. Equivalence to the
serial implementation was checked on the **last 79 of the 154 rows**, which is
what survived of the serial run's captured output; those 79 are byte-identical.
The serial reference is retained as `exhaustive-serial` so the remaining 75
rows can be re-checked by anyone willing to spend the half hour.

## 9. Proposed wording (for the claim owner — no register row is edited here)

Per `docs/infra/roles/ORCHESTRATOR.md` §Boundaries, `EVIDENCE-INTEGRITY` holds `CLAIMS.md`
and the Auditor owns claim semantics. This file edits nothing. Recommended:

- **`3x2.T13` — drop the `⚠ CANNOT REPRODUCE` banner.** It is no longer true.
  Replace with: *"Probe source lost (`untracked/c2pilot_3x2.zig`); independently
  re-implemented 2026-07-30 (`docs/evidence/T13/probe-reimplementation-2026-07-30.md`,
  `docs/evidence/T13/t13_probe.py`). All 12 recorded contradiction lines
  re-execute exactly; all census numbers match."* Status stays **PROVEN
  (falsification)**.
- **`3x2.T13` — restate the finding without the fragile "12".** The falsifying
  content is *which slots* fail, not how many (slot, history) pairs one
  traversal happened to sample. Suggested: *"C2 falsified at 3×2: **154 of the
  508 reachable L==H slots (30.3%, over 132 distinct positions) have at least
  one reachable PSK history whose exact value differs from the stored
  fresh-start value** (`docs/evidence/T13/`, 2026-07-30, all reachable
  histories tested; 4,432 falsifying (slot, history) pairs of 134,504). The
  2026-07-26 run sampled one history per slot and recorded 12 of these; that
  count is traversal-dependent and should not be cited as a property of the
  goban. 0/540 fresh-start sanity mismatches."*
- **`c2-falsification-3x2.md` — retract one sentence.** *"Every mismatch is on
  a position whose stored L==H score is ±6"* is true of the twelve and false in
  general (§8: four falsifying slots carry a stored value of 0). It reads as a
  structural observation and is not one.
- **`CLAIMS.md` §7** opens its consequences list with *"**`3x2.T13` is not
  reproducible.**"* That bullet is now wrong and should be rewritten first — it
  is the sentence most likely to be quoted onward. The rest of the list
  (`2x2.B1`/`3x2.B1`/`3x3.B1`, `GLOBAL.UD-1/2/3`) is untouched by this work and
  stands.
- **`QA-022`** (*"load-bearing evidence for T13 … is retrievable" — FALSE*)
  stays **FALSE**. It is a claim about *retrieval*, and nothing was retrieved:
  the probe was rewritten, not recovered. Do not let this file be read as
  overturning it.
- **`docs/evidence/README.md`** — the "T13, specifically" note and the
  `untracked/c2pilot_3x2.zig` row of the lost-file table should point here, and
  the dead `zig build-exe -Mmain=untracked/c2pilot_3x2.zig` reproduction block
  at `c2-falsification-3x2.md:143-146` should be replaced with the Python
  invocation in §10.
- **`docs/infra/dispatch/ADR0006-FALSIFY.md`** — strike T13 from the list of
  ground-truth searches contaminated if ADR-0006 is wrong (§7). The rest of
  that list stands.
- **`GLOBAL.C2`, `GLOBAL.C4`, `4x4.C2`, `GLOBAL.REFRAME`, `GLOBAL.H1`** — no
  status change. Their parent is now reproducible; that removes a risk, it does
  not add evidence.
- **New standing check for every history-sensitivity probe** (`EXP-2B`,
  `PINRULE-SUFFICIENCY`, any 4×4 C2 attempt): *does the arrival-history
  generator apply the ADR-0006 eye-prune?* If it does, it is under-sampling
  reachable histories, and its count — including a zero — is not the
  measurement it appears to be (§6). Cheap to check, and worth a 4-of-12
  shortfall here. **`src/qa023_probe.zig` passes**: `psk_collect_histories_dfs`
  and `psk_exact_value` contain no `is_own_eye`/`benson_alive` call, so the
  QA-023 family is clean on this axis. Anything built on `retro.ab_solve`'s
  move generator is not clean by default, because that one prunes.
- **`2B-5`'s POS acceptance bar is mis-specified**, independently of whether it
  was met. It requires the probe to "reproduce T13-style sensitivity
  (≥12 mismatches)". 12 is a traversal artefact (§6/§8), so a correct probe
  with a different walk order can land below it, and a weak probe can land
  above it. If that calibration is re-run, the bar should be *"finds ≥ K of the
  known falsifying slots"* against the slot list in §8 — a property of the
  goban, checkable per-slot.
- Run `bin/weizigo-claimlint` after every edit — **and read the next paragraph
  first.**

**A trap in the claimlint edit.** Two of the eleven C2 dangling-evidence paths
the linter currently reports are T13's (`untracked/T13-minimax.md`,
`untracked/c2pilot_3x2.zig`), and repointing the `3x2.T13` row at this
directory clears both. But `untracked/c2pilot_3x2.zig` is also claimlint's
**known-bad 2 calibration case** — the live register row is what makes that
check catch anything:

```
known-bad 2 (C2): `untracked/c2pilot_3x2.zig` must be reported … CAUGHT
```

Remove the citation and the calibration silently loses a failing case, which is
precisely what `GLOBAL.CALIB-LESSON` ("a checker with no failing case proves
nothing") exists to prevent. Whoever makes the register edit must repoint
known-bad 2 at another genuinely-dangling path in the same commit, or convert
it to a synthetic fixture like known-bad 3/4. This is the kind of coupling that
turns a documentation fix into a silent regression in the tool that guards the
documentation.

### What this does and does not license

It does **not** re-derive any downstream conclusion, and it is not a second
independent falsification of C2 in the sense that would justify strengthening
`GLOBAL.C2` beyond FALSE-AS-SCOPED at 3×2. It is one thing only: the experiment
behind the project's most load-bearing row can be run again, by anyone, from
files that are in git. The `AGENTS.md` rule this loss produced — *evidence in
git, or the claim is not proven* — is now satisfied for T13 rather than merely
excused.

## 10. Files

All five are in git under `docs/evidence/T13/`:

| file | what it is |
|---|---|
| `t13_probe.py` | the re-implementation — rules port, L/H tables, `ab_solve` port, probe driver, self-tests |
| `zig_t13_replay.zig` | the lost driver, rewritten in Zig against the committed `src/retro.zig` (§5) |
| `zig_dump_3x2.zig` | dumps the Zig 3×2 L/H tables for the port diff (§5) |
| `diff_zig_tables.py` | the port diff itself |
| `probe-reimplementation-2026-07-30.md` | this report |

A sixth file, **`probe-v2-2026-07-30.py`, is not mine** — it is
`Kimi-k2.7/T118`, an independently dispatched second re-implementation of the
same experiment that appeared in this directory while T110 was running (see the
duplicate-dispatch note below). It is not cited as evidence by this report and
its results are T118's to report.

- Claims supported: `3x2.T13`, and by inheritance `GLOBAL.C2`
- Durable predecessor: `docs/research/c2-falsification-3x2.md`
- Lost originals: `untracked/c2pilot_3x2.zig`, `untracked/T13-minimax.md`

### Reproduction

```
python3 docs/evidence/T13/t13_probe.py test         # port self-tests   (<1 s)
python3 docs/evidence/T13/t13_probe.py census       # §3                (<1 s)
python3 docs/evidence/T13/t13_probe.py replay       # §4                (<1 s)
python3 docs/evidence/T13/t13_probe.py adr0006      # §7                (~1 s)
python3 docs/evidence/T13/t13_probe.py sanity       # §3                (~7 s)
python3 docs/evidence/T13/t13_probe.py search       # §6                (~7 s)
python3 docs/evidence/T13/t13_probe.py exhaustive   # §8                (~5 min, parallel)
python3 docs/evidence/T13/t13_probe.py exhaustive-serial   # §8 reference (~30 min)
python3 docs/evidence/T13/t13_probe.py              # all of the above
```

The Zig cross-check of §5 (optional — it needs a compiler, the Python does not):

```
tools/runner -- zig build-exe -O ReleaseFast --dep retro \
  -Mmain=docs/evidence/T13/zig_t13_replay.zig -Mretro=src/retro.zig \
  -femit-bin=/tmp/t13replay && /tmp/t13replay

tools/runner -- zig build-exe -O ReleaseFast --dep retro \
  -Mmain=docs/evidence/T13/zig_dump_3x2.zig -Mretro=src/retro.zig \
  -femit-bin=/tmp/dump3x2
/tmp/dump3x2 2>/tmp/zig-tables.txt
python3 docs/evidence/T13/diff_zig_tables.py /tmp/zig-tables.txt
```

No build step, no dependencies beyond the Python 3 standard library, and
nothing outside this repository. That is deliberate: T13 was lost because its
evidence was a Zig file in a git-ignored directory that had to be compiled
against a moving `src/retro.zig` to say anything. This one is a single
committed script that runs on its own.

## 11. Duplicate dispatch: T110 and T118 were given the same task

`T110` (this file, Opus 5) was registered at **15:55Z** and claimed at 15:55Z.
`T118` (Kimi-k2.7) was registered at **16:23Z** — 28 minutes later — and is an
independent re-implementation of the same experiment. Both were `in_progress`
simultaneously; neither brief mentions the other; both wrote into
`docs/evidence/T13/`. This was discovered only because the second worker's file
appeared in a directory listing.

**For this claim the collision is fortunate rather than wasteful.** `3x2.T13`
is the falsification the whole reframe rests on, and two independent
implementations agreeing is worth more here than almost anywhere else in the
project. From reading `probe-v2-2026-07-30.py`, T118 makes the same two
semantic calls this file argues for — no eye-prune in line generation, eye-prune
in the solver — which is itself corroboration of §6, arrived at separately.

**But the coordination failure is real and is not a T13 problem.** Two workers
spent an afternoon each on one task, on the register's most load-bearing row,
without either being told. Worth checking how both dispatches were issued
before the next parallel wave.

**One practical observation for whoever runs it.** `probe-v2-2026-07-30.py` was
executed here for **62 minutes without completing**, and was then stopped — it
buffers all output to the end, so a killed run yields nothing at all. The cause
is design, not a defect: it enumerates from both root sides (~542k prefixes
against §6's 271k), tests every distinct history rather than one per slot, is
single-process, and caches nothing across queries. Budget an hour-plus, redirect
to a file, and prefer flushing incrementally. For comparison, §8's parallel pass
covers the Black-first half in 4m37s.

**The cross-check is left open, deliberately.** T118's numbers are T118's
deliverable to report, and this file does not preempt them. When both land, the
comparison that matters is not the headline count — T118 enumerates from
**both** root sides and tests every distinct history, where T13 and §6 take one
history per slot from Black-first roots, so the counts *should* differ and a
mismatch there would prove nothing. Compare instead:

1. the census (489 / 30 / 189 / 189 / 540 stored slots),
2. the fresh-start arm (0 mismatches),
3. whether T118's falsifying-slot set is a **superset** of §8's 154 — it
   enumerates a strictly larger population, so anything less is a real
   disagreement worth adjudicating,
4. per-slot values on the twelve recorded lines.

Whoever absorbs both tasks should run that comparison rather than treating the
two reports as interchangeable.
