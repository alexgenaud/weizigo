# QA-018 seat A — adversarial review of ADR-0017 (the refutation of ADR-0015)

Task: QA-018-REVIEW-A · Role: worker (panel seat A) · Model: GLM-5.2 · Date: 2026-07-29
Seat: A of the three-seat blind panel (`QA-018-REVIEW-PANEL.md`).
Read packet: `QA-018-REVIEW-A.md` → panel protocol → core brief
(`QA-018-REVIEW.md`) → `AGENTS.md`/`DELEGATEE.md`/`dispatch/README.md` →
ADR-0017 → `docs/evidence/QA-018/refutation-attempt-2026-07-29.md` →
`untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md` → ADR-0015 (read
*after* 0017, per the independence rule) → ADR-0010 →
`docs/research/c2-falsification-3x2.md` → `src/retro.zig` + `src/oracle.zig`
(read-only). Seats B/C briefs/deliverables and any message ≥026 were **not**
read (panel protocol §1).

## Headline (one line)

**ADR-0017's "refutation failed" verdict is SOUND; ADR-0015 STANDS.** The
in-family pointwise *strengthening* (Defence 2's repair via T13) is OVERSTATED
only to the extent of the un-re-verifiable eye-prune caveat (QA-022), which
ADR-0017 itself discloses; the core verdict survives that caveat.

## The exemption argument an ADR-0010 defender would need, and why it is unavailable

For Fable to have won Horn B (the search-path family is exempt), the defender
would need a proof of **one** of:

- **(E1) Disjointness.** The set of arrival histories the finisher's search
  presents to a bracket cut is disjoint from the real-game histories that
  falsify the bracket. — **Unavailable.** At an empty-goban root, every
  PSK-legal move sequence from the root is a candidate search path *and* a real
  game line; the two sets coincide. The code confirms the identification:
  `ab_value_from_root` seeds `hist = {root}` (`src/retro.zig:648-649`:
  `hist.reset(); hist.push(pos);`) and `ab_solve` pushes/pops each placement
  (`src/retro.zig:575-577`) while PSK-banning against that same history
  (`src/retro.zig:542-548`). So the arrival history at any interior node is
  exactly `root + search path` with ban set `{root}∪path` — the definition of a
  real game whose first position is the root. This is ADR-0017 Defence 1 and it
  is structural (per ADR-0016 it carries to every goban size).
- **(E2) Holds-on-the-family.** The bracket provably bounds `V(P,h)` for every
  `(P,h)` in the search-path family even though it fails elsewhere — i.e. a
  ban-set-emptiness or window-soundness proof at the cut site. — **Unavailable,
  and now falsified in its testable sub-case.** The cut site
  (`src/retro.zig:464-472`) is an unguarded table lookup: `blo == bhi` returns
  the stored score on **any** visit independent of the window (`:469`); the
  bound returns (`:470-471`) carry `KO_CLEAN` with no ban-relevance or history
  condition of any kind. There is no structural reason cuts avoid the violated
  nodes (ADR-0017 Defence 3), and T13
  (`docs/research/c2-falsification-3x2.md:76-95`) exhibits 12 pointwise
  mismatches — stored `L==H` score vs. history-exact `ab_solve`
  (`memo=false, brackets=false`) under reachable PSK-legal placement lines, 8
  of 12 rooted at index 0 (the empty goban). An `L==H` slot has point bracket
  `[s,s]`, so each mismatch is a node `(P,h)` with `V(P,h) ∉ [lo,hi]` and `h` in
  the search-path family. The restricted claim "brackets hold on the
  search-path family" is therefore not merely undischarged — it is false at 3×2
  for the `L==H` case (the very case the `blo==bhi` cut at `:469` and the
  certified-seed memo read at `:485,:491`/`:487,:493` use).

  *Caveat that bounds this strengthening* (stated honestly by ADR-0017,
  falsifier 2): T13's probe source is lost (`QA-022`); whether each of the 12
  lines respects the **eye-pruned** move generator the finisher actually uses
  (`src/retro.zig:537-540`, `R.is_own_eye`; `src/oracle.zig:230` in the plain
  path) cannot be re-verified without re-running the probe. T13's method
  (`c2-falsification-3x2.md:19-43`) enumerates "PSK-legal placement-only game
  lines" and does **not** record an eye-prune step. On 3×2, Benson-alive walls
  are rare mid-ko-tangle, so eye-pruning likely does not strip most of the 12
  lines — but "likely" is not "verified." I address the consequence below: the
  *verdict* survives this caveat; only the *strengthening*'s force changes.
- **(E3) Bracket re-derivation.** `[L,H]` derived as a ban-set-independent
  bound from the retrograde fixpoint alone, making the premise a theorem. —
  **Unavailable.** ADR-0009's honesty clause (`docs/decisions/0009:*` "The
  honesty clause"; `GLOBAL.ADR0009-HONESTY`) explicitly declines this — "strong
  structural evidence, not a theorem" — naming the exact leak (the achieving
  strategy may need to recreate a position the opponent created, or the seed
  position itself; PSK-banned) that T13 later measured.

No exemption route is open. Horn B fails. ADR-0017's verdict lands.

### Why the verdict survives the T13 eye-prune caveat even if every line violated the eye-pruner

If a re-run of T13 showed all 12 lines violated the eye-pruned generator, the
**in-family pointwise strengthening** (E2's "falsified on the search-path
family") would void — ADR-0017 says so itself (falsifier 2). But the *verdict*
("refutation failed") would not move to Verdict B, because:

1. **Defence 1 stands independent of T13.** The family identification
   (empty-root search path IS a real game line) is structural and code-level;
   it does not depend on any specific T13 line being eye-prune-legal. With the
   scoping defence (E1) dead, ADR-0010's "ANY arrival history" universal
   subsumes the search-path family, and the burden of proving exemption (E2 or
   E3) is on ADR-0010 — and is undischarged.
2. **Defences 3–5 fail independently** (no visit-pattern argument, fail-soft
   does not repair a wrong bound, self-imposed bans do not separate players).
3. **ADR-0015's core is a burden argument, not an E2 measurement.** ADR-0015's
   decision ("the scoping defence fails; the burden is on ADR-0010 and it has
   not been discharged") rests on Defence 1 + the absence of any exemption
   proof. E2/T13 is the *evidence citation* ADR-0015 leans on, and ADR-0017
   Defence 2 corrects that citation (T13 is pointwise; E2 is outcome-level).
   Even with T13's family membership voided, the ruling is "burden
   undischarged" — ADR-0015's original position — which is exactly the verdict
   Horn B must overturn and cannot.

So the caveat downgrades ADR-0017's contribution from "ruling strengthened
(in-family falsified)" to "ruling confirmed (burden still undischarged; E2
corrected from pointwise to outcome)". It does not flip the verdict. This is
the load-bearing reason my headline is SOUND rather than OVERSTATED.

## Per-finding grades (the three findings in message 025)

### Finding 1 — E2 is outcome-level, not pointwise; T13 is the load-bearing in-family pointwise falsification — **SOUND**

The cut's premise is pointwise: at `(P,h)`, `V(P,h) ∈ [lo(P),hi(P)]`. The code
bears this out: the `blo==bhi` return at `src/retro.zig:469` is an exact
return; the bound returns at `:470-471` are fail-soft bounds; none is an
outcome/policy claim. E2 (`docs/status/leak-crisis.md` per the evidence file
§4; register `3x3.E2-RUN1/RUN2`) measured a **policy outcome** — range-aware
self-play (Black maximizes `lo[child]`, White minimizes `hi[child]`) finishing
at −9 against a bracket `[+2,+9]`. A leak of that shape follows from PSK bans
breaking the *chaining* step (no legal child achieves the parent's `lo`)
without any node's pointwise bracket being wrong; the policy player can wander
to −9 with every bracket along the way correct. E2 therefore falsifies the
outcome reading of `GLOBAL.C3`, not the pointwise reading the cut needs. T13's
12 mismatches are pointwise by construction (stored `L==H` score vs.
history-exact `ab_solve` value; an `L==H` slot's bracket is the point
`[s,s]`, so a mismatch is `V(P,h) ∉ [lo,hi]` outright). The claim-semantics
split is correct and is the strongest genuine finding of the attempt. SOUND.

(One scoping nuance, not a demotion: T13 is at **3×2**, E2 at **3×3**. Finding
1's "T13 is the load-bearing in-family pointwise falsification" is load-bearing
*at 3×2*. Per-goban epistemic independence (`AGENTS.md`), the 3×2 pointwise
falsification does not transfer to 3×3 as a measurement; what transfers is the
structural family identification (ADR-0016). The 3×3 pointwise question
remains the open ADR-0015 falsifier 2 — the exhaustive 3×3 cut-site check. I
treat this as an honest scope label, not an overstatement, because ADR-0017
states it.)

### Finding 2 — Brackets-off regen is not sufficient; all modes read CERTCORE-dependent certified seeds — **SOUND** (with a wording caveat)

Verified read-only in `src/retro.zig` and `src/oracle.zig`:

- The certified-seed baseline is built at `src/retro.zig:1006-1015`:
  `base_cb[i] = t.legal[i] and t.vb[i] != UNDEF and t.fb[i] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0`
  (and symmetric `base_cw`). These are exactly the non-settled `L==H` slots.
- Those seeds are copied into the live search context at init
  (`src/retro.zig:1019-1022`: `@memcpy(f.ctx.cb, f.base_cb)` etc.), so every
  `runRoot` — bracketed or plain — starts with `ctx.cb/cw` populated.
- The bracket cut (`src/retro.zig:464-472`) is gated by `if (ctx.brackets)`
  (`:466`). The **memo read is gated separately**, by
  `hashable = ctx.memo and passes == 0` (`:475`). So `brackets = false` alone
  disables only the cut at `:466-472`; it does **not** disable the certified
  seed reuse at `:485`/`:491` (deps off, unconditional) or `:487`/`:493` (deps
  on, `orelse O.fp_zero` → seeds carry the **empty fingerprint** →
  `fpDisjoint(empty, anything) = true` → always reuse). Confirmed:
  `src/retro.zig:486` `const dep = ctx.dep_map.?.get(O.depKey(idx, to_move)) orelse O.fp_zero;`,
  `:487` `if (fpDisjoint(dep, anc_or)) return …`.
- The **plain path** (`bracketed = false` → `O.value_from_root`,
  `src/retro.zig:1096`) is no cleaner: `oracle.zig:228-234` reads
  `ctx.cb[idx]`/`ctx.cw[idx]` and returns `ctx.vb[idx]`/`ctx.vw[idx]` as a memo
  cutoff with **no history check and no `deps`/`fpDisjoint` guard at all** —
  the legacy unconditional-reuse path. So `bracketed = false` reads the seeds
  even more directly.

Net: in every mode (legacy / Track A writes-off / Track B deps), the certified
`L==H` seeds are read as **history-free** cutoffs. Their history-freeness is
`GLOBAL.CERTCORE` (FALSE-AS-SCOPED at 3×2 by the same T13 evidence; `GLOBAL.F3`
already lists `d:GLOBAL.CERTCORE`). A "brackets-off" rebuild
(`bracketed = false`) leaves `ctx.memo = true` (the finisher sets
`ctx.memo = true` at `src/retro.zig:973`/`:1318` regardless of `bracketed`),
so the seed reads fire exactly as in bracketed mode. The only configuration
that escapes the CERTCORE dependency is T13's own: `memo = false, brackets =
false` — and `saveArtifact`'s caller hardcodes `bracketed = true`
(`src/retro.zig:2407`) and the shipped finisher always sets `memo = true`, so
neither switch is on in any shipped artifact. The >5e8-node figure
(`GLOBAL.H5c`) was measured **with seeds on** (the baseline is always built,
`:1006-1015`), so it is a **floor** for a CERTCORE-clean solve; the sound
config costs strictly more. Finding 2 is SOUND: brackets-off regen does not
escape the CERTCORE-dependent seed cutoff, and is therefore not sufficient
for soundness.

**Wording caveat (not a demotion).** Finding 2's phrase "a brackets-off
rebuild does not escape the bracket cut by construction" is imprecise: a
brackets-off rebuild *does* escape the literal bracket cut at `:466-472`. What
it does **not** escape is the **certified-seed memo cutoff** at `:485-493`,
which carries the same `GLOBAL.CERTCORE` history-freeness assumption. The
bracket cut and the seed-memo cut are two distinct mechanisms, and
`brackets = false` toggles only the former. The cited mechanism (empty-fp
clears `fpDisjoint` under deps; seeds reused in every mode) is correct; only
the words "the bracket cut" should read "the certified-seed cutoff (the
`CERTCORE` assumption)." Substance SOUND, phrasing loose.

### Finding 3 — Third-party review, not Opus — **SOUND**

Procedural and correct. Opus issued the D-5 ruling (`ADR-0015`), so Opus
cannot adjudicate a refutation of its own ruling (standard conflict of
interest; the dispatch `QA-018-RULING.md` names this). Fable authored the
refutation attempt (`ADR-0017`), so Fable cannot review its own attempt. The
panel protocol (`QA-018-REVIEW-PANEL.md` §5) bars both, plus the Orchestrator
role-instance, and seats three fresh third parties. I am one such third party
(seat A); I confirm the requirement and that I satisfy it — no Orchestrator
session state, no goban ownership, no prior QA-018 context this session.

## Calibration defences (disclosed, panel protocol §3)

### Defence 6 — MTD self-verification (root convergence certifies no wrong cut influenced the returned value) — **WRONG**

The claim: `ab_value_from_root` (`src/retro.zig:642-655`) runs null-window
probes until `lo == hi`; "if an interior bracket cut returned a wrong value,
successive probes would disagree and the driver would fail to converge — so
root convergence itself certifies that no wrong cut influenced the returned
root value."

This conflates **self-consistency** with **correctness against ground truth**.
The driver's invariant is: the true value `v*` of the (search as defined by
its seeds and cuts) is fixed; each probe asks "v* ≥ mid?"; binary search
converges to `v*`. A wrong interior cut returns a **fixed** wrong value (a
seed is a stored table entry — it does not change between probes; the memo is
shared across probes per the comment at `:637-641` but the *seed* is read from
`ctx.cb/cw`, not the per-root memo). A fixed wrong value yields a fixed wrong
`v*`; the binary search converges to that wrong `v*` cleanly. There is no
probe-to-probe "disagreement" to detect — the wrongness is *consistent*, and
consistency is exactly what convergence certifies.

Concrete instantiation: take T13's `idx=314, side=B, stored=+6,
history-exact=−6` (`c2-falsification-3x2.md:78`). Under the search-path
history `0 2 26 40 110 278 57 154 314`, a probe that reaches `(314,B)` and
takes the `blo==bhi` cut at `src/retro.zig:469` returns `+6` — on every probe,
regardless of `mid`. The driver converges to whatever root value `+6` induces.
It does not fail to converge, and it does not detect that `+6` is wrong for
that history. The MTD driver's convergence is a property of the search's
internal consistency under its (possibly wrong) cutoffs, not a soundness check
on those cutoffs. The exemption fails.

(The deeper MTD/TT literature — GHI through the transposition table — is the
well-known failure mode here: a TT-seeded search can converge to a wrong
value when the seeds are wrong. Defence 6 inverts the literature's direction.)

### Defence 7 — The `bracket_fail` gate (shipped `bracket_fail = 0` certifies cuts were sound) — **WRONG**

The claim: `runRoot` checks each solved root value `v` against that root's own
`[lo0, hi0]` (`src/retro.zig:1122-1124`: `if (v < lo0 or v > hi0) f.st.bracket_fail += 1;`),
shipped generations report `bracket_fail = 0`, and "an unsound interior cut
would push some root value outside its bracket, so the measured zero certifies
the cuts were sound in practice."

The gate is calibrated to the **fresh-start** root bracket: `lo0 = t.lo.b0[i]`,
`hi0 = t.hi.b0[i]` (`:1121-1122`) — the retrograde fresh-start `[L,H]`, which
by construction bounds the **fresh-start** root value. A wrong interior cut, in
the sense at issue, returns a **fresh-start seed** (an `L==H` stored score s).
The minimax of fresh-start seeds along the search yields the **fresh-start
root value**, which is — by definition of the retrograde bracket — inside
`[lo0, hi0]`. So `bracket_fail = 0` is *expected* even when every interior cut
is "wrong" in the history-sensitivity sense, because the wrongness is exactly
the substitution of a fresh-start value where a history-exact value differs,
and the fresh-start value is inside the fresh-start bracket. The gate is
structurally blind to the fresh-start-vs-history disagreement that **is** the
leak.

Equivalently: `bracket_fail` tests `v ∈ [L_root, H_root]` (fresh-start bracket
of the root); the contested premise is `V(P,h) ∈ [L(P), H(P)]` for `h ≠
fresh-start`. These are different predicates. A `bracket_fail = 0` measurement
is consistent with every interior cut being history-wrong, provided the
history-wrong values still lie inside their respective fresh-start brackets —
which they do, because the seeds ARE the fresh-start values. The measured zero
certifies only that root values land inside their fresh-start brackets
(virtually tautological given fresh-start seeds), not that interior cuts are
sound against history-exact values. The exemption fails.

**Note on both defences.** Per panel protocol §3, at least one of {6,7} is a
planted calibration case with a known flaw. I cannot tell which from the
merits — **both** carry genuine, independent flaws (Defence 6: convergence is
self-consistency not correctness; Defence 7: the gate is calibrated to the
fresh-start bracket and so is blind to the fresh-start/history gap). I grade
both WRONG on the merits and flag that I am not blessing a planted flaw by
guessing which was synthetic — both fail without needing the plant.

## Calibration (mandatory — what would move me to Verdict B)

A reviewer with no falsifying case for their own verdict is doing theatre
(`GLOBAL.CALIB-LESSON`). The evidence that would move me to **Verdict B — Fable
missed an exemption** is:

1. **A clean exhaustive 3×3 cut-site check (ADR-0015 falsifier 2).** Log every
   bracket cut the eye-pruned finisher takes over all 622 ko-sensitive orbit
   representatives at 3×3, compare each cut's returned value against the
   history-exact value at that node under its real (search-path) arrival
   history, and find **zero mismatches**. That is positive evidence that no
   *fired* cut on the *eye-pruned* search-path family is violated — the
   narrowed form of ADR-0017's falsifier 1. It would not prove the universal,
   but it would be the first real evidence for the exemption at the goban where
   `C3` is false, and would weaken ADR-0015 from "burden undischarged" toward
   "exemption holds in practice at 3×3." (Today: not run. The 0.625% E2 leak
   rate means a *sample* is not enough — the denominator must be all cut
   sites.)
2. **A T13 re-run with eye-pruning enforced** showing the 12 mismatches
   vanish (the lines were eye-prune-violating), **combined** with #1. This
   would void ADR-0017's in-family strengthening (Defence 2's repair) and
   convert the 3×2 in-family pointwise evidence into a non-result, leaving
   ADR-0015 with only the outcome-level E2 and the burden argument. With #1
   also clean, the case for Verdict B would be live.
3. **A bracket re-derivation from the retrograde fixpoint alone (ADR-0015
   falsifier 3)** proving `[L,H]` bounds `V(P,h)` for arbitrary ban sets —
   making the premise a theorem and ADR-0015 wrong outright. ADR-0009 declines
   this; if someone wrote the proof, I would reverse immediately.

The strongest of these is #1+#2 together. Neither exists today; the only
relevant measurement (T13) cuts the *wrong* way for the defender. So I stay at
Verdict A — but I hold #1 as the single most decisive next experiment, and I
note that ADR-0017 itself names it (falsifier 1 collapsed into falsifier 2).

## What I could not establish

- Whether each of T13's 12 histories respects the eye-pruned generator
  (`QA-022` — probe source lost). I reasoned that eye-pruning on 3×2 likely
  does not strip most ko-tangle lines (Benson-alive walls are rare mid-ko), but
  "likely" is not "verified," and a T13 re-run (~200 ms, per
  `c2-falsification-3x2.md`) is the only thing that settles it. This is the
  single biggest soft spot in ADR-0017's *strengthening*, and ADR-0017 says so.
- That no shipped 4×4 value is wrong. ADR-0017 and ADR-0015 are both explicit
  that nothing here shows any shipped value *is* wrong; `4x4.C3`-pointwise
  remains UNTESTED at 3×3/4×4. My verdict is about the *justification* and the
  *refutation attempt*, not about any 4×4 number, and it does not transfer
  (`AGENTS.md` per-goban epistemic independence).
- That the MTD driver and `bracket_fail` gate are the *only* structural
  certifications available; the panel protocol presented exactly these two as
  the calibration set, and I adjudicated both.

## Suggested register notes (owners', not mine)

- `GLOBAL.ADR0015-BURDEN`: ADR-0017's suggestion to add `e:3x2.T13` is sound
  *with the eye-prune caveat attached* — the edge should read
  `e:3x2.T13 (in-family pointwise; eye-prune adherence unverified, QA-022)`.
- The `C3-VALUE` / `C3-PLAY` split is well-motivated by the claim-semantics
  finding; `C3-VALUE` should carry the explicit scope "FALSE-AS-SCOPED at 3×2
  on `L==H` via `3x2.T13` (family membership contingent on the eye-prune
  re-run); UNTESTED at 3×3/4×4."
- `GLOBAL.ADR0017-REFUTE` (CLAIMED): the refutation attempt failed; verdict
  SOUND subject to the eye-prune caveat voiding only the strengthening, not
  the verdict.

## Run stats (panel protocol §4)

- Model: GLM-5.2 (fresh worker console, not the Orchestrator instance).
- Console: pi coding agent, single session, started 2026-07-29 ~04:5x UTC.
- Wall-clock: ~12 min (packet read + code verification + write).
- Cost: not tracked by this harness.
- Context consumed: rough — packet (~7 files, ~30 KB) + `src/retro.zig`
  excerpts (~600 lines across reads) + `src/oracle.zig` excerpt + evidence
  README; comfortably under the working context; nothing in the packet did
  not fit.
- Reads beyond the brief's read order: `docs/evidence/README.md` (for the
  PROVENANCE convention and the T13-loss record), `docs/decisions/0009*`
  (honesty clause, an ADR-0017 attack surface), and `docs/decisions/0016*`
  (filename only, to confirm existence). No seat B/C deliverable, no
  message ≥026, no `tasks.json`, no engine-file edit.

— Seat A (GLM-5.2), 2026-07-29