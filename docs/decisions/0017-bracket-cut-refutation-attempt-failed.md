# ADR-0017: The refutation of ADR-0015 was attempted and **failed** — the search-path family is not exempt, and the ruling is strengthened

Status: **refutation attempt, concluded** (EXP-10, Fable 5, 2026-07-29).
Analysis tagged **CLAIMED** throughout, per the dispatch's own rule ("do not
assert a ruling"). The D-5 ruling stands; **the user owns the formal ADR
promotion** (`docs/infra/dispatch/QA-018-RULING.md`).
Date: 2026-07-29
Relates to: ADR-0015 (the ruling of record — **confirmed, not superseded**),
ADR-0010, ADR-0009 (honesty clause), ADR-0013 (Track A/B), ADR-0016
(empirical vs structural inheritance), `QA-018`, `QA-019`, `GLOBAL.C3`,
`GLOBAL.C2`, `GLOBAL.CERTCORE`, `GLOBAL.F2`, `GLOBAL.F3`, `CLAIMS.md` §4.1-O1.
Evidence: `docs/evidence/QA-018/refutation-attempt-2026-07-29.md`.

**Numbering note.** `docs/infra/dispatch/EXP-10.md` reserved `0015-*` for this
deliverable, but the claims-register promotion pass wrote ADR-0015 first (as
the ruling of record, to make D-5 durable) and — with `DECISIONS.md` Residue
#5 — explicitly redirected EXP-10's refutation attempt to a **new ADR**.
This file is that ADR. Had the refutation succeeded it would supersede
ADR-0015; it did not succeed, so ADR-0015 stands and this ADR records the
attempt, per EXP-10 acceptance criterion 2. If the user prefers different
numbering, the user renumbers.

## The ruling under attack (D-5, verbatim)

> **ADR-0010's justification is refuted as stated.** Its cut rests on brackets
> holding "under ANY arrival history". For an **empty-goban root** the
> finisher's search path *is* a real game line — so E2's falsifying histories
> lie inside the very family ADR-0010 claims to cover. There is no third
> option: either "ANY arrival history" is too strong, or someone must prove
> the search-path family is exempt. **The burden is on ADR-0010 and it has not
> been discharged.** `GLOBAL.F2` stays orphaned until it is.

To overturn it (Horn B of EXP-10), this ADR must show that the family of
arrival histories the finisher's own search presents to a bracket cut is
genuinely **exempt** from the falsification evidence — either by proving the
families disjoint, or by proving the bracket holds on the search-path family
even though it fails elsewhere. Anything less leaves the burden undischarged
and the ruling standing.

## The machinery, precisely (what a cut sees)

All from the working tree, verbatim excerpts in the evidence file.

- The finisher solves each ko-sensitive orbit representative as a
  **fresh-start root**: `ab_value_from_root` resets the history to exactly
  `{root}` and runs MTD null-window probes (`src/retro.zig:642-655`).
- As `ab_solve` descends, each placement child is **pushed onto the history**
  and popped on return (`src/retro.zig:575-577`); a child recreating any
  position in the history is **PSK-banned** (`hist.repeatsIndex`,
  `src/retro.zig:542-548`). So the arrival history at any interior node is
  exactly *root + search path*, with positional-superko bans enforced against
  it — the same ban-set semantics as a real game whose first position is the
  root. Move generation is eye-pruned (ADR-0006, `src/retro.zig:537-540`).
- The bracket cut (`src/retro.zig:464-472`) is a pure table lookup guarded by
  nothing but the window: `blo == bhi` returns the stored score
  **unconditionally on any visit** (`:469`); `bhi <= alpha` / `blo >= beta`
  return a bound (`:470-471`). All three return `KO_CLEAN`. No ban-relevance,
  ban-set-emptiness, or history condition exists at the cut site.
- The finisher's memo is pre-seeded with **every certified (`L==H`,
  non-settled, non-forward) value** (`base_cb`/`base_cw`,
  `src/retro.zig:1006-1015`) and these seeds are read as history-free cutoffs
  in **every mode**: unconditionally when `deps` is off
  (`src/retro.zig:485,491`), and under Track B `deps` the seed's dependency
  fingerprint defaults to **empty** (`orelse O.fp_zero`,
  `src/retro.zig:486,492`), so `fpDisjoint` always passes. `saveArtifact`'s
  caller hardcodes `bracketed = true` (`src/retro.zig:2407`; `QA-019`).

## The refutation attempt (Horn B, five defences at their strongest)

### Defence 1 — family separation: "search-path histories are a different family from real-game histories"

The strongest form: the finisher never *arrives* anywhere; it solves each slot
fresh, so E2's mid-game arrival histories are outside what a cut is asked to
cover.

**Fails, structurally.** The code above shows the search's arrival history at
an interior node is a PSK-legal move sequence from the root with initial ban
set `{root}` — precisely the definition of a real game line played from that
root. For the **empty root** the identification is total: every legal game
line from the empty goban is a candidate search path and vice versa. D-5's
core sentence is confirmed at the code level, and it extends beyond the empty
root: a fresh-start root at any position `P` with ban `{P}` generates the same
family shape. Per ADR-0016 this argument is **structural** (it is about what
`ab_solve` does) and carries to every goban size.

### Defence 2 — claim semantics: "E2 falsified a different claim than the one the cut needs"

This is the strongest genuine finding of the attempt, and it is recorded here
even though it does not rescue ADR-0010.

The cut's premise is **pointwise**: at node `P` with arrival history `h`, the
history-exact optimal value `V(P,h)` lies in `[lo(P), hi(P)]`. E2
(`leak-crisis.md:36,68-79`) measured something else: a **policy outcome** —
range-aware self-play (Black maximizes `lo[child]`, White minimizes
`hi[child]`) finished at −9 against a root bracket [+2,+9]. That falsifies
"the root bracket bounds the final score of range-aware play". It does **not
exhibit any node** where `V(P,h)` leaves `[lo(P), hi(P)]`: the pointwise claim
does not imply the outcome claim, because the chaining step ("some legal child
achieves the parent's `lo`") fails exactly when PSK bans remove the achieving
move — the very mechanism `GLOBAL.E2-VERDICT` names. A policy player can
wander to −9 with every bracket along the way being correct. So, strictly,
**E2 alone would leave the pointwise premise unproven-but-unfalsified**, and
D-5's sentence "E2's falsifying histories lie inside the very family ADR-0010
claims to cover" would name histories that falsify the wrong claim.

**The repair is immediate, and it is fatal to Horn B.** T13
(`docs/research/c2-falsification-3x2.md:76-95`) exhibits exactly the pointwise
violations E2 does not: **12 verified mismatches** between the stored `L==H`
score and the history-exact `ab_solve` value (`memo=false, brackets=false`)
under **reachable PSK-legal placement-only lines** at 3×2 — e.g. idx=314,
Black to move, stored **+6**, history-exact **−6** under history
`0 2 26 40 110 278 57 154 314`. Eight of the twelve lines are rooted at
**index 0, the empty goban**; the other four are rooted at a legal position
`P` with initial ban `{P}` — both shapes are *literally the finisher's own
search-path family* under Defence 1's identification. An `L==H` slot has the
point bracket `[s,s]`, so each mismatch is a node where `V(P,h) ∉ [lo,hi]`
with `h` **inside the search-path family**. The premise "brackets hold under
ANY arrival history" is therefore not merely undischarged on that family — it
is **falsified on it, at 3×2, in its `L==H` specialization** (which is both
the `blo==bhi` cut at `src/retro.zig:469` and the certified-seed memo read).

Net effect: the ruling's *evidence citation* is corrected (T13, not E2,
carries the in-family pointwise falsification), and its *conclusion* is
strengthened from "burden undischarged" to "burden undischarged, and the
proposed exemption is already false in the sub-case where it was testable".

Caveats, stated honestly: (i) T13's probe source is deleted
(`QA-022`); its method and all 12 counterexamples are committed in
`c2-falsification-3x2.md`, but whether each arrival line respects the
eye-pruned move generator cannot be re-verified without re-running the probe.
(ii) The falsification is **empirical at 3×2** and does not carry to any other
goban (ADR-0016); what carries is the structural family identification and the
death of the universal "ANY arrival history" claim — a universal falsified at
3×2 is false.

### Defence 3 — dynamics: "cuts may never fire at the violated nodes"

Perhaps alpha-beta's actual visit pattern avoids every `(P,h)` where the
bracket fails. **No structural support exists.** The cut is an unguarded table
lookup; the `blo==bhi` return fires on *any* visit regardless of window; the
MTD driver probes null windows `(mid−1, mid)`, making window cuts fire at
essentially every node whose bracket sits weakly on one side of `mid`; and the
certified seeds fire unconditionally in every mode (see machinery). Whether a
wrong cut value ever *changed a shipped root score* remains a legitimate open
measurement — ADR-0015's falsifier 2, the exhaustive cut-site check — but as
an *argument* this defence is circular: the visit pattern is shaped by the
cuts whose soundness is in question.

### Defence 4 — fail-soft: "the returned bound is valid even when the bracket is not"

False by inspection. If `V(P,h) > hi(P)` the cut at `:470` returns `hi` as an
upper bound that is not an upper bound; if `lo==hi` and `V(P,h) ≠` the stored
score, the "exact" return is wrong outright — T13's instances are wrong by 12
points. No window arithmetic repairs a wrong bound.

### Defence 5 — "the bans are self-imposed, so the search family is benign"

The dispatch's own phrasing ("a single self-imposed ban set descending the
retrograde graph") suggests the searcher's bans might be weaker than an
opponent's. This confuses the **searcher** with the **players**: once the
search stands at `(P,h)`, the ban set constrains both players' continuations
below `P` identically to a real game with history `h`. ADR-0009's honesty
clause (`0009:78-89`) names precisely this leak — the achieving strategy may
need to recreate a position *the opponent* created earlier, or the seed
position itself, and those moves are PSK-banned. The clause declined to claim
the theorem in 2026-07-21; T13 measured its failure in 2026-07-26.

## Verdict

**The refutation fails.** No defence discharges the burden; Defence 2 corrects
the ruling's evidence chain and in doing so closes the last escape route:
Horn B's proposed rewording of ADR-0010 to "search-path arrival histories" is
not available, because that restricted claim is itself falsified at 3×2 by
T13's empty-goban-rooted counterexamples. `GLOBAL.F2` stays orphaned via the
O1 chain (`CLAIMS.md` §4.1-O1: `F2 ⟵d ADR0010-CUT ⟵d C3`); `QA-018` stays
orphaned with it.

## Consequences of each horn (as adjudicated)

- **Horn B (did not obtain):** would have un-orphaned `GLOBAL.F2`, reworded
  ADR-0010 to the search-path family, and superseded ADR-0015. Recorded here
  only so a future reader knows it was genuinely attempted, not strawmanned.
- **Horn A (obtains):** ADR-0015's consequences stand, with one **material
  sharpening this ADR adds**: a "brackets-off regen" is **not sufficient** for
  soundness. The finisher in every mode — legacy, writes-off (Track A), and
  deps (Track B) — still reads the certified `L==H` seeds as history-free
  cutoffs (machinery above), and their history-freeness is `GLOBAL.CERTCORE`,
  **FALSE-AS-SCOPED at 3×2 by the same T13 evidence** (`GLOBAL.F3` already
  lists `d:GLOBAL.CERTCORE`). The configuration T13 itself had to use to get
  true values was `memo=false, brackets=false`. The >5e8-node cost quoted for
  the empty 4×4 root (`GLOBAL.H5c`) was measured **with seeds on**; a
  CERTCORE-clean solve has no certified frontier to terminate on and costs
  strictly more. This further forecloses regen-as-rescue and further favours
  the representational route ADR-0015 already names (`GLOBAL.H5d`, the
  `QA-023` ruleset pivot).
- Unchanged from ADR-0015: nothing here shows any shipped value **is** wrong.
  The 3×3 anchors pinned and matched; `GLOBAL.C3`-pointwise remains UNTESTED
  at 3×3/4×4 as a pointwise matter; this ADR, like the ruling, is about the
  **justification**.

## Suggested register edits (owners', not this agent's)

- `GLOBAL.C3` currently conflates the pointwise and outcome readings. Suggest
  splitting: `C3-VALUE` (pointwise; FALSE-AS-SCOPED **at 3×2 on L==H slots**
  via `3x2.T13`; UNTESTED for `L<H`) and `C3-PLAY` (outcome under range-aware
  play; FALSE-AS-SCOPED at 3×3 via E2). The cut needs `C3-VALUE`.
- `GLOBAL.ADR0015-BURDEN`: add `e:3x2.T13` (the in-family pointwise
  falsification) alongside the E2 edges.
- New row for this ADR (e.g. `GLOBAL.ADR0017-REFUTE`, CLAIMED): the refutation
  attempt failed; Track A/B both read CERTCORE-dependent seeds.

## What would still falsify this ADR

1. ADR-0015's falsifier 2 (exhaustive 3×3 cut-site check) — unchanged, still
   the decisive measurement for *fired* cuts.
2. A re-run of the T13 probe showing its 12 lines all violate the eye-pruned
   move generator — this would void the in-family strengthening (Defence 2's
   repair) and demote this ADR back to ADR-0015's burden-only position. It
   would **not** revive Horn B, which still fails on Defences 1 and 3–5.
3. ADR-0015's falsifier 1 (a search-path exemption proof) is **dead as
   scoped** for the `L==H` case — one does not prove a falsified claim — and
   survives only in the narrowed form "no *fired* cut site is ever violated",
   which is falsifier 1 collapsed into falsifier 2.

**Refutation failed: the search-path history family is not exempt — it is the
family in which the premise was falsified.** Ruling stands (D-5); the user
owns the formal ADR promotion.
