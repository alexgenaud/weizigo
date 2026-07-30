# Why the GTP player loses as soon as there is a ko (4×4)

**Date:** 2026-07-27, with the **exhaustive 4×4 sweep** and the
**denominator reconciliation** added 2026-07-28. **Board:** 4×4 primarily;
2×2/3×2/3×3/4×3 measured for calibration. **Status of each claim tagged
inline.** Reproduction commands are given for every number.

**Every percentage in this document names its denominator.** Three different
denominators are in play at 4×4 and they produce three different (all correct)
ko-sensitive percentages; see **Reconciliation of the three 4×4 ko-sensitive
percentages** at the end of Measurement 1 before quoting any of them.

## The question

The oracle player loses 4×4 games in which a ko or a capture-replay occurs
(`regressions/4x4-black-win-after-ko.txt`,
`regressions/4x4-history-blunder.{gtp,sgf}`). Three candidate causes were
separated and measured:

1. the ko/superko **rule** filtering the engine's moves badly;
2. the artifact's ko-sensitive values being **wrong** (the ADR-0013
   `ko_ref >= d` bug in the committed generation);
3. the player **chaining** values that are not chainable.

(3) is the cause. (1) is measured to contribute **nothing** in these games.
(2) is neither confirmed nor needed as an explanation — the loss is fully
explained without assuming any stored value is incorrect.

## Term

**Chainable** *[project term]* — a table region is *chainable* when comparing a
position's stored value with its children's stored values is a meaningful
one-ply minimax, i.e. the history-free Bellman identity holds there:

    V0(P, side) == best_side( { V0(child, -side) } U { V1(P, -side) } )

Picking a move by "maximize/minimize the stored child value" — what
`Session.choose` in `src/gtp.zig` does — is *only* defined on a chainable
region. See `docs/epistemic/GLOSSARY.md`.

## Measurement 1 — the single-score region is chainable; the ko-sensitive region is not

Tool: `bin/weizigo-chainability` (new; `src/chainability.zig`). Reads the
artifact alone — no history, no search, no reference solver.

```
bin/weizigo-chainability artifacts/oracle-2x2.wzo
bin/weizigo-chainability artifacts/oracle-3x2.wzo
bin/weizigo-chainability artifacts/oracle-3x3.wzo
bin/weizigo-chainability artifacts/oracle-4x3.wzo
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --examples 0   # exhaustive, 2026-07-28, 87 s
```

**Denominator, stated once for the whole table.** The sweep exempts *settled*
positions (where `V0 = area_score` by definition, so the Bellman identity does
not apply) and every percentage in the table below is over the **non-settled
(position, side) slots the sweep actually checked** — *not* over all legal
slots. At 4×4 that is 48,599,962 of the 48,636,330 legal slots; the 36,368-slot
difference is exactly 18,184 settled positions × 2 sides.

| goban | n | ko-sensitive, % of **non-settled checked slots** | misprice rate *within* ko-sensitive | max \|stored − bellman\| | violations *outside* ko-sensitive |
|---|---|---|---|---|---|
| 2×2 | 4  | 77.36% | 19.51% | 2  | **0** |
| 3×2 | 6  | 41.18% | 19.05% | 12 | **0** |
| 3×3 | 9  | 35.04% | 7.91%  | 18 | **0** |
| 4×3 | 12 | 26.60% | 3.58%  | 24 | **0** |
| 4×4 | 16 | **21.33%** | 4.08%  | 32 | **0** |

**All five rows are now exhaustive.** 2×2/3×2/3×3/4×3 always were; **4×4 became
exhaustive on 2026-07-28** (the 2026-07-27 revision of this table carried a 1:37
colex-stride estimate — see the superseded-sample note below).

### The exhaustive 4×4 run (2026-07-28)

```
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --examples 0     # 87 s
  legal, non-settled:   24318165
  settled (exempt):     18184
(position, side) slots checked: 48599962
  violations, full move set:     422990
  violations, eyeprune move set: 422990
  violations under BOTH:         422990   <-- unambiguous
    of which KO_SENSITIVE-flagged: 422990
  max |stored - bellman|:        32 points
  BOTH-violation rate:           0.8704% of all checked slots
KO_SENSITIVE-flagged slots:     10367922 (21.33% of checked)
  violations WITHIN ko-sensitive: 4.08%
  violations OUTSIDE ko-sensitive: 0
verdict: PASS
```

Re-run and byte-compared 2026-07-28 before this section was written; the output
above is verbatim.

**Reading note on the tool's own labels** (the tool is not edited here): the
line `legal, non-settled: 24318165` prints the **legal** count (OEIS A094777),
*before* the settled exemption — the non-settled position count is
24,318,165 − 18,184 = **24,299,981**, and 2 × 24,299,981 = 48,599,962 is the
`slots checked` line. Read the label as "legal" and the `slots checked` line as
the actual denominator.

**PROVEN (at each size listed, on the audited artifact):**

- **Zero** identity violations outside the ko-sensitive region, at every goban
  size, under both move sets (full and ADR-0006 eye-pruned). The single-score
  (L==H) region *is* chainable. This is FP1 acceptance check 3 from
  `docs/epistemic/boards/4x4/EPISTEMIC.md`, previously listed ⬜ untested — it
  **passes exhaustively** on the committed artifacts at every size including
  4×4: **0 out-of-flag violations across all 48,599,962 checked 4×4 slots**
  (2026-07-28), no longer a sample result.
  **Scope caveat, unchanged and still load-bearing:** this checks the *shipped
  `vb`/`vw` single-value columns*. The `lo`/`hi` **bracket-table** form of FP1
  check 3 remains **untested** — WZO1 (ADR-0011) carries no bracket columns, so
  that form needs the in-memory L/H tables and no run of it exists.
- Violations are **exactly co-extensive with the KO_SENSITIVE flag**: 16/16,
  72/72, 688/688, 6,092/6,092, and at 4×4 **422,990/422,990** exhaustively.
  Every violation carries the flag; no unflagged slot ever violates.

### Reconciliation of the three 4×4 ko-sensitive percentages (2026-07-28)

Three ko-sensitive percentages for 4×4 appear across this project's documents.
**All three are arithmetically correct**; they differ only in the denominator.
The numerator 10,367,922 is common to the first two: the exhaustive sweep,
reading `fb`/`fw` bit 0 off the artifact over the **non-settled** slots, counts
exactly the 10,367,922 that the converge census counts over **all legal**
slots — i.e. it finds the same flagged slots over 36,368 fewer slots.
**Implication — now MEASURED, not inferred (2026-07-28):** none of the 36,368
settled slots carries the KO_SENSITIVE flag. This was originally recorded here
as an inference across two instruments; `bin/weizigo-chainability` was then
extended to count flags on settled slots directly, and reports **0** at 4×4
(18,184 settled positions) and **0** at 4×3 (1,634 settled positions). The
cross-instrument arithmetic and the direct count agree.

*Tool note:* the same change fixed a mislabelled output line. The counter
printed as `legal, non-settled` was incremented before the settled `continue`,
so it was the plain legal-position count (24,318,165), not the non-settled one
(24,299,981). That mislabelling is what seeded the denominator confusion this
section resolves. The tool now prints both lines separately.

| figure | numerator / denominator | what it measures |
|---|---|---|
| **21.32%** | 10,367,922 / 48,636,330 = 21.3172% | M1's converge census: ko-sensitive over **all legal (position, side) slots** |
| **21.33%** | 10,367,922 / 48,599,962 = 21.3332% | this exhaustive chainability sweep: over **non-settled slots only** (settled positions are exempt — `V0 = area_score` there by definition and the Bellman identity does not apply) |
| **21.27%** | 279,323 / 1,313,248 = 21.2696% | the **superseded** 1:37 colex-stride *sample* estimate of the same quantity as 21.33% |

48,636,330 − 48,599,962 = **36,368 = 18,184 settled positions × 2 sides**. That
one subtraction is the whole of the 21.32 / 21.33 discrepancy.

**The 21.27% row is kept, not deleted.** It is the 2026-07-27 sample estimate,
now superseded by the exhaustive run — and the agreement between them is itself
the evidence that the sampling method was sound: the sample predicted 21.27%
against an exhaustive truth of 21.33% (0.06 pp), and predicted a within-flag
misprice rate of 4.08% against an exhaustive 4.08%. Quote 21.33% (or 21.32%,
denominator stated) for the fact; quote 21.27% only as the sample's history.

**Scope: this reconciles the 4×4 row of D7 only** (`docs/epistemic/CLAIMS.md`,
discrepancy D7, "ko-sensitive fractions disagree between the census and the
chainability sweep at every size"). The **2×2 / 3×2 / 3×3 / 4×3 rows remain
unreconciled.** The settled-exemption mechanism above is the *likely* same
cause at those sizes — but that has **NOT been checked**, no settled counts for
them are quoted here, and per-goban independence (AGENTS.md) forbids treating
the 4×4 reconciliation as evidence for any other size.

**Definitional in KIND — but, on this artifact, not wholly definitional in
MAGNITUDE.** A ko-sensitive slot holds an *independent fresh-start* PSK solve:
`V0(child)` was computed as if the game restarted at `child` with an empty
history, so it is under no obligation to agree with `V0(P)` across a
history-free edge. Violations of that kind are the **C2 falsification restated
per-slot**, and a correct artifact will show them: their expected rate is
nonzero. The chainability tool's verdict line judges only the falsifiable part
(outside the flag).

But the *rate* is a different question from the *kind*, and the 4.08% above is
not all definitional. **Correction (2026-07-27):** an earlier revision of this
section headed this paragraph "**Not a bug.**" and stated that these violations
were "not evidence of a generation error." That was too strong, and Measurement
4 supersedes it. Writes-off regeneration cuts the 4×4 ko-sensitive misprice rate
from 4.08% to **1.67%** at the same stride: the floor is real and definitional,
but the committed writes-on artifact carries roughly **2.4×** it, and that excess
is CLAIMED to be the ADR-0013 `ko_ref >= d` GHI bug. The corrected statement:
*these violations are definitional in kind, so a nonzero rate is expected and is
not by itself evidence of a bug — but the rate observed on the committed
artifact appears to include a bug contribution on top of that floor.* See
Measurement 4 for the numbers, the reasoning, and what would upgrade the excess
claim from CLAIMED to PROVEN.

**The magnitude is maximal, not marginal.** For every goban with n ≥ 6 the
worst misprice equals **2n exactly** — 12, 18, 24, 32 for n = 6, 9, 12, 16.
Since the area score spans [−n, +n], the worst case is the *entire goban
swing*: the table can say "I own everything" where one ply of its own values
says "the opponent owns everything". (2×2 is the exception at 2, not 8.)
**CLAIMED** — an observed regularity across four sizes with no proof offered;
per-goban epistemic independence forbids extrapolating it to 5×5.

## Measurement 2 — the ko *rule* costs the engine nothing in these games

A depth-1 probe replaying each regression game against the artifact, comparing
the best child value over **all** legal children (`freshbest`) with the best
over children that survive the game's actual positional-superko ban set
(`histbest`):

| game | plies | plies where a PSK ban fired | plies where a ban changed the best value |
|---|---|---|---|
| `4x4-black-win-after-ko` | 19 | 1 (ply 14) | **0** |
| `4x4-history-blunder`    | 19 | 1 (ply 14) | **0** |

**PROVEN (these two games):** `histbest == freshbest` at all 19 plies of both
games. Superko removed exactly one candidate move across each entire game and
it was never the best one. Candidate cause (1) is dead: the engine is not
losing because ko legality took its moves away.

## Measurement 3 — what actually happens in the regression games

The two regressions are **the same game up to goban symmetry** through ply 17
(verified move-by-move under the vertical mirror col c ↦ 3−c), after which the
engine breaks a tied-value choice differently. Value traces are identical
throughout. White (the engine) sees:

| ply | 1–7 | 8 | 9 | 10 | 11 | 12–14 | 15 | 16 | 17–19 |
|---|---|---|---|---|---|---|---|---|---|
| stored V0 | +2 | 0 | +1 | 0 | 0 | −3 | −16 | **−16** | +16 |
| best child per table | +2 | +1 | +1 | 0 | 0 | −3 / −3 / −16 | +0 | **+16** | +16 |

- Plies 1–7 are correct and stable at the published anchor **+2**.
- **16 of 19 plies are KO_SENSITIVE-flagged, including ply 1** — the empty 4×4
  goban itself, whose bracket is [−6, +16] (L < H). On 4×4 the engine does not
  "enter" the unchainable region when a ko appears: it **starts the game there**
  and never leaves until the position is decided.
- Plies 8, 14, 15, 16 are exactly the identity violations of Measurement 1.
- Ply 16 is the collapse: stored −16 (White winning by 16) versus +16 (Black
  winning by 16) one ply down. **32 points = 2n = the full goban swing**, the
  measured worst case.

### The mechanism

`choose` takes the max/min over children's fresh-start values. Inside the
ko-sensitive region each of those values is conditioned on a premise that is
false at that point in the game ("the history is empty here"). Taking an
extremum over such values is not evaluation — and it is not unbiased noise
either: **the greedy pick systematically selects the child whose false premise
is most flattering.** The engine therefore walks the path of maximum
accumulated optimism, one independently-priced position at a time, and the
misprice cashes out in a single move when the ko finally resolves: −16 → +16.

**CLAIMED**, and it predicts something the arena does not measure: a random
arena persona samples ko-sensitive mispricings roughly uniformly, whereas a
greedy table player *seeks the largest one*. The B43 clean leak rate of
**3.4% / max 32 pts** — 123 clean leaks / **3,600 arena games**
(`arena-4x4-undef.md:62-70`, B43 TOTAL row) — is therefore a **lower bound** on
the loss rate of the greedy GTP player, not an estimate of it. Falsifiable
test: run the arena with a greedy-max persona against a random persona on the
same artifact and compare leak rate and magnitude. Not yet run.

Note also that the engine already **prints** `KO_SENSITIVE` on every one of
those plies and steers by the number anyway.

## Measurement 4 — writes-off vs writes-on: a floor, and an excess above it

**Date: 2026-07-27.** Measurement 1 swept the *committed* artifact only. Sweeping
a **Track A (`memo_writes=false`, "writes-off")** 4×4 artifact with the same tool
and the same flags separates the part of the ko-sensitive misprice rate that is
definitional from the part that is not.

The writes-off artifact is `untracked/oracle-4x4-writesoff-checkpoint.wzo`
(file dated 2026-07-27 11:31). It is **uncommitted and lives in `untracked/`**;
nothing here promotes it to `data/` or `artifacts/` (AGENTS.md: no silent writes
to artifacts).

```
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo                --sample 37 --examples 0
bin/weizigo-chainability untracked/oracle-4x4-writesoff-checkpoint.wzo --sample 37 --examples 0
```

**Denominators for this table.** "% of checked" is over the **sampled
non-settled slots** listed in the `slots checked` column (stride 37), and the
misprice rate is over the **ko-sensitive subset of those same sampled slots**.
These stay sampled deliberately: the comparison is writes-on *against*
writes-off at the *identical stride*, so both columns must use the same sampled
denominator. Do **not** substitute the exhaustive 21.33% / 4.08% of
Measurement 1 into this table — they are a different denominator and would
break the like-for-like.

| artifact | slots checked (stride 37) | ko-sensitive, % of sampled checked | misprice rate *within* sampled ko-sensitive | max \|stored − bellman\| | violations *outside* ko-sensitive |
|---|---|---|---|---|---|
| `data/oracle-4x4.checkpoint.wzo` (writes **ON** — the committed artifact) | 1,313,248 | 21.27% | **4.08%** | 32 | **0** |
| `untracked/oracle-4x4-writesoff-checkpoint.wzo` (Track A, writes **OFF**) | 1,310,854 | 21.13% | **1.67%** | 32 | **0** |

Both artifact headers declare the same 24,318,165 legal/side.

**Cross-check against the exhaustive run (2026-07-28).** The writes-ON row's
sampled 4.08% within-flag misprice rate is confirmed by the exhaustive sweep of
the same artifact, which gives 422,990 / 10,367,922 = **4.08%** over *all*
non-settled ko-sensitive slots (Measurement 1). The writes-OFF row has **no**
exhaustive counterpart — that artifact has never been swept exhaustively, and
it is in any case incomplete (Reading 3) — so the 1.67% remains a stride-37
sample figure.

**Independent confirmation at a second, coprime stride** (`--sample 997`; 997 and
37 are coprime, so the two samples overlap only at multiples of 36,889):

| artifact | sampled positions | legal | settled | slots checked | violations (full move set) | misprice rate within *sampled* ko-sensitive slots |
|---|---|---|---|---|---|---|
| writes **ON** | 24,433 | 24,413 | 20 | 48,786 | **397** | 3.81% |
| writes **OFF** | 24,423 | 24,403 | 20 | 48,699 | **152** | 1.47% |

The ratio reproduces: 4.08/1.67 = 2.44× at stride 37, 3.81/1.47 = 2.59× at
stride 997 (397/152 = 2.61× by raw violation count).

### The empty-goban root slot, by direct byte inspection (2026-07-28)

The WZO1 payload is a 32-byte header, then the `vb` column of `3^16 =
43,046,721` bytes, then `vw`, then `fb`. The empty goban is colex index 0, so
`vb[empty]` is byte offset 32, `vw[empty]` is 32 + 3^16, `fb[empty]` is
32 + 2·3^16. Read those three bytes directly (no tool, no engine):

| artifact | `vb[empty]` | `vw[empty]` | `fb` bit0 (KO_SENSITIVE) |
|---|---|---|---|
| `data/oracle-4x4.checkpoint.wzo` | **+2** | −2 | 1 |
| `data/oracle-4x4-parallel.checkpoint.wzo` | **−128 (UNDEF)** | −128 | 1 |
| `untracked/oracle-4x4-writesoff-checkpoint.wzo` | **−128 (UNDEF)** | −128 | 1 |

All three files are 258,280,358 bytes. Reproduced 2026-07-28 by byte read at
those three offsets (command under **Reproduce**).

**PROVEN (2026-07-28, by direct byte inspection):**

- **The Track A writes-off run did NOT finish.** Its root slot is UNDEF, so the
  artifact does not state a 4×4 answer. This closes the "completion
  unconfirmed" question that was open in the caveats below, in
  `boards/4x4/EPISTEMIC.md` M6, and in the F2/F3 `See M6` pointers: the answer
  is **incomplete**, not merely unverified.
- **`data/oracle-4x4-parallel.checkpoint.wzo` cannot state the 4×4 answer
  either** — its root is likewise UNDEF.
- Only `data/oracle-4x4.checkpoint.wzo` carries the published **+2** anchor at
  the root, and that is the writes-ON artifact, i.e. the one built with the
  ADR-0013-unsound `ko_ref >= d` guard.

**Methodological observation (tagged as such, not a measurement of any
artifact):** the phrasing used elsewhere in the docs for the parallel
checkpoint — "99.8% complete / 83K unfilled" — measures the wrong thing when
the unfilled slot is the root. Percentage-filled is not a fitness-for-purpose
metric: an artifact can be 99.8% filled and answer 0% of the question it was
built to answer. Fitness should be stated as "does the root (and every slot the
deliverable quotes) hold a defined value," not as a fill fraction. No other
document is edited here; the observation is recorded where it is allowed to be
recorded.

### Reading 1 — there is a definitional FLOOR, and it is not zero

**PROVEN (at 4×4, on the swept writes-off artifact):** the ko-sensitive misprice
rate does **not** go to zero when the unsound memo writes are turned off. It is
1.67% at stride 37 and 1.47% at stride 997, with the same maximal 32-point worst
case.

This is the expected behaviour, not a defect. Each ko-sensitive slot holds an
*independent fresh-start* positional-superko solve: `V0(child)` was computed as
if the game restarted at `child` with an empty history, so it owes `V0(P)` no
agreement across a history-free edge. **Zero is not the target value for a
correct artifact** — a sweep reporting 0% inside the flag would indicate the
tool, not the artifact, was wrong. This is the C2 falsification restated
per-slot (C2 is falsified at 3×2, T13 2026-07-26).

### Reading 2 — the committed artifact carries an excess above that floor (2.44× as measured; see Reading 3 for the bound)

**CLAIMED (not proven):** the excess of the committed writes-on artifact over
the writes-off floor is the ADR-0013 `ko_ref >= d` graph-history-interaction
(GHI) bug.

The reasoning: the two artifacts were produced by the same engine over the same
state space and differ in exactly one respect — whether the finisher writes
cross-branch memo entries under the `ko_ref >= d` guard. ADR-0013 proves that
guard unsound (45/378 violations at 3×2 with writes ON; **0** with writes OFF)
and predicts the damage lands precisely on ko-sensitive slots, which is where
the entire 4.08% − 1.67% excess sits: violations *outside* the flag remain **0**
on both artifacts, at both strides.

That is consistent with the bug and is what the bug predicts, but consistency is
not proof — the sweep is a one-ply identity check on stored values, and other
generation differences could in principle produce the same signature. **What
would upgrade this to PROVEN:** the #2 self-consistency auditor (`RETRO_CONSIST`),
which is the project's standing pre-commit gate per AGENTS.md and ADR-0013.
**This sweep is not a substitute for the auditor** and must not be reported as
one.

**QA-007 status (as of 2026-07-28):** *the excess above the definitional floor
is the ADR-0013 `ko_ref >= d` bug* remains **CLAIMED** — attribution to that bug
is not proven. What is now proven is that **an excess exists**: a worst-case
survivorship bound puts the effect at **≥1.63×** the writes-off floor (Reading
3), so the direction is no longer in question even though the cause is. Upgrade
path is unchanged: **`RETRO_CONSIST`** (the #2 self-consistency auditor) on both
artifacts, which is the standing pre-commit gate per AGENTS.md and ADR-0013.
Prerequisite, newly identified: a **completed** writes-off regen, since the
current writes-off artifact is confirmed incomplete (its root is UNDEF).

### Reading 3 — survivorship confound, and a worst-case bound that survives it

**The confound is real and must be stated.** The writes-off artifact is
incomplete (see the byte table above), and a retrograde build solves the deep ko
tangles *last*. Its unfilled slots are therefore exactly the hard ones — which
are plausibly also the most mispriced. Excluding them can only bias the
writes-off misprice rate **downward**. The 2.44× ratio is measured over a sample
that is not like-for-like.

**The confound is boundable.** At `--sample 37`:

- writes **ON**: 1,313,248 slots checked; 279,323 ko-sensitive; 11,402
  violations = **4.08%**.
- writes **OFF**: 1,310,854 slots checked; 276,929 ko-sensitive; 4,618
  violations = **1.67%**.
- The writes-off sample is missing **2,394 slots (0.18%)**.

Worst case — charge **every** missing slot to writes-off as a ko-sensitive
violation:

    (4,618 + 2,394) / (276,929 + 2,394) = 7,012 / 279,323 = 2.51%

**PROVEN (at 4×4, stride 37, arithmetic above):** even under the maximally
adversarial assumption, writes-off stays at **2.51% < 4.08%**. The ratio falls
from 2.44× to **1.63×** (4.08 / 2.51) but **does not invert**.

So the honest status is two-part:

- The **direction** of the writes-off/writes-on result is **robust to the
  survivorship confound** — a worst-case bound proves it. Writes-off is
  genuinely cleaner.
- The **magnitude** (2.44×) is an **over-estimate of unknown degree**. The true
  ratio lies somewhere in **[1.63×, 2.44×]**; the sweep cannot narrow it
  further, because narrowing it requires the missing slots.

### Why this is useful — a cheap sound/unsound discriminator

New capability for Track A validation: **the ko-sensitive misprice rate
discriminates sound from unsound generation using the artifact alone.** No
retrograde rebuild, no auditor run, no reference solver, no history — seconds of
CPU over a strided read of a 258 MB file. Before this, telling a writes-off
regen from the committed artifact required the auditor (which did not finish on
the 4×4 sample; see EPISTEMIC.md D3/F3). The rate is a *screen*, not a gate: it
can cheaply flag a suspect artifact and cheaply corroborate a clean one, while
the auditor remains the thing that decides.

### Caveats — all of them load-bearing

- **The writes-off run is CONFIRMED INCOMPLETE** (2026-07-28; was "completion
  NOT confirmed" in the 2026-07-27 revision). Evidence: `vb[empty]` = −128
  (UNDEF) by direct byte read at offset 32 — the empty-goban root is unsolved.
  The two artifacts differ by 2,394 filled slots at stride 37 (1,313,248 vs
  1,310,854 — 0.18%). A 0.18% shortfall cannot arithmetically explain 4.08% →
  1.67%, and Reading 3 now bounds the residual bias (worst case 2.51%, ratio
  ≥1.63×), but the comparison is **not like-for-like** and must not be reported
  as one. **The honest comparison this project actually needs is a *completed*
  writes-off regen**, swept exhaustively or at the same stride with no missing
  slots. That is now a **named blocker for F2 and F3** (`boards/4x4/
  EPISTEMIC.md`): those hypotheses are gated on the auditor *and* on a regen
  that reaches its root.
- **The writes-off artifact is uncommitted**, in `untracked/`. It has not been
  promoted to `data/` or `artifacts/`, and this note does not propose promoting
  it — promotion is gated on the auditor plus the completion check above.
- **Measurement 4's 4×4 comparison is sampled, not exhaustive** — 1:37 and
  1:997 colex strides, on both artifacts. (Measurement 1's single-artifact 4×4
  sweep *is* exhaustive as of 2026-07-28; that does not make this comparison
  exhaustive, because no exhaustive sweep of the writes-off artifact exists.)
- **Per-goban independence (AGENTS.md).** The ratio — 2.44× as measured, **[1.63×,
  2.44×]** once the incompleteness bound of Reading 3 is applied — is measured
  **at 4×4 only**. Do not carry it to 4×3, 5×5, or anywhere else; no monotonicity
  argument is offered and none is implied.

## What a fix costs — the fork

The sound play-time answer is a forward search under the game's **real**
history (`Retro.ab_solve` / `value_from_line` already implement this). The
obstacle is that soundness and tractability are on opposite sides:

- **Memo-free, bracket-free history-exact search — sound, intractable.**
  This project's own measurement: the empty 4×4 root is **>5×10⁸ nodes,
  abandoned** (`retrograde-4x4.md`, driver table). Independently re-measured
  here: empty **2×2** costs 2.3M nodes / 132 ms; empty **3×2** does not finish
  in 100 s. No cross-branch memo is available — ADR-0013 proved the
  `ko_ref >= d` guard unsound.
- **The same search with [L,H] bracket cuts — tractable, unsound.**
  ≤3.5×10⁵ nodes for the empty 4×4 root, whole ko-sensitive region in 6.1 min
  (~1,663 nodes/rep): a 1,400× win on the hardest case. But cutting on [L,H]
  under a real history *is* claim **C3**, and C3 is **FALSE-AS-SCOPED at 3×3**
  (E2: 25/4000 games leaked, promise +3 → final −9). This buys tractability
  with precisely the unsoundness that produced the leak crisis.
- **Restrict the player to what is chainable — sound, weaker.** Measurement 1
  says the L==H region is chainable with zero violations. A player that steers
  by table values only there, and by a history-free quantity elsewhere (settled
  area score / Benson-alive territory, or a history-exact search terminating at
  a Benson-settled horizon, where the value is history-free by theorem), never
  chains an unchainable value. On 4×4 this means it has no table guidance from
  move one — the honest consequence of a fresh-start-only deliverable.
- **Bounded-history state** — the representational route AGENTS.md already
  names as the way to a real-game claim. New ADR, not a bug fix.

**Open, and the user's call:** which of these the 4×4 deliverable should ship.
No engine change was made on this finding — the choice between "tractable and
unsound" and "sound and mute" is a deliverable decision, and any change to the
ko/finisher path is gated on the #2 auditor per AGENTS.md.

## Reproduce

```
zig build -Doptimize=ReleaseFast

# Measurement 1 — the EXHAUSTIVE 4×4 sweep (2026-07-28, 87 s wall)
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --examples 0

bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --sample 37 --examples 3  # superseded sample
bin/weizigo-chainability artifacts/oracle-4x3.wzo          # exhaustive, 0 outside-flag

# Measurement 4 — writes-on vs writes-off (all four runs re-reproduced 2026-07-27)
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo                --sample 37  --examples 0
bin/weizigo-chainability untracked/oracle-4x4-writesoff-checkpoint.wzo --sample 37  --examples 0
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo                --sample 997 --examples 0
bin/weizigo-chainability untracked/oracle-4x4-writesoff-checkpoint.wzo --sample 997 --examples 0
```

Empty-goban root slot, by direct byte read (2026-07-28; no engine involved):

```
python3 -c "
N=3**16
for p in ['data/oracle-4x4.checkpoint.wzo',
          'data/oracle-4x4-parallel.checkpoint.wzo',
          'untracked/oracle-4x4-writesoff-checkpoint.wzo']:
    f=open(p,'rb'); s=lambda o:(f.seek(o), (lambda b: b-256 if b>127 else b)(f.read(1)[0]))[1]
    print(p, 'vb', s(32), 'vw', s(32+N), 'fb bit0', s(32+2*N)&1)
"
```

The depth-1 history probe and the memo-free history-exact search of
Measurements 2–3 were scratch instruments, not installed; the numbers they
produced are quoted above and the artifact-independent part of the regression
(rules/capture/PSK/scoring → B+15.5) is asserted by the `zig` test
`4x4 regression: user-win B+15.5 …` in `src/gtp.zig`.

## Cross-references

- `docs/epistemic/boards/4x4/EPISTEMIC.md` — FP1 check 3 (now measured PASS
  outside the flag, **exhaustively** as of 2026-07-28, for the shipped
  `vb`/`vw` columns only); M1's 21.32% over **all legal slots** vs this sweep's
  21.33% over **non-settled slots** (reconciled at the end of Measurement 1;
  the 21.27% is the superseded 1:37 sample); **M6** (the
  Measurement 4 sound/unsound discriminator); F2/F3 (writes-off regen soundness
  at 4×4), which Measurement 4 supplies cheap corroborating evidence for
  without discharging.
- `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md` — the
  memo unsoundness that closes the tractable-and-sound door; also the claim
  that "the GTP player shares this machinery", which is **not true of the
  current `src/gtp.zig`** — it performs table lookups only and never searches.
  **Measurement 4 bears directly on ADR-0013 Track A** (`memo_writes=false`):
  it gives the first 4×4 artifact-only signal that a writes-off regen differs
  from the committed writes-on artifact in the direction and the region the ADR
  predicts (4.08% → 1.67% inside the ko-sensitive flag; 0 outside on both). It
  does **not** discharge the ADR's acceptance test — that is still the #2
  auditor (`RETRO_CONSIST`) plus bracket containment, symmetry, anchors, and
  Exact agreement — and the writes-off build is now **confirmed not to have run
  to completion** (2026-07-28; root slot UNDEF).
- `docs/research/arena-4x4-undef.md` — the 3.4% clean leak rate (123 / 3,600
  arena games) this finding argues is a lower bound for a greedy player.
- `docs/status/leak-crisis.md` — C2/C3/C4.
