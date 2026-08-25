# Adjudicating the 62 disputed ko-sensitive slots at 3×2

**Task:** T912 · **Date:** 2026-08-25 · **Model:** claude-opus-5 · **Board:** 3×2 (six points)
**Instrument:** `src/t912_adjudicate.zig` · **Evidence:** `docs/evidence/T912/`

---

## Answer, in one paragraph

The 62 reproduce exactly, against the 3×2 artifact as committed at `807d530` — the audit's
"old" generation. The history-exact solver, which this row was told to use as the judge,
**resolves 0 of them** (and 0 of its own 24-pair null control) after 1.72 × 10⁹ nodes and 330
seconds; that is a measured wall, not a shortfall of effort. The `[L,H]` brackets and the
symmetry battery — the two validators `src/retro.zig:2637` names for this region — pass their
controls and also **resolve 0 of 62**; worse, they accept a generator the project has already
convicted, so their discriminating power here is measurably zero. The instrument that does
adjudicate is the one ADR-0013 already used: the **minimax identity under a fixed root history**.
Pointed at the stored values rather than at a generator, it resolves **62 of 62 in 7 ms**, and it
lands on **writes-off on 62 of 62**. The currently committed `artifacts/oracle-3x2.wzo` already
agrees with a fresh writes-off rebuild on **all 978** (slot, side) values — the 62 were repaired
by the regeneration at `ae39978`. Nothing was found on which both methods are wrong.

---

## 1. Reproduction of the 62

Denominators first. 3×2 has 729 colex slots, **489 legal**, so **978 (slot, side) values**. The
finisher's `FLAG_KO_SENSITIVE` region is **378 pairs** (189 Black-to-move + 189 White-to-move),
exactly the denominator `docs/research/arena-audit.md:182` uses.

| comparison | differing pairs | denominator |
|---|---|---|
| writes-off vs artifact @ `807d530` (the audit's "old") | **62** | 378 ko-sensitive |
| writes-off vs artifact @ `807d530`, whole table | **62** | 978 all legal (slot, side) |
| writes-off vs artifact @ `ae39978` = HEAD | **0** | 378 ko-sensitive |
| writes-off vs artifact @ `ae39978` = HEAD, whole table | **0** | 978 all legal (slot, side) |
| writes-off vs cross-branch memo reuse (`memo_writes = ON`) | **170** | 378 ko-sensitive |
| writes-off vs dependency-guarded reuse (Track B, `deps = ON`) | **0** | 378 ko-sensitive |

Every one of the 62 lies inside the ko-sensitive region (62 of 978 whole-table = 62 of 378
ko-sensitive), so the disagreement is exactly where the audit said it was and nowhere else.

**Which artifact is "old".** `artifacts/oracle-3x2.wzo` has two committed generations:

| commit | SHA-256 of the artifact | role |
|---|---|---|
| `807d530` | `6725b335cd4708f88b59eac2c84eb1a6e0f77a2468cef074797a6d5022e25da1` | the audit's "old" — the 62 are against this |
| `ae39978` | `d4d22c0d9f1d771bfcb1d99fc43a4f19f652205113ff599123b189097b3bb523` | HEAD; matches `artifacts/SHA256SUMS` |

`ae39978` is the commit that also landed `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md`.
The comparison was made against the artifact extracted from git at each commit, not against any
loose copy.

**Reproduction shortfall, stated.** The audit names three methods at the empty goban: old `+1`,
new `−2`, writes-off `0`. Two of the three reproduce exactly — `807d530` stores `+1` for Black at
idx 0 and the writes-off rebuild gives `0`. **The third does not exist in any committed artifact:**
no committed 3×2 `.wzo` carries `−2` at the empty goban. It is reproducible only as a live code
path — `memo_writes = ON` yields exactly `parent = −2, best-option = 0` at idx 0 Black
(`docs/evidence/T912/consist-3x2.txt`), which identifies the audit's "new" with cross-branch memo
reuse. So "new" is reproducible as a generator, not as an artifact.

### The 62, enumerated

`idx` is the colex slot; `pos` reads the six points in colex order. `wo` = writes-off rebuild,
`old` = the `807d530` artifact, `best` = the minimax identity's best option (§5).

| idx | side | pos | wo | old | best | adjudged |
|---|---|---|---|---|---|---|
| 480 | B | `BBBWW.` | 1 | 3 | 1 | writes-off |
| 488 | B | `BBBBW.` | -1 | 0 | -1 | writes-off |
| 488 | W | `BBBBW.` | -1 | 0 | -1 | writes-off |
| 489 | B | `WWWWB.` | 1 | 0 | 1 | writes-off |
| 489 | W | `WWWWB.` | 1 | 0 | 1 | writes-off |
| 497 | W | `WWWBB.` | -1 | -3 | -1 | writes-off |
| 513 | W | `WWWB.W` | -6 | -3 | -6 | writes-off |
| 520 | B | `BBBB.W` | 6 | 3 | 6 | writes-off |
| 521 | W | `WWWW.B` | -6 | -3 | -6 | writes-off |
| 528 | B | `BBBW.B` | 6 | 3 | 6 | writes-off |
| 544 | B | `BBB.WW` | 1 | 3 | 1 | writes-off |
| 545 | B | `WWW.BW` | 1 | 0 | 1 | writes-off |
| 545 | W | `WWW.BW` | 1 | 0 | 1 | writes-off |
| 560 | B | `BBB.WB` | -1 | 0 | -1 | writes-off |
| 560 | W | `BBB.WB` | -1 | 0 | -1 | writes-off |
| 561 | W | `WWW.BB` | -1 | -3 | -1 | writes-off |
| 571 | B | `WB.WWW` | 1 | 0 | 1 | writes-off |
| 571 | W | `WB.WWW` | 1 | 0 | 1 | writes-off |
| 572 | W | `BB.WWW` | -1 | -3 | -1 | writes-off |
| 597 | B | `WW.BBB` | 1 | 3 | 1 | writes-off |
| 598 | B | `BW.BBB` | -1 | 0 | -1 | writes-off |
| 598 | W | `BW.BBB` | -1 | 0 | -1 | writes-off |
| 602 | W | `B.WWWW` | -6 | -3 | -6 | writes-off |
| 603 | W | `W.BWWW` | -6 | -3 | -6 | writes-off |
| 630 | B | `B.WBBB` | 6 | 3 | 6 | writes-off |
| 631 | B | `W.BBBB` | 6 | 3 | 6 | writes-off |
| 634 | B | `.BWWWW` | 1 | 0 | 1 | writes-off |
| 634 | W | `.BWWWW` | 1 | 0 | 1 | writes-off |
| 636 | W | `.BBWWW` | -1 | -3 | -1 | writes-off |
| 661 | B | `.WWBBB` | 1 | 3 | 1 | writes-off |
| 663 | B | `.WBBBB` | -1 | 0 | -1 | writes-off |
| 663 | W | `.WBBBB` | -1 | 0 | -1 | writes-off |
| 240 | W | `BBBW..` | 1 | 3 | 1 | writes-off |
| 241 | B | `WWWB..` | -1 | -3 | -1 | writes-off |
| 288 | B | `B.BBW.` | -1 | 0 | -1 | writes-off |
| 289 | W | `W.WWB.` | 1 | 0 | 1 | writes-off |
| 320 | W | `BBB..W` | 1 | 3 | 1 | writes-off |
| 321 | B | `WWW..B` | -1 | -3 | -1 | writes-off |
| 331 | W | `WB.W.W` | 1 | 0 | 1 | writes-off |
| 342 | B | `BW.B.B` | -1 | 0 | -1 | writes-off |
| 362 | W | `.BWW.W` | 1 | 0 | 1 | writes-off |
| 375 | B | `.WBB.B` | -1 | 0 | -1 | writes-off |
| 397 | W | `W.W.BW` | 1 | 0 | 1 | writes-off |
| 404 | B | `B.B.WB` | -1 | 0 | -1 | writes-off |
| 426 | B | `B..WWW` | -1 | -3 | -1 | writes-off |
| 439 | W | `W..BBB` | 1 | 3 | 1 | writes-off |
| 458 | B | `..BWWW` | -1 | -3 | -1 | writes-off |
| 471 | W | `..WBBB` | 1 | 3 | 1 | writes-off |
| 73 | B | `WWW...` | 1 | 0 | 1 | writes-off |
| 80 | W | `BBB...` | -1 | 0 | -1 | writes-off |
| 89 | B | `W.WW..` | 1 | 0 | 1 | writes-off |
| 96 | W | `B.BB..` | -1 | 0 | -1 | writes-off |
| 161 | B | `W.W..W` | 1 | 0 | 1 | writes-off |
| 168 | W | `B.B..B` | -1 | 0 | -1 | writes-off |
| 177 | B | `W..W.W` | 1 | 0 | 1 | writes-off |
| 184 | W | `B..B.B` | -1 | 0 | -1 | writes-off |
| 193 | B | `..WW.W` | 1 | 0 | 1 | writes-off |
| 200 | W | `..BB.B` | -1 | 0 | -1 | writes-off |
| 225 | B | `...WWW` | 1 | 0 | 1 | writes-off |
| 232 | W | `...BBB` | -1 | 0 | -1 | writes-off |
| 0 | B | `......` | 0 | 1 | 0 | writes-off |
| 0 | W | `......` | 0 | -1 | 0 | writes-off |

By stone count the 62 are: **2** at 0 stones (the empty goban, both sides), **12** at 3 stones,
**16** at 4 stones, **32** at 5 stones. They come in 31 colour-inverted couples, which is what
both tables' internal symmetry (§4) requires.

---

## 2. Status of the committed table today — Track A's premise at 3×2 is already met

A fresh writes-off rebuild and `artifacts/oracle-3x2.wzo` at HEAD agree on **all 978** (slot,
side) values — not merely on the 378 ko-sensitive ones. The artifact's SHA-256 matches the
recorded `artifacts/SHA256SUMS` line. **There is nothing left to regenerate at 3×2.** The 62 are
a historical disagreement between the writes-off generator and a superseded artifact generation,
already repaired in the tree by `ae39978`.

This does not settle 4×4, and it is not an argument that the regeneration was *verified* at the
time — only that the numbers now on disk are the writes-off numbers.

---

## 3. The controls (run before every verdict)

Acceptance item 3 says the null control decides whether the rest of the row means anything, so it
ran first each time. Acceptance item 4 asks for a seeded defect.

| control | instrument | result |
|---|---|---|
| null — brackets, on agreeing pairs | `[L,H]` containment | 0 fires of 316 (both candidates) |
| null — symmetry, on agreeing pairs | dihedral + colour inversion | 0 fires of 316 (both candidates) |
| null — minimax identity, on agreeing pairs | best-option vs agreed value | **316 agree of 316**, 0 disagree |
| null — minimax identity, vs HEAD artifact | best-option over the whole region | **378 agree of 378**, 0 disagree |
| null — history-exact judge, 24 agreeing pairs | `retro.Exact` | **0 resolved of 24** — the judge could not be calibrated at all |
| seeded defect — table comparator | perturb one agreeing slot | diffs 62 → 63, **CAUGHT** |
| seeded defect — bracket check | value pushed one past `H` | **CAUGHT** |
| seeded defect — symmetry check | same perturbation | **CAUGHT** |
| seeded defect — identity check | best-option vs a value that is not it | **CAUGHT** |
| **known-bad generator** — identity check | the convicted `memo_writes = ON` table, on all 170 pairs where it differs from writes-off | **writes-off 170, reuse 0, neither 0** |

The last row is the control that matters most. A synthetic perturbation only proves a comparator
can see a changed number. ADR-0013 already convicted cross-branch memo reuse, so its table is a
*real* seeded defect: the adjudicator lands on writes-off at 170 of 170 and never on reuse.

**The null control also caught a real defect in this row's own instrument.** The first cut of the
identity adjudicator seeded its search context from the *finished* writes-off table, which marks
every ko-sensitive slot as a clean history-free memo entry — the exact reuse under audit. It
reported 52 disagreements of 316 on the null control and a plausible-looking 42/20 split on the
62. Seeding from the certified-only table (`seed`/`converge`/`finalize`, no finisher), as
`retro.zig:2984` does, took the null control to 316 of 316. **Had the null control been run after
the adjudication instead of before it, this row would have shipped a 42/20 verdict that was
entirely an artefact of its own instrument.**

---

## 4. Adjudicator A — the history-exact solver: 0 of 62, and what it cost

`retro.Exact(3,2)` keeps the full positional-superko ban set in the memo key, so it is sound by
construction: no `ko_ref` rule, no eye-prune, no graph-history assumption. It is the judge this
row was told to use. Run over the shared, bounded memo the project's own `groundTruth`
(`retro.zig:1742`) uses:

| phase | pairs attempted | resolved | unresolved |
|---|---|---|---|
| null control (agreeing pairs, deepest first) | 24 | **0** | 24 |
| adjudication (the 62) | 62 | **0** | 62 |

1,720,000,086 nodes, **330 s wall**, 1.74 GB peak resident, memo saturated at its 6 M-entry cap. A
single-root escalation to 400 M nodes on the most tractable disputed pair (idx 480, Black,
`BBBWW.`, 5 stones) also returned UNRESOLVED after 74 s.

**Why it cannot finish, measured rather than asserted.** With the memo left uncapped on that same
root, at doubling node budgets:

| node budget | nodes | distinct ban-set states | resident bytes per node | verdict |
|---|---|---|---|---|
| 1 M | 1,000,001 | 543,560 | 75 | unresolved |
| 2 M | 2,000,001 | 1,083,442 | 74 | unresolved |
| 4 M | 4,000,001 | 2,164,212 | 74 | unresolved |
| 8 M | 8,000,001 | 4,331,620 | 74 | unresolved |
| 16 M | 16,000,001 | 8,659,340 | 74 | unresolved |

0.541 new states per node, **flat to five doublings, with no plateau**. Nearly every path is a
distinct ban set, so the memo barely reuses. Extrapolating the measured 74 bytes/node, the 400 M-node
escalation would need ≈ **29.6 GB** resident — and 400 M nodes did not resolve it either, so that
is a lower bound on a cost whose upper bound is unknown.

**How many of the 62 can the history-exact method resolve? Zero.** This is not new physics: it is
`3x2.EXACT` (Finding 3 — history-exact ground truth completed on 68 of 600 roots at 3×2) read
correctly. The roots that complete are the settled ones; every ko-sensitive slot is by definition
unsettled (`L < H`). Extending the history-exact run at 3×2 was in this row's scope, and the
measurement above is the reason it was not pursued: there is no budget at which it turns over.

---

## 5. Adjudicator B — brackets and symmetry: 0 of 62, and zero discriminating power

`src/retro.zig:2637` states the project's position on this region directly: *"Ko-sensitive region
is NOT spot-checked here: forward search cannot tractably reach it (Finding 3/6) — it is validated
by the `[L,H]` brackets + symmetry instead."* So these are the project's own validators for
exactly these slots, not a substitute invented for this row.

Both pass their controls (§3). Both resolve **0 of 62**:

- **Bracket containment.** Every disputed value, on both sides, sits inside its certified
  `[L, H]`. 0 refutations of 62.
- **Symmetry.** Dihedral and colour-inversion violations over the whole ko-sensitive region:
  **writes-off 0 of 378, `807d530` artifact 0 of 378, memo-reuse 0 of 378, deps 0 of 378.**

**This is the finding that should worry the operator.** Writes-off and cross-branch memo reuse
differ on **170 of 378** pairs, so at most one of them can be right — and brackets plus symmetry
accept *both tables completely*, 0 violations each. The two validators the engine names for the
ko-sensitive region cannot detect a generator ADR-0013 has already proven buggy. Their
discriminating power on this region is not low; on this evidence it is zero. Any claim resting on
"the ko-sensitive region is validated by brackets and symmetry" is resting on a test that has now
been shown to pass a known-bad input.

---

## 6. Adjudicator C — the minimax identity: 62 of 62, in 7 ms

`docs/research/consistency-audit.md` and ADR-0013 convict a generation with the identity, under a
**fixed root history** `H = [P]`:

```
V(P, side, [P])  ==  opt_side( { V(c, -side, [P,c]) : c legal },  pass )
```

Parent, every PSK-legal eye-pruned child, and the pass branch are each solved as an *independent*
root with a freshly re-seeded per-root memo, so the check compares final exact scores rather than
the search's fail-soft internals.

**Reproduced first, unchanged.** `RETRO_CONSIST=1` on the current tree
(`docs/evidence/T912/consist-3x2.txt`):

| variant | checked | violations | verdict |
|---|---|---|---|
| new (`memo_writes = ON`) | 378 | **45** | PROVABLY BUGGY |
| soundish (writes OFF) | 378 | **0** | self-consistent (necessary pass) |
| deps (guarded reuse, Track B) | 378 | **0** | self-consistent (necessary pass) |

**0.35 s wall, 2.8 MB peak.** The published 45/378 and 0/378 reproduce exactly.

**Why that auditor could not answer this row's question, and what was done.** `RETRO_CONSIST`
audits a **generator**: it solves the parent with the variant under test and compares it against
that same variant's children. The generator that produced the 62 disputed values is not in the
repository any more, so it cannot be re-run. This row therefore computes only the identity's
**right-hand side** — the best option, children and pass branch re-solved independently under
`H = [P,c]` by the sound variant — and tests **both** candidate parent values against it. The
implementation calls the public engine API in the same sequence `retro.zig:2845` (`solveNode`) and
`retro.zig:2874` (`seedCtx`) use; `src/retro.zig` is not edited and no engine logic is duplicated.

Result over the 62, after the null control passed 316 of 316:

| verdict | count | of |
|---|---|---|
| writes-off matches the identity, artifact does not | **62** | 62 |
| artifact matches the identity, writes-off does not | **0** | 62 |
| **both violate the identity** | **0** | 62 |
| unresolved | **0** | 62 |

**7 ms** for the 62; **0.31 s / 16.7 MB** for the whole program including both controls.

**The assumption, stated once and not smuggled.** The children and the pass branch are valued by
the sound finisher variant (`memo_writes = false`) reading certified seeds and `[L,H]` brackets
over the real positional-superko history. A refutation therefore says *"this stored value
contradicts the sound solver's independently re-solved children one ply deeper"* — not *"this
stored value is false in the absolute"*. That is precisely the standing the ADR-0013 conviction
already has, applied to a table of numbers instead of to a code path.

---

## 7. What this licenses, and what it does not

**Licensed by the evidence:**

1. **Writes-off is right on 62 of 62 adjudicable pairs.** The `807d530` values are refuted on all
   62; writes-off is refuted on 0.
2. Across the whole region, writes-off equals the independently re-solved best option at **378 of
   378** ko-sensitive pairs.
3. The dependency-guarded (Track B) generator agrees with writes-off at **378 of 378** and at
   **978 of 978**, and is likewise self-consistent at 0 violations of 378.
4. Cross-branch memo reuse is refuted at **45 of 378** by the project's own auditor and at **170 of
   170** of its disagreements by this row's adjudicator.

**Not licensed, and the row will not pretend otherwise:**

1. **No independent oracle resolved a single disputed pair.** The one assumption-free judge —
   `retro.Exact` — returned 0 of 62 and 0 of 24. Everything above is a *necessary* test.
   `consistency-audit.md` says so in terms: a solver can be self-consistent at a wrong fixpoint,
   and the identity never yields the true score.
2. Therefore **"writes-off is the correct generator" remains unproven.** What is established is
   narrower and still useful: *of the candidates that can be tested at 3×2, writes-off is the only
   one not refuted, and the artifact generation it replaced is refuted on every disputed slot.*
3. The identity's right-hand side is computed by the sound variant, so it shares that variant's
   dependence on `[L,H]` bracket validity, certified-seed history-freeness, and eye-prune
   soundness. It is a weaker dependence than trusting the whole writes-off table — the children
   are re-solved one ply deeper, independently — but it is not zero.
4. Nothing here transfers to 4×4 by itself. It removes an objection to Track A; it does not
   discharge the 4×4 tractability question.

**The "both wrong" check ran and found nothing.** Acceptance item 4 asks specifically whether any
pair refutes both methods, which would indict the shared assumptions (`[L,H]` brackets, certified
seeds) beneath them. Four independent opportunities for that verdict were tested and all four
came back empty: 0 pairs with both values out of bracket, 0 with both symmetry-refuted, 0
`BOTH_WRONG` from the history-exact phase (which resolved nothing, so this is vacuous there), and
**0 `BOTH_VIOLATE_IDENTITY` of 62**. On this evidence the brackets and certified seeds are not
implicated at 3×2.

---

## 8. Cost — the comparison that should stop the next worker

The three killed attempts at this row hand-rolled a history-exact solver and a WZO loader in
Python. Attempt 3 reached **7,685 MB resident in 212.7 s** and produced no adjudication.

| approach | wall | peak resident | pairs adjudicated of 62 |
|---|---|---|---|
| hand-rolled Python solver (attempt 3) | 212.7 s | 7,685 MB | 0 |
| existing engine, identity adjudicator | **0.31 s** | **16.7 MB** | **62** |
| existing engine, `RETRO_CONSIST` as-is | 0.35 s | 2.8 MB | n/a (convicts the generator) |
| existing engine, history-exact judge | 330 s | 1,739 MB | 0 |

The history-exact row is the sweep alone. The canonical combined log
(`docs/evidence/T912/adjudication-old-807d530.txt`) peaks at 3,476 MB because it also runs the
uncapped 16 M-node growth probe of §4; the sweep's own bound is the 6 M-entry memo cap.

Roughly **690× faster and 460× less memory**, with the answer instead of without it. The
reproduce-plus-controls stage — rebuild all three generator variants, load the artifact, diff,
bracket, symmetry — costs **12 ms** of generator time.

The honest other half: **the existing tooling does not make the history-exact route cheap.** Zig
buys nothing there. The Exact solver in the engine hits the same wall the Python one did, for the
same structural reason (0.541 new ban-set states per node, no reuse), and it does so at 74 bytes
per node instead of a Python frame. The earlier attempts' error was not the language; it was
choosing an intractable judge and then scaling the machine at it.

**The gap worth naming.** `RETRO_CONSIST` audits generators and cannot be pointed at a `.wzo`.
That is the whole reason a fourth attempt was needed to adjudicate values that the project's own
instrument could have refuted in milliseconds since 2026-07-23. `src/t912_adjudicate.zig` phase
1b-2 is that missing check, written as a one-off row instrument: *load an artifact, take its
stored value as the parent, test it against independently re-solved children.* Promoting it into
the standing battery — so that every committed artifact's ko-sensitive region is identity-checked
at commit time, not argued about in prose — is a recommendation for the operator, not a
conclusion this row may draw.

---

## 9. Reproducing this

```sh
# build the instrument (any scratch output path will do)
zig build-exe -O ReleaseFast src/t912_adjudicate.zig

# the audit's "old" generation, extracted from git — not from any loose copy
WORK=$(mktemp -d)
git show 807d530:artifacts/oracle-3x2.wzo > "$WORK/old-3x2"

# reproduction + all controls + the identity adjudication  (~0.3 s, ~17 MB)
T912_ART="$WORK/old-3x2" T912_BUDGET=1000 T912_NULL_N=0 ./t912_adjudicate

# add the history-exact judge and the growth probe  (~340 s, ~3.5 GB)
T912_ART="$WORK/old-3x2" T912_GROWTH=1 \
  T912_BUDGET=20000000 T912_ENTRIES=6000000 T912_NULL_N=24 ./t912_adjudicate

# the project's own generator auditor, unchanged  (~0.35 s, ~2.8 MB)
zig build-exe -O ReleaseFast src/retro.zig && RETRO_CONSIST=1 ./retro
```

All output is TSV on stderr, tagged in column 1. Logs as run are in `docs/evidence/T912/`.
