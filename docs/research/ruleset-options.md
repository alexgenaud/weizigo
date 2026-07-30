# Ruleset options — research, findings, and the plan

Motivation: full positional superko (PSK, Tromp–Taylor) is what we've been
solving, but it is (a) the hardest possible rule for an *exact* solver
(unbounded history → graph-history interaction), and (b) **not** what real
matches use. We want to support many rulesets and pick a tractable one to
*generate* perfect tables under.

## What real Go actually uses (researched 2026-07)

- **Japan / Korea (pro):** basic ko only; long cycles (triple ko, eternal
  life) → **no result**, game replayed. No superko.
- **China (pro):** basic ko + stronger anti-repetition provisions (leans toward
  prohibiting whole-goban repetition; adjudicated, not mechanical).
- **AGA / New Zealand / computer (Tromp–Taylor):** situational / positional
  superko. PSK is a *computer* convenience (mechanical, no "no result").
- **AlphaGo vs Lee Sedol / Ke Jie:** Chinese rules, 7.5 komi — **not** PSK.
- **Strong bots (AlphaGo/AlphaZero/KataGo):** sidestep the whole problem — they
  feed the net **bounded history** (~8 goban planes) plus an engine-computed
  **"illegal move" plane** (ko/superko/suicide), and the score is an
  *estimate*. They never compute exact history-dependent scores.
- **KataGo** is the model for breadth: ko ∈ {SIMPLE, POSITIONAL, SITUATIONAL},
  scoring ∈ {AREA, TERRITORY}, komi, tax — configurable, and PSK/SSK randomized
  during training. SIMPLE = basic ko + Spight-style bounded no-result
  conditions (repeat-twice-since-last-pass → no result).

**Conclusion:** superko's exact-solve difficulty is essentially a
*provable-solver* problem; approximate bots never face it. Enforcing any ko
rule during *play* is cheap; *solving* exactly under PSK is what's intractable.

## Two contexts (they are not the same rule)

- **Generation (the table):** one fixed ruleset per table; its scores are
  perfect for *that* rule only. Must be a tractable rule.
- **Play / interop:** can enforce any ko rule for legality; perfect only if the
  loaded table was generated under that same rule; otherwise approximate.

Decision: **keep every table, tagged by (size, ruleset)** — PSK small tables
stay as sanity/functional artifacts; new-rule and larger tables are separate
files (e.g. `oracle-4x4-<rule>-area.wzo`).

## Correction: bounded "N-ply superko (forbid-only)" does NOT terminate

Tempting idea — ban only the last N gobans to bound history. **Wrong:** a cycle
longer than N is then legal, so the game (and search) can loop forever. Full
PSK is used by solvers *precisely because* banning all prior gobans makes the
game finite. A bounded rule is only well-defined with a **terminal verdict on
longer cycles** (score / draw / no-result), caught via on-search-stack
detection. Under that, an N-sweep meaningfully interpolates basic-ko (N=1) →
PSK (N=∞) — but it requires choosing *what a forced cycle scores*, a real
semantic decision still open.

### RETRO_PLY — the exact N-ply sweep is intractable (the window doesn't help)

We built it anyway (RETRO_PLY): ban the last N gobans; a repeat OLDER than the
window scores as-is (terminal verdict = score-on-cycle, the well-defined choice
above). N ∈ {1,2,4,6,8} vs the PSK anchor, empty goban, 2×2 & 3×2, 200M-node
budget, 5M-entry memo cap.

**Result: EVERY row — all N including N=1 (basic ko), plus PSK — hit the node
budget with no score.** The N-ply window did NOT make the exact solve tractable.

Why (the trap, worth stating): to give a bounded rule a *terminal verdict on
longer cycles* you must **detect** those cycles, which requires remembering
**every** goban seen so far — the full history (`bans`) stays in the memo key.
So "bounded-history N-ply" is only bounded for *legality*; the *score-on-cycle
terminal* drags the whole history back in, and the state space blows up exactly
like PSK. A truly bounded exact rule needs a **move cap** instead of
score-on-cycle (game ends at ply M, scored) — but then the score depends on the
arbitrary M. There is no free lunch on the exact solver: any rule that
terminates via repetition is full-history-dependent → intractable past ~3×2.

**The only tractable home for N-ply is the RETROGRADE engine**, and only as a
bounded window *in the state* — state = (board, side, passes, last-N-window).
There, short cycles (≤ N) become explicitly illegal (removing their L/H
ambiguity) while longer cycles are still bracketed, so the ko-sensitive region would SHRINK
as N grows and pin scores at large enough N. BUT that augmented state space is
**sparse** (reachable (board, window) pairs only) — the dense colex addressing
the current engine relies on does not extend to windows — so it is a
substantial engine change with memory growing in N, not a quick probe. Deferred
as an explicit fork (see HANDOVER).

## kill-X% sanity experiment (RETRO_RULES, exact PSK solver)

A move capturing > X% of the goban's points ends the game immediately, scored
by area (the killed side cannot invade-and-cycle). Empty-goban score, exact
solver, budget 200M nodes:

| goban | kill=0 (pure PSK) | kill=50% |
|---|---|---|
| 2×2 | intractable (>200M nodes, **118M** ban-set states) | **+1**, 4795 nodes |
| 3×2 | intractable (116M states) | still intractable (125M states) |

Findings:
1. **Pure PSK is intractable by the sound exact method even on 2×2 empty** —
   definitive evidence PSK is the wrong generation target.
2. **kill-50 makes 2×2 trivial with the score UNCHANGED** (+1, matching the PSK
   retrograde table) — pathology removed, answer preserved, tractable.
3. **kill-50 is too lenient for 3×2** — captures on a 6-point goban rarely
   exceed 50%, so the rule never fires. The threshold must **scale with goban
   size** (aggressive % on tiny gobans, or an absolute-capture trigger).

Caveat: the exact solver is exponential; it is a *scores + pathology* probe,
not the generation method. Real tables must come from the **retrograde engine**
with the rule built in (polynomial in table size).

## kill-X% CENSUS at 4×4 — the decisive verdict (RETRO_KILLCENSUS, retrograde)

The exact probe above only sees tiny gobans. The real question is whether
kill-X% collapses the **4×4 ko-sensitive region** (the KO_SENSITIVE fraction the retrograde
engine cannot certify history-free). The retrograde engine is tractable at 4×4,
so a full build-only census answers it directly:

| kill_pct | ko-sensitive region / 48,636,330 | fraction | empty(B) |
|---|---|---|---|
| 0 (pure PSK) | 10,367,922 | **21.32%** | still-ko-sensitive region |
| 50% | 10,331,246 | 21.24% | still-ko-sensitive region |
| 40% | 10,521,182 | 21.63% | still-ko-sensitive region |
| 30% | 12,163,434 | **25.01%** | still-ko-sensitive region |

**Verdict: kill-X% does NOT collapse the 4×4 ko-sensitive region — it makes it WORSE.**
kill=50 barely moves it (the tangles are *small*-capture, so the rule rarely
fires); lower thresholds *fragment* the game graph with mid-game terminal
boundaries, creating MORE ko-sensitive states, not fewer. The empty goban stays
ambiguous (`still-ko-sensitive region`) at every threshold. **kill-X% is abandoned as a
ko-sensitive region-collapsing lever** (it remains a legitimate optional rule, just not a
cure for GHI). → pivot to Option B.

## Option B — basic ko + score-on-cycle (the honest scalable deliverable)

Idea: drop superko entirely. Legality = **basic ko only** (may not recreate the
goban one ply ago). The longer cycles superko used to forbid (triple ko,
eternal life) instead **end the game, scored by area as-is** at the repeated
goban.

**The theory catch (why this is not a free lunch):** "score-on-cycle-as-is" is
genuinely *path-dependent* — the score from a goban depends on *which* earlier
gobans have been seen, because re-reaching any of them ends the game. So it
CANNOT be pinned exactly by a history-free (board, side) retrograde table, for
the same reason PSK cannot. A bounded (board, side, ko-point) state fixes
*basic-ko legality* but still not the *longer-cycle* terminal. Pinning ko-sensitive region
exactly under this rule needs either full history (exact solver — intractable
past ~3×3) or a loopy-combinatorial-game solver (future work).

**What IS sound and scalable — and is therefore the deliverable:**
1. **The fresh-start single-score region (L==H).** Where L==H (~79% of 4×4),
   the fresh-start score is unique. These scores were once claimed
   rule-independent and history-independent, but T13 (2026-07-26) falsified
   history-independence at 3×2. They remain exact as *fresh-start* scores
   (C1). No finisher, no ko headache for fresh-start correctness.
2. **The honest [L,H] bracket for the ko-sensitive region.** Every ko-sensitive
   region state's fresh-start bracket is [L,H]. We ship the bracket, not a
   fragile single number. The bracket does **not** bound real PSK scores
   (C3 falsified at 3×3, E2).

### RETRO_CYCLE probe — score-on-cycle is exactly as exact-intractable as PSK

The `RETRO_CYCLE` exact probe (Exact.Ctx.cycle_score) runs the empty goban
under basic-ko + score-on-cycle side by side with pure PSK:

| goban | PSK states @200M nodes | basic+cycle states @200M nodes |
|---|---|---|
| 2×2 | 118,475,182 (budget-exceeded) | **118,475,182** (budget-exceeded) |
| 3×2 | 116,114,272 (budget-exceeded) | **116,114,272** (budget-exceeded) |

The state counts are **byte-identical** — not a coincidence, a proof of
structure: under BOTH rules a move that re-reaches an already-seen goban does
**not recurse** (PSK skips it as illegal; score-on-cycle terminates it by
area). Same recursion tree; the rules differ only in whether the repeated
goban contributes a terminal *score*. So **score-on-cycle inherits PSK's
ban-set (full-history) blowup exactly** — both are intractable on the empty
2×2, and score-on-cycle buys ZERO tractability. (3×3/4×3 rows OOM at 200M
nodes with kilobyte-scale ban-set keys, so the probe caps at 3×2; the identity
is already proven.)

**Conclusion — this is the theory wall for Option B.** score-on-cycle-as-is is
genuinely path-dependent, so:
- it CANNOT be exact-solved (needs full history — intractable past ~3×2), AND
- it CANNOT be captured by a history-free retrograde table (same reason PSK
  can't). A bounded (board, side, ko-point) state would fix basic-ko
  *legality* but not the longer-cycle *terminal*.

So the sound + scalable deliverable is the **fresh-start single-score region +
[L,H] bracket** (see below), NOT an exact score-on-cycle table. The
`RETRO_BRACKET` report produces it.

## RETRO_BRACKET — the deliverable (fresh-start single-score region + honest ko-sensitive region)

> **Epistemic update (2026-07-26):** T13 falsified C2 (history-independence
> of L==H positions) at 3×2 (12/508 mismatches). The "rule-independent
> certified core" framing is withdrawn. The L==H scores are fresh-start
> correct only (C1), not real-game correct. See `../epistemic/PROGRESS.md` and
> `../status/leak-crisis.md`.

After the retrograde L/H fixpoints converge, for every (board, side):
- **L == H → single-score.** The fresh-start score is unique (C1 correct).
  These positions were once claimed rule-independent, but T13 shows they can
  be history-dependent under real PSK play. No finisher, no ko rule, no
  history needed for *fresh-start* correctness.
- **L < H → KO-SENSITIVE.** The fresh-start bracket is [L, H]. We ship the
  bracket, not a fragile guess. The bracket does not bound real PSK scores
  (C3 falsified at 3×3).

This is the honest "perfect-4×4-partial": exact on the fresh-start single-score
region, bracketed on the rest.

Results (`RETRO_BRACKET`, no finisher):

| goban | slots | fresh-start single-score | ko-sensitive region | empty(B) bracket | known true score |
|---|---|---|---|---|---|
| 3×3 | 25,350 | 16,652 (65.7%) | 8,698 | [2, 9] w7 | +9 (PSK/vdWerf) ✓ in-bracket |
| 4×3 | 643,378 | 473,102 (73.5%) | 170,276 | [−1, 12] w13 | +4 ✓ in-bracket |
| 4×4 | 48,636,330 | 38,268,408 (78.68%) | 10,367,922 | [−6, 16] w22 | +2 (PSK/vdWerf) ✓ in-bracket |

**Soundness confirmed (but weak evidence — see erratum):** every known anchor score falls inside its bracket
(4×4 ko-sensitive count 10,367,922 matches the kill=0 census exactly — regression
check). **Critical caveat (AUDIT-REF-DSPro-2026-07-29 §1.3, `critique-2026-07-28.md:107`):**
bracket-containment is NOT soundness — a wrong answer passes this test ~42–70% of the time
(3×3: ~42%, 4×3: ~56%, 4×4: ~70%). The `4x4.BRACKET` and `3x3.BRACKET` register entries
carry these pass rates; this caption was written before the critique and overstates the
evidence. The 4×4 ko-sensitive region histogram has a **3,702,442-slot spike at width 32** =
the full [−16, 16] range: over a third of the ko-sensitive region is deep-tangle where L/H
carries zero information. The empty 4×4 bracket [−6, 16] contains the published
PSK score +2 but is 22 wide out of 32 — the single-number question is
emphatically not answered.

**Two honest caveats the numbers force us to state:**
1. The **empty-goban bracket is WIDE** (3×3 [2,9], 4×3 [−1,12]). The empty
   goban is the most cycle-entangled position, so the L/H method
   says little about *it specifically*. The fresh-start single-score
   region (66–79% of slots) is where the exact fresh-start knowledge lives.
2. Part of the ko-sensitive region has **fully-uninformative brackets** — e.g. 4×3 has
   54,388 slots at width 24 = [−12, 12] = the entire range. There the L/H
   method knows *nothing* beyond legality; those are the deep-cycle tangles.

**So the single-number question ("what is Go on 4×4, exactly, under a real
rule?") is NOT answerable by any tractable *sound* method we have.** Pinning it
needs either the exact solver (intractable past ~3×2) or a loopy-combinatorial-
game solver (Berlekamp–Conway; unbuilt, research-grade). What IS delivered,
provably: the fresh-start single-score region (C1 correct) + honest brackets
(CLAIMED, not proven as real-game bounds). That is a
legitimate partial solution, honestly bounded.

## Plan (open items, not yet committed to a table)

1. **Generation rule:** a tractable rule — leading candidate SIMPLE ko (basic
   ko + score/draw on longer cycle) + area, optionally + kill-X%. Needs the
   cycle-scoring semantics decided, then built into the retrograde engine
   (converge/finalize), not the exact DFS.
2. **kill-X%:** keep as an optional small-goban rule; the % should scale with
   goban size (or use absolute capture count). Orthogonal to the ko rule.
3. **Configurable + tagged tables:** generate per (size, ruleset); keep PSK
   tables as sanity; expose ko/scoring as config for play/interop (KataGo mold).
4. **Sub-4×4 is sanity-tier only** (per project direction); the interesting
   targets are 4×4 and 5×5 under a tractable rule.
