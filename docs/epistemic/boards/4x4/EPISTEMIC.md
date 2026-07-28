# 4×4 epistemic tree — what we know, honestly

**Read this first for 4×4.** Status is *at 4×4* unless explicitly tagged
`INHERITED-*`. Inherited facts are flagged because the project forbids
silent inheritance: smaller-board proof does **not** constitute a 4×4
proof. See `boards/CONCEPTS.md` for definitions (incl.
`C2-bounded` vs `C2-general`).

Status: ✅ proven · ⬜ untested · 🟡 in progress · ❌ falsified · ⛔ intractable ·
⬜ᴵᴺᴴ inherited (not re-reproven at 4×4)

This file was rewritten on 2026-07-26 (GLM-5.2, task T16) to address the eight
critical findings of `untracked/T07-audit-hypotheses.md`. Each fix is tagged
`[T07-N]` so a fresh auditor can verify the changes.

## Truths (proven at 4×4)
- **S1** ✅ colex bijection (exhaustive round-trip through 4×4).
- **S3a** ✅ move/capture/suicide kernel (24,318,165 legal = OEIS A094777;
  cross-validated). `[T07-1]` This sub-claim is what the OEIS count actually
  attests: it covers the move-generation, capture, and suicide rules; it does
  **not** cover ko-legality under history, which is a separate sub-claim.
- **R1** ✅ PSK intractable (structural; measured at 2×2).
- **R3** ❌ kill-X% falsified (makes ko-sensitive region WORSE: 21.32% → 25.01%,
  both over **all 48,636,330 legal (position, side) slots** — the census
  denominator, not the chainability sweep's non-settled one).
- **P1** ❌ anchor ≠ real-game correctness (structural).
- **P3** ❌ fresh-start player is history-blind (the leak).
- **C4** ❌ fresh-start ≠ real-game for ko-sensitive (structural).
- **F1** ❌ writes-on finisher unsound (ko_ref guard; ADR-0013 — 3×2 fact,
  not yet re-confirmed at 4×4, but the guard is the same code).

### Inherited-but-not-reproven at 4×4 `[T07-2]` `[T07-3]`
- **S4** ⬜ᴵᴺᴴ area scoring — currently inherited from S3's smaller-board
  validation, **not re-reproven at 4×4.** Honest options: (i) downgrade to
  `⬜ᴵᴺᴴ` (this file's choice), or (ii) add a falsifiable 4×4 test (a small
  hand-picked 4×4 position battery replayed against a reference area scorer).
  **TODO:** pick one before shipping the 4×4 deliverable (blocked on UD-2).
  The current "✅ part of S3" wording in the prior revision conflated S3a
  (kernel) with S4 (scoring) and was removed.
- **FP3** ⬜ᴵᴺᴴ finite-sweep convergence **(the theorem)** — the lattice
  argument that the Bellman iteration terminates in finitely many sweeps is
  structural and inherits from the monotone-map-on-finite-lattice proof; it
  has **not been re-derived as a 4×4-specific claim.** The measurement "19
  sweeps at 4×4" is **not** the theorem — it is **M2** (see Measured facts).
  `[T07-3]`

## Falsifications (dead-ends, recorded to not repeat)
- **C2 at 3×2** — falsified at 3×2 by T13 (2026-07-26; 12 mismatches on 508 non-trivial PSK histories on L==H positions). 4×4 falsification is analogy-expected, **not an open hypothesis**. The deliverable decision is settled: fresh-start score table + CLAIMED `[L,H]` bracket.
- **R3** kill-X% at 4×4: full census, 4 thresholds (0/50/40/30%), all worse.
  How we know: RETRO_KILLCENSUS, full 4×4 build per row.
- **F1** ko_ref >= d guard: 45/378 violations at 3×2 with writes ON; 0 OFF.
  How we know: #2 auditor (RETRO_CONSIST), ADR-0013. The guard is the same
  code at 4×4; the 4×4 auditor sample did not finish — but the bug is
  structural, not size-dependent.
- **P3** fresh-start player leaks 8-16% of games (even on proven-correct
  2×2/3×2 tables). How we know: arena audit, 300+ games per persona.
- **C3 at 3×3** — falsified at 3×3; **analogy-expected falsified at 4×4**
  (NOT an open hypothesis). `[T07-5]` E2 range-aware self-play leaked 25/4000
  games on 3×3 (promise +3, final -9). B1 confirmed lo=2 is the true least
  fixpoint → the fixpoint itself doesn't bound real PSK scores. Kimi audit
  convicted the (a′) multi-fixpoint conclusion as unsound. The 3×3 result is
  **method-validated** (E2's design catches a real leak), so the 4×4 result
  is analogy-expected to be the same kind of failure (PSK removes moves; lo
  only pessimises cycles — different semantics from real-game bounds). The
  **deliverable decision must not wait for a 4×4 E2 run**; the 4×4 C3 result
  is a *scaling data point*, not the falsifier. If a 4×4 run is performed
  (T19, low priority), it is to characterise the leak magnitude, not to
  decide the deliverable.

## Hypotheses (open, with falsifiable experiments designed)
- **FP1** ⬜ L is least, H is greatest fixpoint of the Bellman map at 4×4.
  `[T07-4]` Experiment: **B1-4×4 (three-check acceptance)**:
  1. **Seed check** — confirm `converge` was seeded from `-N` (the lattice
     bottom) for the L table and from `+N` (the lattice top) for the H table,
     using the existing build logs.
  2. **Zero-change check** — confirm the final L-sweep and H-sweep each hit
     zero change (termination; the on-disk artifact's last-sweep delta is 0).
  3. **V0/V1 Bellman check** — at every non-settled `(i, side)` and at every
     `(i, side, passes=1)` node, the canonical `lo`/`hi` satisfy the V0 and V1
     Bellman identities.
     **DONE for the shipped single-value columns — and as of 2026-07-28
     EXHAUSTIVELY at 4×4 (M4): PASS** — zero violations outside the
     ko-sensitive region on the committed artifact, across **all 48,599,962
     non-settled (position, side) slots** (the 2026-07-27 result was a 1:37
     sample and is superseded); exhaustive at 4×3 and below.
     `bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --examples 0`.
     **Scope caveat, do not overread — unchanged by the exhaustive run:** this
     checked the *shipped `vb`/`vw` columns*, not the separate `lo`/`hi`
     bracket tables — the artifact format (ADR-0011) carries no bracket
     columns, so the literal `lo`/`hi` form of this check still needs the
     in-memory tables and remains ⬜. "Exhaustive" upgrades the coverage of the
     `vb`/`vw` form only; it does not touch the bracket form.
     Within the ko-sensitive region violations are expected and
     found (each slot is an independent fresh-start solve), so this check
     constrains only the single-score region.
  Acceptance: all three pass. **Any single violation ⇒ FP1 falsified ⇒ STOP.**
  **Dropped from the prior revision:** the re-converge-from-`+N` / `-N+1`
  zero-change check. Per Kimi's T02 audit and T07 finding #1, that check is
  a *multi-fixpointedness observation*, not a least-ness witness — by
  Knaster-Tarski, iteration-from-bottom yielding a fixpoint that satisfies
  V0/V1 *is* the least-ness proof; iteration-from-top is expected to land at
  a different (greater) fixpoint when the map is multi-fixpointed. The
  re-converge observation is still interesting and lives under F2/F3 if
  useful, but it is **not** part of FP1 acceptance.
- **C2/FP2** ❌ **C2-bounded falsified at 3×2** (T13, 2026-07-26; 12 mismatches on 508 non-trivial PSK histories). 4×4 falsification is analogy-expected, not blocking — any 4×4 C2-probe (T19) is **characterisation**, not decision. The honest deliverable does not rest on C2-bounded. `[T07-1, T07-7]` Experiment: **C2-probe-4×4** (exact solver
  at deep L==H positions, varied ban sets). **Design must specify:** (i)
  sample size; (ii) ban-set distribution (must include prefixes that are
  themselves L==H positions so "L==H reached from L==H" is covered, plus
  long-history ban sets simulating many prior captures per the user's "any
  history could be long" worry); (iii) a depth distribution that reaches past
  the near-terminal / Benson-dominated layers. Acceptance: zero
  contradictions on the sampled set, with a stated power argument. A
  *failure to find* a contradiction bounds the disagreement probability; it
  does **not** establish C2-general. If intractable at 4×4, the certified
  core remains conditional on the unproven FP2 honesty clause (ADR-0009).
  **C2-probe-2×2 and C2-probe-3×2 must run first** as design calibration
  (Wave 1); the 4×4 design is calibrated from their results.
- **F3** ⬜ writes-off (`memo_writes=false`) finisher self-consistent at 4×4
  (sampled). `[T07-6]` Experiment: bounded #2 auditor, deepest-first **or
  stratified-by-layer** sample (deepest-N alone is 0.004% of ko-sensitive
  region; a stratified sample with a power argument is preferred — T07
  §4(a)). **Pre-condition:** the artifact must be **regenerated with
  `memo_writes=false`** first. Running the auditor on the *committed*
  `data/oracle-4x4.wzo` is a **falsification test for the committed
  artifact** (which uses the unsound `ko_ref >= d` guard), **not** a
  validation of writes-off at 4×4. These two claims must not be conflated.
  A bracket-containment check (every finisher output lies in `[lo,hi]`)
  should run alongside — it is a cheap necessary condition.
  **See M6 / M7 (updated 2026-07-28):** a writes-off 4×4 artifact exists
  (`untracked/oracle-4x4-writesoff-checkpoint.wzo`, uncommitted) and its
  chainability sweep is cheap *corroborating* evidence (4.08% → 1.67%
  ko-sensitive misprice, **both stride-37 sampled, denominator = the sampled
  ko-sensitive slots**; **≥1.63× worst case**) — but that artifact is
  **confirmed INCOMPLETE** (M7: root slot UNDEF), so it is a corroborating
  signal only and does **not** discharge F3. F3 needs the auditor **and** a
  **completed** writes-off regen; the incomplete checkpoint cannot serve as the
  regen this hypothesis is pre-conditioned on.
- **F2** ⬜ bracket-guided finisher (ADR-0010) sound at 4×4. `[T07-6]`
  Experiment: auditor + bracket containment on a **writes-off regenerated
  artifact** (same artifact as F3; the two share a regen run). **Same
  pre-condition as F3:** the committed artifact is the wrong path and
  cannot validate F2. **See M6 / M7 (updated 2026-07-28)** for the same cheap
  corroborating evidence on the writes-off checkpoint — which is **uncommitted
  and confirmed INCOMPLETE** (M7: root slot UNDEF). A **completed** writes-off
  regen is a named blocker for F2 as well as F3.

## Unknowns (no experiment yet, or intractable)
- **S3b** ⬜ ko-legality under history at 4×4. `[T07-1]` OEIS A094777 does
  not attest ko-legality; it attests the move/capture/suicide kernel (S3a).
  Ko-legality under PSK is the load-bearing sub-claim that separates a
  "legal position count" from a "legal (position, history) pair count" and
  is the structural reason R1 holds. No 4×4-specific ko-legality
  falsification test is designed yet.
- **C1** ⬜ fresh-start scores correct at 4×4 — no exhaustive ground truth
  (exact solver intractable at 4×4 from empty). Only anchors + symmetry +
  spot checks. Status: SUPPORTED, not PROVEN. `[T07-Should]` C1-4×4 should
  be **folded into the C2-probe harness**: for each sampled L==H position,
  the exact solver with empty history returns the fresh-start score;
  compare to `lo[i,side]` (= `hi[i,side]`). This is essentially free once the
  C2-probe harness exists and is much stronger than anchors + symmetry.
- **C2-general** ⛔(possibly) — the unbounded-history version of C2 (any
  past or future repetition could change the score). `[T07-7, T07-10]`
  Distinct from **C2-bounded** (above). The user's "any previous or future
  position could repeat, on a large enough board" worry is a *structural*
  claim about the table's information content: the table has no
  representation of the future and cannot, in principle, rule out a future
  cycle changing the score. The honest framing is **C2-general is possibly
  unprovable by finite methods.** The 4×4 deliverable attacks **C2-bounded**
  first; C2-general is a separate research question and does **not** block
  the deliverable (per user direction 2026-07-26).
- **S2** ⬜ Benson-alive implementation correct at 4×4 — **NOT a
  theorem check, an implementation regression test.** `[T07-7]` The Benson
  *theorem* is board-structure and inherits; the 4×4 question is whether
  the `rules.zig` implementation regresses in a size-dependent way (e.g. an
  uninitialized size-dependent array). The 3×3 exhaustive adversarial
  falsification validated the implementation at 3×3, not at 4×4. Experiment:
  exhaustive adversarial falsification at 4×4 (a `zig test` extension) plus a
  hand-picked unit-test battery (corner Benson-alive, edge Benson-alive,
  two-eyes, dead shape, seki-like). Independent of the retrograde artifact;
  can run in Wave 0.
- **F4** ⬜ KM dependency-guarded memo at 4×4 — validated at 3×2/3×3/4×3
  only. `[T07-8]` Experiment: KM-regen at 4×4, **byte-compare to the
  writes-off regen** (F2/F3), auditor + bracket containment on the KM
  regen. Acceptance: byte-identical writes (modulo deterministic
  tie-breaking) AND zero auditor violations AND bracket containment. The
  KM regen and the writes-off regen **cannot run in parallel** (same disk
  pipeline; AGENTS.md no-silent-write rule) → F4 is serial after F2+F3.
- **D3** ⬜ writes-off 4×4 tractability. `[T07-9]` **A measurement, not a
  truth claim.** Prior 400-node auditor sample didn't finish in ~14 min —
  but that measured the *auditor*, not the *retrograde build*. Experiment:
  full `converge` + `finalize` with `memo_writes=false` at 4×4; **target
  wall ≤ 8 h, memory ≤ 32 GB** (or whatever the dev machine sustains — TODO
  confirm with user). **Cheap proxy first:** a D3-4×3 pilot (full writes-off
  on 4×3, ~75× smaller) extrapolates a 4×4 floor; a single-sweep 4×4 run
  (`RETRO_ONE_SWEEP=1`) gives a per-sweep wall-time unit × 19. D3 is the
  unblocker for F2/F3/F4.

## Measured facts (data, not knowledge)
- **M1** ko-sensitive region = 10,367,922 / 48,636,330 = **21.32%** — the
  converge census, denominator = **all legal (position, side) slots**. Compare
  M4's 21.33%, which is the same numerator over the **non-settled** slots only;
  see the denominator reconciliation in M4.
- **M4** (2026-07-27; **re-run EXHAUSTIVELY 2026-07-28**) **chainability**: the
  single-score (L==H) region satisfies the history-free Bellman identity with
  **ZERO** violations; every violation found carries the KO_SENSITIVE flag
  (at 4×4 **422,990/422,990 exhaustively**, superseding the 11,402/11,402 of the
  1:37 colex sample; 6,092/6,092 exhaustive at 4×3; likewise 2×2/3×2/3×3). This
  is **FP1 acceptance check 3, and it PASSES exhaustively** on the committed
  artifact for the shipped `vb`/`vw` columns — see the FP1 entry above,
  including the still-untested `lo`/`hi` bracket form. Within the ko-sensitive
  region the misprice rate is 422,990 / 10,367,922 = **4.08%** and the max gap
  is **32 points = 2n, the full board swing**. Ko-sensitive violations are
  *expected* (each such slot is an independent fresh-start solve; C2 restated
  per-slot), not a generation bug.

  **Denominator reconciliation (2026-07-28) — resolves the 4×4 row of `CLAIMS.md`
  discrepancy D7.** Three 4×4 ko-sensitive percentages circulate; all three are
  arithmetically correct and differ only in denominator. The numerator is shared
  by the first two (the sweep finds the census's 10,367,922 flagged slots over
  36,368 fewer slots — implying, as an inference across two instruments rather
  than a separate measurement, that **no settled slot is KO_SENSITIVE-flagged**;
  a direct settled-slot flag count was not run):

  | figure | numerator / denominator | denominator is |
  |---|---|---|
  | **21.32%** (M1) | 10,367,922 / 48,636,330 = 21.3172% | **all legal** (position, side) slots |
  | **21.33%** (this sweep) | 10,367,922 / 48,599,962 = 21.3332% | **non-settled** slots only — the sweep exempts settled positions, where `V0 = area_score` by definition and the Bellman identity does not apply |
  | **21.27%** (superseded) | 279,323 / 1,313,248 = 21.2696% | the 1:37 colex **sample** estimate of the same quantity as 21.33% |

  48,636,330 − 48,599,962 = **36,368 = 18,184 settled positions × 2 sides**.
  The 21.27% is retained as history, not deleted: sample 21.27% vs exhaustive
  21.33% (0.06 pp), and sample within-flag 4.08% vs exhaustive 4.08%, is direct
  evidence the 1:37 sampling was sound. **Scope: the 4×4 row of D7 only.** The
  2×2/3×2/3×3/4×3 rows of D7 are **unreconciled**; the settled-exemption cause
  is *likely* the same there but has **NOT been checked**, and per-board
  independence forbids assuming it.

  How we know: `bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo
  --examples 0` (exhaustive, 87 s, re-run and output-matched 2026-07-28); the
  superseded sample was the same tool with `--sample 37`.
  Durable record: `../../../research/ko-sensitive-chainability.md`.
- **M5** (2026-07-27) the empty 4×4 board is itself KO_SENSITIVE (bracket
  [−6, +16]), and **16 of 19 plies** in both saved regression games are
  KO_SENSITIVE-flagged. On 4×4 the GTP player does not *enter* the unchainable
  region when a ko appears — it starts there. Meanwhile positional-superko bans
  changed the best available value at **0 of 19 plies** in those games: the ko
  *rule* costs the engine nothing; chaining unchainable values costs it the
  game. See `../../../research/ko-sensitive-chainability.md`.
- **M6** (2026-07-27) **sound-vs-unsound discriminator, artifact-only**: the
  ko-sensitive misprice rate of M4 **halves** when the artifact is regenerated
  with `memo_writes=false` (ADR-0013 Track A). Same tool, same flags, same
  stride. **Denominators: this table is stride-37 SAMPLED on both rows**
  (percentages over the sampled non-settled slots in the `slots checked`
  column; misprice rate over the ko-sensitive subset of those). It stays
  sampled on purpose — it is a like-for-like writes-on/writes-off comparison,
  so M4's exhaustive 21.33% / 4.08% must **not** be substituted into it. No
  exhaustive sweep of the writes-off artifact exists.

  | artifact | slots checked (stride 37) | ko-sensitive % of sampled checked | misprice rate *within* sampled ko-sensitive | max gap | violations *outside* |
  |---|---|---|---|---|---|
  | `data/oracle-4x4.checkpoint.wzo` (writes ON, committed) | 1,313,248 | 21.27% | **4.08%** | 32 | **0** |
  | `untracked/oracle-4x4-writesoff-checkpoint.wzo` (writes OFF) | 1,310,854 | 21.13% | **1.67%** | 32 | **0** |

  The writes-ON row's sampled 4.08% is corroborated by M4's exhaustive sweep of
  the same artifact (422,990 / 10,367,922 = 4.08% over *all* non-settled
  ko-sensitive slots, 2026-07-28). The writes-OFF 1.67% has no exhaustive
  counterpart.

  Confirmed at a second coprime stride (`--sample 997`): writes ON 24,433
  sampled / 24,413 legal non-settled / 20 settled / 48,786 slots / **397**
  violations (3.81% within-flag); writes OFF 24,423 / 24,403 / 20 / 48,699 /
  **152** (1.47%). Both headers declare 24,318,165 legal/side. Ratio 2.44× at
  stride 37, 2.59× at stride 997.
  Two readings, tagged separately:
  (i) **PROVEN at 4×4 on the swept artifact** — the definitional **floor is
  nonzero**. Writes-off still shows 1.67%, and must: each ko-sensitive slot is
  an independent fresh-start PSK solve owing its parent no agreement across a
  history-free edge. **0% is not the target value for a correct artifact.**
  (ii) **CLAIMED, not proven** — the committed artifact's ≈2.4× excess over that
  floor is the ADR-0013 `ko_ref >= d` GHI bug, showing up in exactly the region
  the ADR predicts (all excess inside the flag; **0** outside on both artifacts,
  both strides). Upgrading this to PROVEN requires the **#2 auditor
  (`RETRO_CONSIST`)** — the standing gate per AGENTS.md; **this sweep is not a
  substitute for it.**
  Practical value: a **cheap discriminator between sound and unsound generation
  from the artifact alone** — seconds of CPU, no retrograde rebuild, no auditor
  run, no reference solver. New capability for Track A validation; a screen, not
  a gate.
  **Update 2026-07-28 — the writes-off run is CONFIRMED INCOMPLETE.** Direct
  byte read of the empty-board root slot (colex index 0; `vb` at byte offset 32
  of the WZO1 payload — 32-byte header, then `vb`/`vw`/`fb` columns of `3^16 =
  43,046,721` bytes each):

  | artifact | `vb[empty]` | `vw[empty]` | `fb` bit0 (KO_SENSITIVE) |
  |---|---|---|---|
  | `data/oracle-4x4.checkpoint.wzo` | **+2** | −2 | 1 |
  | `data/oracle-4x4-parallel.checkpoint.wzo` | **−128 (UNDEF)** | −128 | 1 |
  | `untracked/oracle-4x4-writesoff-checkpoint.wzo` | **−128 (UNDEF)** | −128 | 1 |

  The Track A writes-off artifact's root is unsolved: the run did not finish.
  The prior caveat "completion is an open verification item" is therefore
  **answered — incomplete**, and is retained in that corrected form. See **M7**.

  **Survivorship confound, and the worst-case bound that survives it.** Because
  the writes-off artifact is incomplete and retrograde solves deep ko tangles
  last, its missing slots are exactly the hard — plausibly most-mispriced —
  ones. Excluding them can only bias its misprice rate **downward**, so the
  comparison is not like-for-like. It is nonetheless boundable. At stride 37:
  writes ON checked 1,313,248 slots / 279,323 ko-sensitive / 11,402 violations
  = 4.08%; writes OFF checked 1,310,854 / 276,929 / 4,618 = 1.67%; writes-off
  is missing **2,394 slots (0.18%)**. Charging every missing slot to writes-off
  as a violation:

      (4,618 + 2,394) / (276,929 + 2,394) = 7,012 / 279,323 = 2.51%

  **PROVEN (4×4, stride 37):** 2.51% < 4.08% — the ratio falls from 2.44× to
  **1.63×** but does **not invert**. So the *direction* of reading (ii) is
  robust to the confound; the *magnitude* is an over-estimate of unknown degree,
  true ratio in **[1.63×, 2.44×]**. Reading (ii) stays **CLAIMED** as to *cause*
  (the ADR-0013 bug) with a **proven lower bound of 1.63×** on the *effect*;
  `RETRO_CONSIST` remains the upgrade path, and a **completed writes-off regen**
  is now a named prerequisite.
  Remaining caveats: the writes-off artifact is **uncommitted, in `untracked/`**,
  and is not promoted to `data/`/`artifacts/`; **this M6 comparison is sampled**
  at 4×4 (1:37, 1:997), not exhaustive — M4's single-artifact 4×4 sweep became
  exhaustive on 2026-07-28 but the writes-off artifact has never been swept
  exhaustively, so the comparison is still a sample; and per-board independence
  forbids carrying the ratio to any other size — it is a 4×4 measurement only.
  How we know: `bin/weizigo-chainability <artifact> --sample 37 --examples 0`
  and `--sample 997 --examples 0`, all four runs re-reproduced 2026-07-27; the
  root-slot bytes read directly 2026-07-28.
  Durable record: `../../../research/ko-sensitive-chainability.md` (Measurement 4).
- **M7** (2026-07-28) **empty-board root slot across the three 4×4 artifacts.**
  Direct byte inspection, no engine: the WZO1 payload is a 32-byte header then
  the `vb`, `vw`, `fb` columns of `3^16 = 43,046,721` bytes each; the empty
  board is colex index 0, so `vb[empty]` is at offset 32, `vw[empty]` at
  32 + 3^16, `fb[empty]` at 32 + 2·3^16.

  | artifact | `vb[empty]` | `vw[empty]` | `fb` bit0 (KO_SENSITIVE) |
  |---|---|---|---|
  | `data/oracle-4x4.checkpoint.wzo` | **+2** | −2 | 1 |
  | `data/oracle-4x4-parallel.checkpoint.wzo` | **−128 (UNDEF)** | −128 | 1 |
  | `untracked/oracle-4x4-writesoff-checkpoint.wzo` | **−128 (UNDEF)** | −128 | 1 |

  All three files are 258,280,358 bytes. **PROVEN (2026-07-28, byte read):**
  two of the three 4×4 artifacts have an **unfilled root** and therefore state
  no 4×4 answer at all. Only `data/oracle-4x4.checkpoint.wzo` carries the
  published **+2** anchor, and it is the writes-ON (ADR-0013-unsound) artifact.
  Consequence for M6/F2/F3: the Track A writes-off run **did not finish**.
  **Methodological observation** (tagged as such, not a measurement): the
  "99.8% complete / 83K unfilled" phrasing used elsewhere for
  `oracle-4x4-parallel` measures the wrong thing when the missing slot is the
  root — percentage-filled is not a fitness-for-purpose metric. Fitness is
  "does the root, and every slot the deliverable quotes, hold a defined value."
  How we know: byte read at the three offsets above, 2026-07-28; reproduction
  command in `../../../research/ko-sensitive-chainability.md` (Reproduce).
- **M2** 19 sweeps at 4×4. `[T07-3]` (This is the measurement; the theorem is
  FP3 above.)
- **M3** 649,517 ko-sensitive reps; finisher 6.1 min; ~1,663 nodes/rep avg.
- Empty 4×4 bracket: [-6, +16] (22 wide out of 32). Anchor +2 in-bracket.
- Fresh-start single-score region: 38,268,408 / 48,636,330 = 78.68% — the
  exact complement of M1, so the denominator is **all legal (position, side)
  slots** (the census denominator, not the sweep's non-settled one).

> **T13 update (2026-07-26):** C2-bounded was **falsified at 3×2** by the
> C2-probe (12 mismatches on 508 non-trivial histories). The "Core-only"
> deliverable below is therefore **refuted as a proven real-game score claim**
> unless 4×4 somehow differs from 3×2. The Wave-0 pilots are done: T12
> (2×2) tautological; T13 (3×2) FALSIFIED. Wave-2 "C2-4×4" is now a
> falsification-extension probe, not a calibration task.

## The deliverable decision (what "solving 4×4" means)
1. **Full solution** — C2-bounded ✅ + C3 ✅ at 4×4: every (position, side)
   gets a single exact score or a sound [L,H] range.
2. **Core-only** — C2-bounded ✅ + C3 ❌ (the **expected** outcome, since C3
   is falsified at 3×3 and analogy-expected falsified at 4×4): only L==H
   region shippable; ko-sensitive region labelled "fresh-start fixpoint, NOT
   a real-game bound."
3. **No solution** — C2-bounded ❌: even the core is history-dependent; the
   table concept collapses until a different representation is built.

`[T07-5]` **C2-bounded is falsified at 3×2 (T13, 2026-07-26).** The decision is settled: option 3 (no real-game solution) is the verdict; the honest 4×4 deliverable is a **fresh-start score table + CLAIMED `[L,H]` bracket** (B05, `untracked/B05-glm.md`), not a real-game oracle. A 4×4 C2-probe (T19) or C3 run, if performed, is characterisation, not a deliverable input.

## Experiment plan — parallel wave structure `[T07-8]`

Replaces the prior serial `E0 → E1 → … → E5` plan. The truth-claim
dependencies are serial (C2 needs FP1; F2/F3/F4 need a regen; the regen
needs D3 feasibility), but **independent audits of distinct claims
parallelize**, and FP1-4×4 is a post-hoc check on the existing artifact
(not a new build), so the parallelism is wider than the prior plan allowed.

```
Wave 0 — immediate, fully parallel, all mechanical (no dependencies)
  • S2-4×4       — Benson implementation regression (rules.zig test
                   extension + hand-picked unit battery). Independent.
  • FP1-4×4      — post-hoc three-check on the *committed* artifact
                   (seed-from-`-N` + zero-change + V0/V1). No new build.
  • D3-4×3 pilot — full writes-off on 4×3, extrapolate to 4×4. Feeds
                   Wave 1's go/no-go.
  • C2-pilot-2×2 — exact solver on all L==H × M histories. **DONE**
                   (tautological: 2×2 has no reachable non-root cycles).
  • C2-pilot-3×2 — exact solver on L==H × non-trivial histories. **DONE —
                   FALSIFIED C2 at 3×2 (T13, 12/508 mismatches).**

Wave 1 — blocked on D3-4×3 pilot GO
  • F2+F3-4×4 writes-off regen — single artifact, shared by F2 and F3.
  • F2+F3 auditor + bracket containment — on the regen, not the
    committed artifact. (F2 and F3 are reported together; one acceptance.)

Wave 2 — blocked on Wave 0 calibration + Wave 1 regen
  • C2-4×4 falsification-extension probe — long-history ban sets; folded with C1-4×4
    (empty-history comparison is free in the same harness).
  • C3-4×4 range-aware self-play — low priority; characterises the leak
    magnitude. NOT on the deliverable's critical path.
  • F4-4×4 KM regen — byte-compare to writes-off regen, auditor +
    containment. Serial after F2+F3 (same disk; no parallel regens).

Wave 3 — blocked on C2/C3/F2/F3 results
  • Deliverable decision (Full / Core-only / No-solution) — depends on
    C2-bounded, not on C3-4×4.
  • E5 anchor consistency labeling — can run any time after Wave 2.
```

### What is genuinely serial (cannot parallelize)
- F2+F3 regen and F4 regen (same disk pipeline; AGENTS.md no-silent-write).
- C2-pilot results and the C2-4×4 design (pilot must calibrate the design).
- Any `src/retro.zig` edit (one writer at a time per AGENTS.md).
- The deliverable decision waits on C2-bounded (and F2/F3 for the artifact).

### What the prior plan serialised that need not be
The prior `E0 → E1 → E2 → E3 → E4` chain made C2 wait on C3 wait on F3 wait
on the wiring sanity. The actual dependencies are looser: FP1 is a post-hoc
check (no new build); C2-4×4 depends on the C2-pilots (Wave 0) and on FP1
(post-hoc), not on C3 or F3; C3-4×4 is off the deliverable's critical path.
Specs in `experiments/` (to be (re)written per Wave). Tables
in `tables/`.

## Open doc TODOs (not blocking, but honest)
- `[T07-2]` S4 at 4×4: pick `⬜ᴵᴺᴴ` (current) or add a falsifiable 4×4
  scoring battery. Blocked on UD-2.
- `[T07-9]` D3 target wall/memory: confirm with user (placeholder 8h / 32GB).
- C2-probe sample size and power argument: T12/T13 completed; C2 falsified
  at 3×2. No further C2-probe needed at 4×4. The open question is leak
  magnitude, not falsification.
