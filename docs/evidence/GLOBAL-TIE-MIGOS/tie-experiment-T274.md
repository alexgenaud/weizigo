# TIE-EXPERIMENT-T274 — does a different tie constant reproduce MIGOS's +2 at 4×4?

Task: T274 · Role: worker · Model: deepseek-v4-flash (per dispatch "You are DSFlash";
Orchestrator directive D011 addressed this seat as "deepseek-v4-pro/T274" — discrepancy
flagged for the performance ledger, managent `agent` field unchanged: `deepseek-v4-flash/T274`)
· Date: 2026-08-02

**Status: COMPLETE — 2026-08-02.** Reading half committed (`5f87b5b`); empirical half executed under Orchestrator directive D014 as the **descoped small-goban sweep** (2×2, 3×2, + 3×3 supplementary; **no 4×4 run** — 4×4 remains analytic-only, see §5, §9). D011's HOLD (host memory contention, per-PID RSS guard) governed the session; D014 lifted it for the cheap gobans only.

---

## 1. The question (from the brief)

`GLOBAL.TIE-MIGOS` (minted CLAIMED by T271) hypothesises that the +1-vs-+2 miss against the
MIGOS II 4×4 anchor is a genuine ruleset difference in **tie value** (our TIE=0 vs "MIGOS's
implementation-specific long-cycle-tie value"), not a ko-rule difference and not a defect.
The falsification test: re-run the 4×4 fresh-start root with only the tie constant changed;
if some tie value yields +2, the tie hypothesis is supported; if none does, the tie
hypothesis is refuted and the defect hypothesis (`GLOBAL.FIXPOINT-VS-SEARCH`, candidate
(b)) survives.

## 2. The anchor and the correct citation

The register cites the 4×4 +2 anchor to "van der Werf 2005 PhD thesis **§6.4**"
(`4x4.ANCHOR`, `retrograde-4x4.md:93`, `AXIOMS.md` §4.2). **That section reference is
wrong.** In the thesis (full text obtained 2026-08-02 from the Maastricht repository,
DOI 10.26481/dis.20050127ew) §6.4 is "Learning connectedness" (neural-network experiments).
The 4×4 solve is §5.4.1 (Table 5.1) plus Appendix A (§A.4) for the rules; the 2009 ICGA
paper "Solving Go for Rectangular Boards" (van der Werf & Winands, ICGA Journal 32(2))
reports MIGOS II's +2 at Table 1 ("16 4×4 2 21–23 695–826k 1.09–1.73(s) central").
This is a drifted-citation finding against `4x4.ANCHOR` / `AXIOMS.md` §4 — see §7.

## 3. What MIGOS actually does with a long cycle — the documented answer

### 3.1 The rules-level answer (thesis Appendix A §A.4, "Repetition" — the MIGOS rules)

> "A repetition is a whole-board situation which is identical to a whole-board situation
> that occurred earlier in the game. If a repetition occurs, the game ends and is scored
> directly based on an analysis of all moves in the cycle starting from the first
> occurrence of the whole board situation. **If the number of pass moves in the cycle is
> identical for both players the game ends as a draw. Otherwise, the game is won by the
> player that played the most pass moves in the cycle.** Optional numeric scores for an
> exceptional end by repetition are: +∞ (black win), −∞ (white win), and 0 (draw)."

MIGOS's long-cycle resolution is a **rule** (repetition ends the game; balanced cycle =
draw; unbalanced cycle = the player who passed more wins), not a search-constant choice.

### 3.2 The value assigned to a long-cycle tie (thesis §5.3.2; 2009 paper §3.2–3.3)

Thesis §5.3.2:
> "In practice **we use 0 as the value for a draw**, and we do not distinguish between a
> draw and heuristic scores."

2009 paper §3.2 (evaluation):
> "MIGOS II (optionally) distinguishes between normal scores … and exceptional scores
> (used to assign a value for termination by long-cycle repetition). In practice, the most
> important application of this change is to distinguish long-cycle ties from ordinary
> ties. This facilitates analysis because we can, e.g., **configure White to win in the case
> of an ordinary tie … while Black wins in case of a balanced long-cycle repetition.**"

2009 paper §3.3 (transposition table):
> "Since superko is not used, balanced long-cycle repetition (where both sides capture an
> equal number of stones in each cycle) is scored as a long-cycle-tie. **Normally, there is
> no need to distinguishing long-cycle-ties from heuristic scores, so MIGOS II simply
> assigns a value in the heuristic range (typically 0).** However, when optimal play leads
> to a long cycle-tie this setting prevents the search from returning a proof.
> Alternatively, the long-cycle-tie can be assigned a value corresponding to a **minimal
> proven win, for either Black or White**, but this then becomes prone to the ordinary GHI
> problems normally observed only under superko rules…"

**The documented default long-cycle-tie value is 0 — identical to our TIE=0.** A
non-zero tie value (a "minimal proven win", +2 at 4×4) is a documented *optional
configuration*, described as breaking the search's soundness (GHI-prone), not as the value
used for the published results.

### 3.3 The decisive datum: MIGOS's own 4×4 result under basic ko is +1

Thesis §5.4.1, Table 5.1 ("Solving small empty boards", MIGOS I):

| goban | ko rule | result |
|---|---|---|
| 4×4 | **basic** | **+1** |
| 4×4 | Japanese | +2 |
| 4×4 | approx. SSK | +2 |
| 4×4 | full SSK | +2 |

> "Another conspicuous result is that **under basic ko Black does not win the 4×4 board by
> two points. The reason is that the two-point victory is unreachable by a seki with a
> cycle where White throws in more stones than Black per cycle.**"

> "Since the two-point victory for Black on the 4×4 board is a seki (which is a draw under
> Japanese rules) it also confirms the results of [Sei & Kawashima 2000]."

Under **basic ko** (MIGOS's own default, per thesis §2.2.1: "the reader may safely assume
as a default that only the basic-ko rule is relevant") with long-cycle ties worth 0,
**MIGOS returns +1 for the empty 4×4 — exactly our +1.** The +2 appears only under the
repetition-scored rulesets (Japanese ko / the Chinese-rules formalisation of Appendix A,
and SSK), where the +2 seki is reachable because White cannot escape into a balanced cycle
and cannot repeat.

### 3.4 The literature does not document a non-zero tie VALUE for the 4×4 +2

No passage in either source states a numeric long-cycle-tie value other than 0 (draw) as
the one used for the published 4×4 result. The 2009 paper's Table 1 flags tie-sensitivity
explicitly where it matters (footnote 10, 2×2: "the result remains a tie as long as komi
is in the range [-1,1] because either side can force a balanced long cycle"); the 4×4 row
carries no such footnote. So the anchor's +2 is either (a) the +2 seki reached under the
repetition-scored ruleset, or (b) a configured minimal-win tie — the sources do not
disambiguate, which bounds what the anchor can ever prove: **the +2 anchor is not evidence
about the value of a long cycle under basic-ko-with-flat-tie rules.**

## 4. Reading-half conclusion

The `GLOBAL.TIE-MIGOS` hypothesis as minted — "a genuine ruleset difference in **tie
resolution (TIE=0 vs MIGOS's implementation-specific long-cycle-tie value)**" — is
**contradicted by the primary sources on its stated mechanism**:

- MIGOS's long-cycle-tie value **is 0** (draw), the same as our TIE=0 (thesis §5.3.2;
  2009 paper §3.3 "typically 0").
- MIGOS's own basic-ko 4×4 result is **+1 = our +1** (thesis Table 5.1).
- The +2 comes from a different **cycle-resolution rule** (repetition ends the game, scored
  by pass-difference in the cycle; or SSK banning the repeat), which is a different game
  definition — not a different tie constant.

The remaining work is the empirical half (§6): confirm that no flat tie constant reproduces
the full colour-symmetric anchor (+2, −2). The analytic prediction from the build is
§5; the runs will confirm three points of it.

## 5. Build analysis — where TIE actually lives in `src/exp6_solve.zig`

- `pub const TIE: i8 = 0;` (line 41) is the only tie constant.
- The value rule is `V = median(L, TIE, H) = max(L, min(TIE, H))` (printed in the run
  header; implemented at `v()` line 58, `median32()` line 403, `median()` line 686, and
  the WZO fill at line ~1456).
- **All four fixpoints (2×2, 3×2, 3×3, 4×4) propagate raw L/H — no fixpoint update loop
  references TIE.** Verified by inspection (the 2×2 loop at lines 62–120, 3×2 at 404+,
  3×3 at 686+, 4×4 Phase-5 sweeps at 1150+ use `L_tab[child]`/`H_tab[child]` only).
  Therefore the [L,H] brackets are TIE-independent, and the reported root value is
  exactly `V_root(TIE) = clamp(TIE, [L_root, H_root])`.
- With the measured bracket [L=+1, H=+16] (B) / [−16, −1] (W):
  - V_B(TIE) = clamp(TIE, [1,16])  →  +1 for TIE ≤ 1; TIE itself for 2 ≤ TIE ≤ 16; +16 for TIE ≥ 16.
  - V_W(TIE) = clamp(TIE, [−16,−1]) →  −1 for TIE ≥ −1; TIE itself for −16 ≤ TIE ≤ −2.
  - **Only TIE = +2 gives V_B = +2; at TIE = +2, V_W = −1 ≠ −2.** No single flat tie
    constant reproduces the colour-symmetric anchor (+2, −2). The W-side −2 requires
    TIE = −2, at which V_B = +1. (The bracket is colour-inversion-consistent, but the
    single-constant median value function is not: colour inversion demands the *signed*
    tie, i.e. a per-side tie, which a single constant cannot express.)
- The `brute_value` function (line 788) returns `TIE` on repetition and is dead code in
  `main()` — it is never called (relevant to the T102 successor-buffer warning: the
  warning concerns a cross-check that this solver does not run).

## 6. Run plan, budget and what actually ran (D014 descope)

**Budget (stated before starting):** 3 × ~53-min 4×4 runs ≈ 2.75 h wall under
`tools/runner` with the default 4 GB RSS cap (observed peak 3137 MB on 2026-07-29).
**What actually ran (D014):** a 5-value TIE sweep over the *small* gobans only — TIE ∈
{0, +2, −2, +16, −16} — each run seconds-scale (2×2 fixpoint 4 sweeps, 3×2 10 sweeps,
3×3 16 sweeps), executed by `src/t274_tie_harness.zig` (committed) importing
`src/exp6_solve.zig`. The harness never references `main()`, so the 4×4 census/fixpoint/
WZO write is neither analyzed nor executed. **The 4×4 root was not run** (descope; the
+2-vs-+1 4×4 analysis in §5 is analytic, standing on the measured 2026-07-29 bracket
[+1,+16] plus the TIE-free-fixpoint property now empirically confirmed).

**Source change per run (nothing else):** only `pub const TIE` (line 41) of
`src/exp6_solve.zig`; restored to 0 after the sweep. The WZO output-path diversion (line
1538 → `/tmp/weizigo/T274-tie-0.wzo`) is committed per D014 to honour "no silent writes
to `data/`" — `data/oracle-4x4-basicko-tie-area.wzo` is untouched. This is I/O hygiene,
not a ruleset change; the axiom set is otherwise fixed. (Note: the working tree was
reverted between sessions — the first application of the diversion was lost; it was
re-applied and committed with this revision.)

**Blocker found 2026-08-02 (before any run):** `src/exp6_solve.zig` at HEAD does NOT
compile with the current toolchain (zig 0.16.0): `fp4_out.data.deinit()` const-qualifier
error at line 1568 (`const fp4_out` at line 1407). The QA-026-era commit (eeec85c,
2026-07-29) had `!Fixpoint4Result` and no `.data.deinit()`, so the +1 measurement ran
structurally different code; the refactor (T165–T167/T226) changed exports, comments and
the return struct but **not any sweep kernel** (diff-verified), so the QA-026 +1 remains
the measurement of the same game. The required fix is mechanical (`const`→`var`); it is
left un-applied because the descope does not run `main()`. The "unmodified build" null
control for the 4×4 gate chain therefore cannot run as-is at HEAD — a finding about the
tree, not about the experiment.

**Host contention:** a concurrent `zig build test` (not ours) ran at ~22:41; our
seconds-scale runs were unaffected.

## 7. Findings for the register (proposed in `findings/T274-tie-experiment.json`)

1. `GLOBAL.TIE-MIGOS` — proposed **FALSE-AS-SCOPED**: primary sources show MIGOS's
   long-cycle-tie value is 0 (identical to ours) and MIGOS's own basic-ko 4×4 = +1 = ours;
   the +2 anchor arises from the pass-difference cycle-resolution rule (a different game
   definition). The empirical half (D014) confirms the value knob only affects
   cycle-valued states (see §9) and that no flat tie can reproduce the colour-symmetric
   (+2, −2) at 4×4 (analytic, §5): V_W = clamp(TIE,[−16,−1]) ≠ −V_B for every single
   TIE.
2. `GLOBAL.FIXPOINT-VS-SEARCH` — proposed CLAIMED: under aligned rules (basic ko, tie 0)
   weizigo fixpoint (+1) and MIGOS search (+1, thesis Table 5.1) agree; the +1-vs-+2 gap
   is a ruleset (cycle-resolution) difference, not a fixpoint-vs-search discrepancy. A
   defect hypothesis for our own game's value remains live only in the standing sense
   (#2 auditor).
3. **Citation correction:** `4x4.ANCHOR` and `AXIOMS.md` §4 cite "thesis §6.4" for the
   4×4 +2; the correct location is thesis §5.4.1 (Table 5.1) + Appendix A §A.4.
4. **Tree finding:** `src/exp6_solve.zig` at HEAD does not compile (const/var at line
   1568/1407); the QA-026 measurement's code (eeec85c) is structurally older but
   semantically identical.
5. **Roadmap note (not a register row):** EXP-6's "4×4 = +2" acceptance criterion
   (`roadmap-2026-07-28.md:227-232`) is not met by ruleset R (basic ko + flat TIE=0) and
   cannot be, because the +2 anchor is a different game (pass-difference cycle scoring;
   MIGOS's own basic-ko result is +1). The criterion needs restating against the ruleset
   actually solved.

## 8. Empirical results — small-goban TIE sweep (D014 descope, 2026-08-02)

Harness: `src/t274_tie_harness.zig` (committed), importing `src/exp6_solve.zig`; per run
only `pub const TIE` changed (line 41). Full logs:
`/tmp/weizigo/T274-tie-{0,2,-2,16,-16}.small.stdout` (ephemeral).

### 8.1 Roots — L/H unchanged, V = clamp(TIE,[L,H]) exactly

| TIE | 2×2 root [L,H] | V | 3×2 root [L,H] | V | 3×3 root [L,H] | V |
|---|---|---|---|---|---|---|
| **0** | [−4, +4] | **0** (committed root ✓) | [−6, +6] | **0** (✓) | [9, 9] | **+9** (✓) |
| +2 | [−4, +4] | **+2** | [−6, +6] | **+2** | [9, 9] | +9 |
| −2 | [−4, +4] | **−2** | [−6, +6] | **−2** | [9, 9] | +9 |
| +16 | [−4, +4] | **+4** (clamped at H) | [−6, +6] | **+6** (clamped at H) | [9, 9] | +9 |
| −16 | [−4, +4] | **−4** (clamped at L) | [−6, +6] | **−6** (clamped at L) | [9, 9] | +9 |

`clamp_ok=true` at every root; **violations=0** in the exhaustive per-state check
(V == clamp(TIE,[L,H])) over all reachable non-terminal states in every run: 1620 states
(2×2), 1732 states (3×2).

### 8.2 L/H tables are bit-identical across all five TIE values

Additive fingerprints (same every run):

| goban | L fingerprint | H fingerprint |
|---|---|---|
| 2×2 | 5556148101547559484 | 10401735261974369308 |
| 3×2 | 2064380219156613884 | 2776031351365902392 |
| 3×3 | 4187169911178369046 | 8972143558438831558 |

Sweep counts also identical per goban (2×2: 4 sweeps; 3×2: 10; 3×3: 16). This is the
empirical confirmation that the fixpoint is TIE-free (by construction — no sweep update
references TIE; confirmed on every state of three gobans).

### 8.3 Bracket census — where the tie constant decides

| TIE | goban | L==H (resolved) | L<TIE<H (V == TIE) | L>TIE (pin_L) | H<TIE (pin_H) |
|---|---|---|---|---|---|
| 0 | 2×2 | 904 | 570 | 40 | 106 |
| 0 | 3×2 | 1366 | 268 | 34 | 64 |
| +2 | 2×2 | 904 | 603 | 0 | 113 |
| +2 | 3×2 | 1366 | 281 | 6 | 79 |
| −2 | 2×2 | 904 | 603 | 113 | 0 |
| −2 | 3×2 | 1366 | 281 | 63 | 22 |
| +16 | 2×2 | 904 | 0 | 0 | 716 |
| −16 | 2×2 | 904 | 0 | 716 | 0 |

(L==H counts identical across TIE — the resolved core never moves; the tie-pinned and
pinned-side counts redistribute exactly as the clamp predicts.) The 5 widest-bracket
states (printed per run) are the same states every run with V = clamp(TIE,[L,H]), e.g.
2×2 lin 0: [−4,+4], V = 0 / +2 / −2 / +4 / −4 across the sweep.

### 8.4 What the sweep establishes

1. **TIE=0 null control passes**: 2×2 = 0, 3×2 = 0, 3×3 = +9 — the committed roots,
   reproduced by this checkout's code (which itself does not compile at HEAD for the 4×4
   path, but the small-goban paths compile and run).
2. **The tie constant is a pure value knob on cycle-valued states**: 2×2/3×2 roots are
   tie-pinned (L == seed −N: Black has no terminal-forcing strategy; the game is
   cycle-dominated — consistent with MIGOS's 2×2 footnote "either side can force a
   balanced long cycle"), so V follows TIE exactly; at TIE = ±2 the roots take ±2 —
   precisely MIGOS's documented optional configuration "Black (White) wins in case of a
   balanced long-cycle repetition" (2009 §3.2).
3. **The tie constant is inert on resolved states**: 3×3 root L==H==9 ⇒ V = 9 for every
   TIE — the L==H region's values do not depend on the tie.
4. **The 4×4 +2 cannot come from the tie value alone** (analytic, §5): with the measured
   bracket [L=+1, H=+16] / [−16, −1], V_B(TIE) = clamp(TIE,[1,16]) and V_W(TIE) =
   clamp(TIE,[−16,−1]) — the only value giving V_B = +2 is TIE = +2, at which V_W = −1
   ≠ −2. Colour inversion demands the *signed* tie (Black's cycles +2, White's −2); a
   single flat constant cannot express it. MIGOS's +2 comes from its cycle-resolution
   *rule* (pass-difference), which is a different game — and MIGOS's own basic-ko result
   is +1 = ours.

## 9. What to check next

- The 4×4 full run (TIE sweep at 4×4, ~53 min each) can be executed when the host is
  quiet, after applying the 2-char compile fix (`const`→`var`, line 1407/1568) — expected
  to confirm the analytic curve V = clamp(TIE,[1,16]) / clamp(TIE,[−16,−1]) (points at
  TIE ∈ {0, +2, −2} predicted: +1, +2, +1 and −1, −1, −2).
- The #2 auditor gate for the small-goban sweep results and the corrected register rows.
