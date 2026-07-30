# F2-REMEDY — design of a sound finisher that does not depend on the bracket premise

```
Task: F2-REMEDY · Role: worker · Model: Fable 5 (claude-fable-5) · Date: 2026-07-29
```

**Opened by:** ADR-0018 (`GLOBAL.F2` orphaned and confirmed).
**Brief:** `docs/infra/dispatch/F2-REMEDY.md`.
**Kind:** ANALYSIS — this is a design, not a proof and not an implementation.
It closes nothing; it scopes the work that could. `GLOBAL.F2` stays
CLAIMED-and-orphaned regardless of this document.

## Headline

> **The sound finisher is no finisher at all: rebuild the L/H fixpoints with
> the existing `converge` operator on the `(board, side, ko_point, passes)`
> graph under basic ko + a constant long-cycle tie `T`, then pin every state
> exactly by `V = median(L, T, H)` — an O(1) post-processing with no forward
> search, no bracket cut, and no certified seeds. Soundness:
> proven-as-scoped by QA-023 Part A v2 Theorem 5.1, contingent on the (A1)
> hypotheses whose empirical check (EXP-2B, 3×2) is in flight — not asserted
> here. Cost: ~354 MB artifact and an estimated fixpoint run of the same
> order as the standing retrograde build at 4×4 (costing plan below is the
> first deliverable). Falsifier: 2×2 must return 0 where PSK returns +1;
> plus memo-less history-carried truncation probes against table values.**

Every claim in this document carries a tag. The load-bearing ones:

| # | claim | tag |
|---|---|---|
| D1 | `V = median(L, T, H)` equals the game value under basic ko + constant-`T` infinite-play verdict, on the `(board, side, ko_point, passes)` graph | **PROVEN-as-scoped** — `docs/evidence/QA-023/proof-v2-2026-07-28.md` Thm 5.1, adversarially reviewed (verdict REPAIRABLE-GAPS, all repairs applied, no theorem statement changed). Scope: conditional on hypotheses (A1-legal/term/ko/passes); **QA-023 overall stays CLAIMED until EXP-2B passes** |
| D2 | The build path below never consults history and never detects a repeated goban | **PROVEN-as-scoped** (by construction of the operator — §5; the argument is structural in the ADR-0016 sense) |
| D3 | The build path below reads no prior artifact and no certified seed, hence cannot inherit the CERTCORE premise (ADR-0017 finding 2 does not apply) | **PROVEN-as-scoped** (by construction — §3.4) |
| D4 | Cost at 4×4: ≤ 354 MB artifact, build working set ~350 MB (sparse) and wall clock of the same order as EXP-3's census (~4 min) × a small sweep-count factor | **CLAIMED** — estimate, not a measurement; costing is deliverable 1 of the implementation task (§7) |
| D5 | Anchors under this rule: 2×2 = 0, 2×3 = 0, 3×3 = +9, 4×4 = +2 | **CLAIMED** — and 2×2/2×3 are the falsification gate (EXP-4), not evidence; also gated on QA-023.M1 (that MIGOS II's rule is in fact value-equal — UNTESTED) |

---

## 1. What this remedy is, and pointedly is not

**It is not a rehabilitation of F2.** ADR-0018 confirmed that the
bracket-guided finisher's premise ("brackets hold under ANY arrival history")
is refuted as stated and the burden undischarged. This design does not
discharge it. It **dissolves the finisher**: under the target rule there is
no ko-sensitive residue left for a forward search to fill, so the component
whose soundness F2 asserts ceases to exist. `GLOBAL.F2` stays orphaned as a
claim about the shipped PSK-era artifacts, which this design supersedes
rather than repairs.

**It is not a brackets-off regen.** Foreclosed by ADR-0018 and the brief:
every generation mode of the current engine reads CERTCORE-dependent
certified seeds, so a brackets-off rebuild inherits the same premise. The
build below is a **new-rule** build on a **new state graph** with **no seed
inheritance at all** (§3.4) — it does not share the foreclosed regen's
epistemic position, because it reads nothing the bracket cut ever touched.
(Proof-v2 §7 is explicit that no shipped artifact's L/H columns can be
reinterpreted into new-rule values by any post-processing; the sweeps must
run on the new graph.)

**It is the QA-026 direction, with QA-026's wording corrected.** QA-026 as
registered says loops are "pinned to the tie value instead of shipping a
bracket." That is v1's rule (`L < H ⇒ V = T`) and it is **false** — the §5.3
gadget of proof-v2 is a concrete counterexample (true value 1, v1 rule
returns 0). The corrected rule, same cost, is `V = median(L, T, H)`: the tie
pins a loop-valued state only when `T` lies inside `[L, H]`; otherwise the
nearer fixpoint is the value, because the disadvantaged player prefers a
terminal to the tie. The CLAIMS owner should reword QA-026 (§9).

## 2. The rule being solved (inputs this design takes as given)

Basic ko (formalization (i): the single point forbidden after a single-stone
ko capture, cleared by any other move — the (i)-vs-(ii) choice is an open
user ADR, proof-v2 §9.6), Chinese area scoring, suicide forbidden, and a
**constant** value `T` assigned to infinite plays. `T = 0` is assumed
throughout, pending the user's A3-sub ADR (proof-v2 §9.5); nothing below
depends on the specific value except `−n ≤ T ≤ +n` (needed by Theorem 5.1's
clamp robustness) and the reporting convention for ties (no sentinel needed
— 0 is inside the terminal value set even on odd gobans, because neutral
regions exist; proof-v2 §9.4).

**The rule has no in-game repetition trigger** (proof-v2 §1.2 Remark):
cycles are *valued*, never *detected*. Any operational game-ending trigger
is a different game unless proven value-equal; the one proven-equal trigger
is first revisit of the **full state tuple** within the continuation
(Theorem 6.1). The arena must use exactly that trigger (§4.3).

## 3. The approach, concretely enough to implement

### 3.1 State space and addressing

State = `(board, side, ko_point ∈ {none} ∪ cells, passes ∈ {0, 1})`, with
`passes = 2` a computed terminal (payoff = `area_score`), never stored.
Since a pass clears the ko point, the `passes = 1` slice carries
`ko_point = none` only.

Census (EXP-3, `docs/research/kostate-census-2026-07-28.md`, exact, no
sampling; denominators as stated there):

| goban | reachable `(b,side,ko)` | with passes (a′) | distinct `(b,ko)` | sparse/dense | artifact 6 B/addr |
|---|---|---|---|---|---|
| 3×3 | 22,736 | 45,472 | 13,997 | 7.111% | 84 KB |
| 4×3 | 638,266 | 1,276,532 | 375,281 | 5.432% | 2.25 MB |
| 4×4 | 51,419,046 | 102,838,092 | 29,497,329 | 4.031% | 177 MB (354 MB with passes) |

Two candidate addressings (EXP-3 deliberately declined to choose; the choice
is a user ADR — this design gives its recommendation and the reasoning, and
defers the decision):

- **Dense** `(colex(board) × ko × side)` planes + a ko-free `passes = 1`
  plane. At 3×3/4×3 this is trivially fine. At 4×4 the working set is
  `24.3M legal × 17 × 2 sides × 2 fixpoints × 1 B ≈ 1.65 GB` on legal
  gobans, ~2.9 GB if allocated over raw `3^16` — at or over the
  `tools/runner` 4 GB kill line once legality maps and the passes plane are
  added. **Not recommended at 4×4.**
- **Reachable-sparse (recommended at 4×4):** a `(b, ko)` reachability bitset
  over `3^16 × 17` bits (91.5 MB) with a rank directory (O(1) address =
  rank of the bit), value arrays indexed by rank: L and H at i8 over
  102.8M reachable states ≈ 206 MB, total working set ≈ **350 MB**
  [CLAIMED — arithmetic on EXP-3's exact counts, not yet a measured RSS].
  Reachability is closed under legal moves by definition, so a sweep over
  reachable states never needs an unreachable value. Queries from
  unreachable setups (e.g. hand-placed Sabaki positions) return UNDEF and
  the GTP layer refuses honestly — same policy as today's unfilled slots.

### 3.2 The fixpoint operator (the reuse of `converge`)

Exactly ADR-0009's operator, re-hosted on the new graph — Black max / White
min **in both fixpoints** (proof-v2 §9.3 records v1's swapped-max/min
transcription error so nobody copies it):

- Successors of `(b, side, ko, 0)`: every legal goban move (full move set,
  **no eye-prune**, matching ADR-0009 Decision 3 *and* hypothesis (A1-legal)
  — the retrograde sweep has no reopening problem and the proof's graph is
  the true rule's graph) with the child's `ko_point` computed by the
  `isKoCapture` shape, plus pass → `(b, -side, none, 1)`.
- Successors of `(b, side, none, 1)`: goban moves (child passes = 0) plus
  pass → terminal with payoff `area_score(b)`.
- `L` seeded −n on non-terminals, swept up to the least fixpoint; `H` seeded
  +n, swept down to the greatest. Monotone, so convergence is guaranteed;
  the zero-change sweep is the check (`src/retro.zig:326-334` unchanged in
  spirit; the loop bodies change because the state gained `ko` and lost
  nothing else).

**Deliberate deviation from the current engine, flagged:** the current graph
treats Benson-settled gobans as terminals for both sides (`is_settled`,
ADR-0009 seed). Theorem 3.1 is proven for `Terminal(S) ⇔ passes = 2` only.
The v0 build must therefore use **pass-pass terminals only**, exactly the
proven graph. Re-adding settled-terminals is an optimization that changes
the graph and needs its own equivalence argument (GLOBAL.ADR0004-TERM covers
the *score* of a settled goban, not the removal of its out-edges from this
rule's game graph with a tie in the value domain) — **UNTESTED; do not fold
into v0**. Same discipline for any eye-prune in forward cross-check tools:
the cross-checks keep ADR-0006's prune per that ADR, and any disagreement is
(as always) a standing test of ADR-0006.

### 3.3 The post-processing (the corrected pin)

After both fixpoints converge, per state, O(1):

```
V(S) = max(L(S), min(T, H(S)))        // = median(L(S), T, H(S))
```

[PROVEN-as-scoped — Thm 5.1.] `L = H` states are untouched by `T`
(median = L). `L < H` states are pinned to whichever of `{L, T, H}` is the
median. **Every reachable state gets an exact value.** There is no
ko-sensitive residue, hence no finisher pass, no per-root forward search, no
memo, no `ko_ref`, no journal, no budget-skip. The entire apparatus from
`Finisher.init` through `ab_value_from_root` has no counterpart in this
build.

Flags to keep (reporting metadata, not semantics): bit for `L < H`
("loop-valued under this rule"), and the trichotomy bucket
(`T < L` / `T ∈ [L,H]` / `H < T`) — the **pin census** EXP-4 must report per
goban, because a zero outer bucket is exactly where v1's false rule would
have silently coincided.

### 3.4 Seeds — the answer to "how are certified seeds produced without the bracket cut"

**They are not produced, because none are needed.** The only inputs to the
sweep are: the legality predicate, the move generator, `area_score` at
`passes = 2`, and the constants ±n. No prior `.wzo` is read; no
`FLAG_KO_SENSITIVE`/`FROM_FORWARD` triage exists; no forward memo is
pre-seeded because no forward solve runs. The CERTCORE inheritance channel
that ADR-0017 finding 2 identified — certified seeds whose empty
fingerprint clears `fpDisjoint` — is closed **by absence of the mechanism**,
not by an argument about it [D3, PROVEN-as-scoped by construction; the
implementation task must keep it true, i.e. the build binary must not link
a seed-loading path at all].

### 3.5 Artifact

New file, new name, tagged by ruleset per the standing no-silent-writes
rule: e.g. `data/oracle-3x3-basicko-tie0.wzo`,
`data/oracle-4x4-basicko-tie0.wzo`. Header (ADR-0011 versioning) must
record: ruleset id (basic-ko formalization (i), `T`, area scoring),
addressing scheme (bitset + rank directory serialized alongside the
columns), and the census counts as integrity checks. Columns per reachable
state: `V: i8` (no `TIE` sentinel — proof-v2 §9.4), `dtt: u8`, `flags: u8`
(§3.3). Existing PSK-era artifacts are kept untouched under their own
(size, ruleset) tags per `ruleset-options.md` doctrine.

**DTT semantics change and must be redefined [CLAIMED, design decision for
the implementation ADR]:** states whose value is achieved only against
termination-refusing play (the `V = T` bucket where the opponent may cycle)
have no finite "fastest optimal resolution"; they carry `DTT_FAR = 255`.
The existing min-sweep computes DTT only over optimal edges that decrease
toward terminals; loop-valued optimal play saturates. `choose`'s
smaller-DTT tiebreak then automatically prefers terminal-reaching moves
among value-ties, which is the desired play style.

## 4. Consumption

### 4.1 `Session.choose` (GTP)

`Session.choose` today is a one-ply table extremum over
`v0(child_board, -side)` with a PSK `seen()` legality filter
(`src/gtp.zig:344-386`; EXP-16 established the one-ply-extremum reading).
Under the new table the shape survives; the key and the filter change:

1. Session state adds `ko_point` (it already tracks `passes`). After each
   played move it updates `ko_point` by the same `isKoCapture` shape the
   build uses — one code path, shared, so the play-time key and the build
   key cannot drift.
2. Move loop: for each empty cell, child = `pos_from_move`; **legality =
   basic ko** (reject `p == ko_point`); value = `V(child, -side,
   ko_of(child move), 0)`. Pass value = `V(pos, -side, none, passes+1)`,
   with `passes = 1` → pass gives `area_score` (unchanged code).
3. **The PSK `seen()` filter must not gate the solved-rule policy** — under
   this table it would change the game being played and un-anchor the
   optimality claim. PSK-awareness lives where the roadmap put it (S3): a
   play-time *flag* when the opponent's rule would forbid the chosen move
   or when the real history would make the table's answer diverge — a
   warning channel, never a value channel.
4. The H5a `choose_with_check` A1/A2 chainability checks stay wired in.
   Under QA-027 (Markovian ⇒ 100% chainable, CLAIMED) they should never
   refuse; **keep them precisely because a refusal is then a falsifier**,
   not because they are expected to fire.

### 4.2 Tie handling at the UI

`V = 0` states may be true ties (loop-valued, pinned) or scored zeros
(neutral regions). The value column does not distinguish them — by design
(§3.5); the `L < H` flag plus trichotomy bucket is the reporting channel if
an operator wants "this 0 is a tie you can only bank by being willing to
cycle forever."

### 4.3 The arena

The arena plays full games and must **end** them; the one game-ending
trigger proven value-equal to the solved game is **first revisit of the
full `(board, side, ko_point, passes)` tuple within the game, scored `T`**
(Theorem 6.1; the game root is the fresh start, so the whole game is the
continuation). Goban-keyed or `(board, side)`-keyed triggers are a
*different game* with **unproven** value-equality (QA-023.M2, UNTESTED) —
the arena must not use them, however natural they look. The arena already
tracks seen positions; the change is keying that set on the full tuple and
scoring `T` instead of declaring PSK-illegality. With that trigger, EXP-7's
certified-fraction measurement (prediction: 100%; a falsifier, not a
formality) is a measurement of the game the table actually solves.

### 4.4 Forward cross-checks (the probe family)

Any forward evaluator under this rule — EXP-2B's probe, spot-checks, an
arena adjudicator — computes the history-carried value by first-revisit
truncation (leaf = `T`) and **must not cache truncated values by state**:
interior truncated values are path-dependent (proof-v2 reviewer F1, with an
explicit counterexample; this is the GHI trap's third appearance in the
project). This is an operational foreclosure the implementation task must
write into the probe sources as a comment *and* into the dispatch briefs.
It costs probe speed only; the generation path is the fixpoint sweep, which
needs no such cache.

## 5. The R2 / RPLY-TRAP check (hard constraints 2 and 3)

**Why the tie-pinned loop is a constant verdict (R2).** `T` is one global
constant. `V(S) = median(L(S), T, H(S))` consults the state's own two
fixpoint values and the constant — never the identity of a repeated goban.
Contrast score-on-cycle, where the verdict is `area_score(repeated board)`,
a function of which goban recurred: that is what made it byte-identical to
PSK (`GLOBAL.R2`). Nothing in §3 evaluates a cycle at all: infinite play
enters the value only through the trap lemmas, which are global properties
of the graph computed by the sweeps (proof-v2 §8). [D2,
PROVEN-as-scoped — structural.]

**Why the key stays history-free (RPLY-TRAP).** The RPLY trap was: a cycle
*terminal* forces cycle *detection*, which drags every seen goban into the
memo key. Here (a) the generation path has **no memo and no search** — a
table sweep has no key beyond the state address; (b) the play-time lookup
key is the state tuple; (c) the only component that ever detects a repeat
is the arena's *game-ending trigger* (§4.3), which consumes history the way
a referee does — it ends the game — and feeds nothing back into any stored
value; and (d) the one place history could sneak back in — memoizing
truncated forward values — is foreclosed by name (§4.4). [D2.]

## 6. Per-goban independence (ADR-0016 discipline, constraint 4)

**Structural (inherits, with the argument):** Theorems 3.1/4.1/5.1/6.1 are
pure finite-graph game theory; their hypotheses (A1-*) are per-*rule*, not
per-goban (proof-v2 §1.1 makes this explicit). D1–D3 above therefore carry
to every goban size *conditional on the hypotheses*.

**Empirical (never inherits):** every number — census counts, sweep counts,
wall clock, pin census, anchor matches, EXP-2B's (A1)-conformance check,
EXP-7's certified fraction, EXP-8's PSK divergence. In particular: EXP-2B
passing at 3×2 checks the (A1) hypotheses *there*; the per-goban gates
(EXP-4: 2×2/2×3 = 0; EXP-5: 3×3 = +9; EXP-6: 4×4 = +2 with a filled root)
plus the auditor (§8) are what stand in for it at each size. No anchor
match at one size is evidence at another.

## 7. Cost (constraint 5) — estimate now, measurement as deliverable 1

All numbers below are CLAIMED estimates derived from cited measurements;
none is itself a measurement of this build.

- **Space:** §3.1 table. Artifact ≤ 354 MB at 4×4 (EXP-3's 6 B/addr row,
  passes folded); build working set ≈ 350 MB sparse — comfortably inside
  the `tools/runner` 4 GB line. 3×3/4×3 are trivial (≤ 3 MB).
- **Wall:** the closest measured analog is EXP-3's reachability fixpoint on
  the *same* graph: 29 sweeps, ~4 min at 4×4, single thread, ReleaseFast
  (`kostate-census-2026-07-28.md`). A value sweep does the same successor
  enumeration plus i8 min/max updates, and two fixpoints run instead of
  one; the standing PSK build's sweep count is 19 at 4×4 (AGENTS.md build
  note). Estimate: **tens of minutes at 4×4, single thread** — three-plus
  orders of magnitude inside the foreclosed brackets-off regen
  (>5e8 nodes on the empty root alone, `GLOBAL.H5c`) and with no finisher
  phase at all, which was the unbounded part of the old build.
- **Costing plan (the first implementation deliverable, per the brief):**
  build 3×3 first (expected seconds), then 4×3, reporting per-fixpoint
  sweep counts, wall, and peak RSS under `tools/runner`; extrapolate to 4×4
  only as a *prediction to check*, then measure 4×4. A sweep count at 4×4
  materially above ~100, or an RSS above ~1 GB sparse, falsifies this cost
  section and triggers re-design of the addressing before any long run.
- **Tractability honesty:** if QA-023 falls, none of this is spent at risk —
  the census and the addressing layer are rule-independent
  (reachability under basic ko), and the sweeps are cheap enough that even
  a discarded 4×4 run costs minutes, not the machine-week the brief warns
  about.

## 8. Falsifiers and calibration (acceptance item 6)

The remedy is unsound (or mis-implemented — the probes cannot distinguish
these, and do not need to) if **any** of the following fires:

1. **EXP-4 gate:** 2×2 or 2×3 returns anything but 0. PSK's answer is +1;
   a +1 here means the build solved the wrong game. Cheapest, runs first.
2. **History-carried agreement (the direct falsifier):** at 3×2 (and
   sampled 3×3), the memo-less full-tuple first-revisit truncation value of
   a state, reached via multiple distinct arrival histories with a non-zero
   cycle census, differs from the table's `V`. This is EXP-2B's shape,
   re-run against *this* build — it checks (A1) and the implementation at
   once (proof-v2 §6.2 item 4).
3. **Bellman self-consistency (#2 auditor, mandatory pre-commit gate):**
   `V` is the value of a determined game, so it must satisfy
   `V(S) = opt_side over successors' V` at every non-terminal — exhaustive
   at 3×2, deepest-N sampled at 4×4. **Calibration known-bad:** wire v1's
   rule (`L < H ⇒ V = T`) into the post-processing and the auditor must
   flag the §5.3 gadget (synthetic fixture; median rule returns 1, v1 rule
   returns 0). **Known-good:** the gadget under the median rule, plus the
   L = H slice where `V = L` trivially. An auditor without both cases
   proves nothing (standing rule).
4. **Pin census sanity:** if EXP-4's census shows `T ∉ [L, H]` states and
   the shipped values there equal `T`, the false v1 rule is live in the
   code — instant fail, no game-play needed.
5. **Anchors:** 3×3 ≠ +9 or 4×4 ≠ +2 (with root filled). Interpreting a
   miss needs QA-023.M1 first (is the MIGOS II verdict value-equal to the
   infinite-play tie? — UNTESTED): a miss falsifies the *conjunction* of
   the build and M1, and the M1 check must be done before EXP-5/6 treat
   anchors as ground truth.
6. **EXP-7:** certified fraction under full-tuple-adjudicated self-play
   below 100% falsifies QA-027 and with it the Markovian claim as
   operationalized (any `choose_with_check` refusal is the same signal at
   single-move grain).
7. **Standing battery:** colour inversion (`L(-pos,-side,ko⁻) = -H(pos,side,ko)`
   pairing L with H, ko transformed covariantly), dihedral orbit
   consistency over values *and* flags — exhaustive, as in ADR-0009.

## 9. The QA-023 contingency (hard constraint 1)

**Not asserted:** QA-023 stays CLAIMED. Part A is proven-as-scoped
(theorems reviewed); the computational half (EXP-2B, 3×2, non-zero cycle
census required) is in flight with Minimax-m3 at the time of writing.

**If QA-023 holds** (EXP-2B passes): this design proceeds as written;
EXP-4/5/6 implement §3, EXP-7/8 measure §4.

**If QA-023 falls at 3×2**, the failure localizes, and the remedy differs by
branch (proof-v2 §6.2 item 4 gives the disjunction):

- **(a) An implementation defect** in the probe or rule code — fix and
  re-run; the design is untouched. This must be ruled out first
  (calibration cases exist for exactly this).
- **(b) An (A1) hypothesis is false as formalized** — i.e. some
  legality/termination component of *real* basic ko consults history beyond
  the tuple (most plausibly the ko formalization (i)/(ii) mismatch). The
  theorems survive; the *state tuple* was wrong. Remedy: enlarge/repair the
  tuple to carry exactly what the rule consults (basic ko consults one ply,
  so the repaired tuple stays O(cells) wide — this is bounded, unlike the
  RPLY ladder, because *legality* is what is being repaired, not a cycle
  terminal), re-run the census (EXP-3's machinery re-parameterizes), and
  re-derive the addressing. The design's shape survives with a bigger key.
- **(c) The claim fails irreparably** — no bounded tuple satisfies (A1) for
  a Go-faithful basic-ko rule. Then the remedy is **X = retreat to the
  honest floor plus the exact-but-expensive route**: (X1) ship the
  bracket-only deliverable (the T14.1 `bracket_only` path already in the
  engine: fresh-start single-score region + `[L,H]`, no finisher, no F2
  claim at all — sound and partial by design), and (X2) scope
  Kishimoto–Müller dependency-set finishing (ADR-0010's named fallback;
  the F4 fingerprint machinery is PROVEN-as-argument) as the only known
  exact finisher that does not rest on the bracket premise — with the
  explicit warning that its cost is unmeasured and it may be
  intractable-in-practice at 4×4. F2 would then be *withdrawn*, not
  remedied — and that is the honest outcome, recorded as such.

## 10. Status lines for the CLAIMS.md owner (not applied here — owner's file)

- `GLOBAL.F2`: no change — CLAIMED-and-orphaned, confirmed (ADR-0018); this
  design supersedes rather than rehabilitates; scope note "applies to
  PSK-era artifacts only" may be added when the new-rule build lands.
- **New row proposed** `GLOBAL.F2-REMEDY`: "The finisher-replacement is the
  median build: `converge` on `(board, side, ko_point, passes)` under basic
  ko + constant tie `T`, then `V = median(L, T, H)` (proof-v2 Thm 5.1); no
  forward search, no brackets, no seed inheritance. **CLAIMED** — design
  only (`docs/research/f2-remedy-design-2026-07-29.md`); `d:QA-023`,
  `d:QA-023.M1` (anchors), gated on EXP-4."
- `QA-026`: **reword** — current text states v1's false rule ("pinned to
  the tie value"); the reuse claim is true but the pin is
  `median(L, T, H)`, per proof-v2 §5.2/§7. Suggested edge: `e:` proof-v2
  Thm 5.1.

## 11. Not established here (candour)

1. QA-023's computational half (EXP-2B) — in flight; nothing above asserts
   it.
2. QA-023.M1 (MIGOS II rule identity) and .M2 (trigger equivalence beyond
   the full tuple) — UNTESTED; M1 gates anchor interpretation (§8.5), M2
   gates any arena trigger other than §4.3's.
3. The `T` value / komi ADR and the ko formalization (i)/(ii) ADR — the
   user's, pending; this design parameterizes over both.
4. Benson-settled terminals in the new graph — UNTESTED equivalence; kept
   out of v0 (§3.2).
5. The addressing choice at 4×4 — recommended sparse, decided by ADR, not
   here.
6. Whether sweep counts at 4×4 stay near the census's 29 — the costing
   plan's first measurement, and this design's cost section falls if it
   misses badly (§7).
7. DTT's exact definition on loop-valued states — flagged (§3.5), needs a
   line in the implementation ADR.
