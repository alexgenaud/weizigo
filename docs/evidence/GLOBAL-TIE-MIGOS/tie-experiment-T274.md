# TIE-EXPERIMENT-T274 — does a different tie constant reproduce MIGOS's +2 at 4×4?

Task: T274 · Role: worker · Model: deepseek-v4-flash (per dispatch "You are DSFlash";
Orchestrator directive D011 addressed this seat as "deepseek-v4-pro/T274" — discrepancy
flagged for the performance ledger, managent `agent` field unchanged: `deepseek-v4-flash/T274`)
· Date: 2026-08-02

**Status: READING HALF COMPLETE · RUN HALF PENDING (Orchestrator HOLD D011).**
D011 (2026-08-02T20:40:27Z) paused the 4×4 runs: three memory-heavy jobs in flight; the
runner caps RSS per-PID, not summed across descendants; the host panicked at 12.5 GB on
2026-07-29 (`docs/infra/host/incident-2026-07-29.md`). The reading half was done under the
HOLD as directed; **no 4×4 run has been started**. See §6 for the run plan and budget.

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

## 6. Run plan and budget statement (started only after Orcha resumes T274)

**Budget (stated before starting):** 3 × ~53-min 4×4 runs ≈ 2.75 h wall + ~2 min build
each, under `tools/runner` with the default 4 GB RSS cap (observed peak 3137 MB on
2026-07-29), `--max-wall 14400 --max-cpu 28800`. Three runs: **TIE=0** (calibration /
null control — gates must read 2×2=0, 3×2=0, 3×3=+9 and root +1), **TIE=+2** (the
hypothesis value), **TIE=−2** (White-side control). If host contention or any failure
makes three impractical, the two that answer the question are TIE=0 and TIE=+2; TIE=−2 is
the White-side point and what is not reached gets reported explicitly.

**Source change per run (nothing else):** the `TIE` constant (line 41) and — to honour
"no silent writes to `data/`" — the WZO output path (line 1538), diverted to
`/tmp/weizigo/T274-tie-<v>.wzo`. `data/oracle-4x4-basicko-tie-area.wzo` is not touched.
This is I/O hygiene, not a ruleset change; the axiom set is otherwise fixed.

**Blocker found on 2026-08-02 (before any run):** `src/exp6_solve.zig` at HEAD does NOT
compile with the current toolchain (zig 0.16.0):

```
src/exp6_solve.zig:1568:17: error: expected type '*T', found '*const T'
    fp4_out.data.deinit();
```

`run_fixpoint_4x4` was refactored (T165–T167 absorption 2026-07-31 / T226 2026-08-02) to
return an owned `Fixpoint4Output`, and `main` binds it as `const fp4_out` (line 1407) then
calls the mutating `deinit`. The QA-026-era commit (eeec85c, 2026-07-29) had
`const fp4 = try run_fixpoint_4x4(...) !Fixpoint4Result` and no `.data.deinit()`, so the
+1 measurement ran structurally different code. **The fixpoint kernels are byte-identical
in semantics** (verified by diff: the refactor changed exports, comments, the return
struct and the WZO fill source, not any sweep update), so the QA-026 +1 remains the
measurement of the same game. The required fix is mechanical: `const fp4_out` →
`var fp4_out` (2 characters). The "unmodified build" null control therefore cannot run
as-is at HEAD — a finding about the tree, not about the experiment.

**Host contention:** at 22:41 a concurrent `zig build test` (not ours; another in-flight
job on this host) was consuming several cores at 100%. Our runs will be slower while it
persists; nothing was killed. This is the D011 context.

**Per HOLD:** no run has been started. `git log`-verified that the only working-tree change
to `src/exp6_solve.zig` so far is the wzo_path diversion (this document's §6 source
change, applied for the aborted-launch attempt; the TIE constant is still 0).

## 7. Findings for the register (proposed in `findings/T274-tie-experiment.json`)

1. `GLOBAL.TIE-MIGOS` — proposed **FALSE-AS-SCOPED** (mechanism refuted by primary
   sources: MIGOS's long-cycle-tie value is 0, identical to ours; MIGOS's own basic-ko
   4×4 = +1 = ours; the +2 arises from the pass-difference cycle-resolution rule, a
   different game definition). Awaiting the run half to finalise.
2. `GLOBAL.FIXPOINT-VS-SEARCH` — under aligned rules (basic ko, tie 0), weizigo fixpoint
   (+1) and MIGOS search (+1, thesis Table 5.1) **agree**; the +1-vs-+2 gap is a ruleset
   (cycle-rule) difference, so candidate (b) (a defect) is not needed to explain the gap.
   A defect hypothesis for our +1 remains live only in the standing sense (the #2 auditor
   must confirm our value for our game).
3. **Citation correction:** `4x4.ANCHOR` and `AXIOMS.md` §4 cite "thesis §6.4" for the
   4×4 +2; the correct location is thesis §5.4.1 (Table 5.1) + Appendix A §A.4.
4. **Tree finding:** `src/exp6_solve.zig` at HEAD does not compile (const/var at line
   1568/1407); the QA-026 measurement's code (eeec85c) is structurally older but
   semantically identical.

## 8. What to check next (resume plan)

1. Apply the 2-char compile fix; run TIE=0 (calibration) → expect gates 0/0/+9, root +1,
   bracket [1,16]/[−16,−1], 31 sweeps.
2. Run TIE=+2 → expect root B +2, W −1, identical bracket/sweep count.
3. Run TIE=−2 (budget permitting) → expect root B +1, W −2.
4. Finalise the findings file and this document; restore `src/exp6_solve.zig` to HEAD
   (TIE=0, original wzo path); commit; `managent done T274`.
