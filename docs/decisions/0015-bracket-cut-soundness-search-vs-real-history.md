# ADR-0015: ADR-0010's "brackets hold under ANY arrival history" is refuted as stated — F2 stays orphaned

Status: **accepted as a ruling** (D-5 / `QA-018`, Opus, 2026-07-28) — and
**to be challenged, not ratified.** The dispatch that follows this ADR
(EXP-10, allocated to Fable under D-7) is required to *attempt to refute the
ruling below*, not to restate it. If the attempt succeeds, supersede this ADR.
Date: 2026-07-28
Supersedes: the **"Soundness status"** and **"Consequences"** sections of
ADR-0010 (`docs/decisions/0010-bracket-guided-finishing.md:70-93`). ADRs are
append-only: ADR-0010 is **not** edited, and its Decision (bracket cutoffs as a
mechanism) is not withdrawn here — only its justification and the conclusions
drawn from it.
Relates to: ADR-0009 (certification + the honesty clause), ADR-0013 (the
`ko_ref >= d` bug), `QA-018`, `QA-019`, `GLOBAL.C3`, `GLOBAL.F2`, `GLOBAL.F3`,
`CLAIMS.md` §4.1-O1.

**Filename and ownership — read this before writing another ADR on this
ruling.** `docs/infra/dispatch/EXP-10.md` (committed `175839c`) reserves
`docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` — this
file — as **Fable's** deliverable, "structured as a refutation attempt", and
its acceptance criterion 1 is that this path exists. This document was written
first, by the claims-register promotion pass, because D-5 was recorded **only**
in git-ignored `untracked/` and a `git clean -x` would have destroyed it. The two
tasks overlap and that overlap is flagged, not silently resolved:

- **This file is the ruling of record.** It states D-5 and its consequences.
- **EXP-10's refutation attempt must be filed as a new ADR (0017) that
  supersedes this one if the refutation succeeds** — not as a rewrite of this
  file. ADRs are append-only, and two agents editing one ADR is the
  one-writer-per-file failure `AGENTS.md` names.
- If the user prefers EXP-10 to own 0015 outright, this document should be
  renumbered by the user, not by either agent mid-flight.

## Context

ADR-0010:16-18 states the load-bearing premise of the entire ko-sensitive
region:

> The L/H tables assign every node … a score bracket **that holds under ANY
> arrival history** (the same structural claim as ADR-0009 certification;
> measured directly in Finding 3: every history-exact score at 2x2/3x2 fell
> inside its bracket).

and ADR-0010:27 draws the operative consequence: the cuts "are valid under any
ban set (the bracket is), so they fire deep inside the ko-tangled opening".
`src/retro.zig:464` implements it.

"The bracket holds under any arrival history" **is** claim `GLOBAL.C3` (the
`[L,H]` bracket bounds the real-game score). `GLOBAL.C3` is
**FALSE-AS-SCOPED at 3×3** since 2026-07-23: E2's range-aware self-play left the
bracket, promise +3 → final −9 against a bracket of [+2,+9]
(`docs/status/leak-crisis.md:36,66,74-79`).

The standing defence of ADR-0010 has been a scoping one: E2 falsified the
bracket under a *real game history*, whereas the finisher solves each
ko-sensitive slot as a **fresh-start root**, so the histories E2 exhibited are
outside the family the finisher ever presents to a cut. `CLAIMS.md` §4.1 records
this as "nuance to preserve, not resolve".

`QA-019` already closed the other escape route: `memo_writes=false` (ADR-0013
Track A) does **not** avoid the premise. `bracketed` and `memo_writes` are
independent switches and `saveArtifact` hardcodes `bracketed = true`
(`src/retro.zig:2407`), so the writes-off artifact is still bracket-cut
produced, and the 1.67% writes-off chainability floor is itself bracket-derived.

## Decision (the ruling)

**The scoping defence fails, and ADR-0010's justification is refuted as
stated.**

Take the finisher at an **empty-goban root**. It expands moves from the empty
position, accumulating an arrival history as it descends — that history *is a
real game line*: a legal sequence of moves from the empty goban. At depth *d*
inside that search, the node the finisher is about to cut on has arrived by a
real history, and the bracket is being asked to bound its value **under that
history**. That is not a fresh-start question; the fresh-start framing describes
how the *root* was chosen, not what the arrival history at an interior cut site
is.

Therefore **E2's falsifying histories lie inside the very family ADR-0010 claims
to cover.** E2's leaking line is a legal move sequence from the empty 3×3 goban;
the finisher's search path from the empty 3×3 root ranges over legal move
sequences from the empty 3×3 goban. The two families are not disjoint, and
ADR-0010 asserts its bracket over "ANY arrival history", which subsumes both.

Consequently:

1. **`GLOBAL.F2` (the bracket-guided finisher is sound) stays orphaned** via
   `d:GLOBAL.C3`. It is not rehabilitated by the fresh-start-root argument, and
   `CLAIMS.md` §4.1-O1 stands as computed. `QA-018`, its alias, stays orphaned
   with it.
2. **The burden is on ADR-0010 and it has not been discharged.** Anyone wishing
   to keep ADR-0010's Consequences must *prove* that the family of arrival
   histories reachable along the finisher's own search path is exempt from the
   falsification — i.e. that no bracket cut is ever taken at a node whose real
   arrival history would move the true value outside `[L,H]`. Absent that proof,
   the bracket cut is unsound as used.
3. **Nothing here is a new empirical result.** This is a ruling about an
   *argument*. It establishes that ADR-0010's justification does not support its
   conclusion; it does **not** establish that the bracket fails at 4×4, or at
   4×3, or at 2×2. `GLOBAL.C3` remains FALSE-AS-SCOPED **at 3×3** and `4x4.C3`
   remains UNTESTED. Per ADR-0016, the *argument* above is structural (it is
   about what `retro.finish` does), so it carries to every goban size; the
   *falsification* it feeds on is empirical at 3×3 and carries nowhere.

## Consequences

These replace ADR-0010's Consequences section, which assumed the premise.

- **No shipped ko-sensitive value may be quoted as sound.** Every such value at
  every goban size is bracket-cut produced. This is `AGENTS.md`'s standing
  foreclosure ("the committed ko-sensitive values are NOT trustworthy") and this
  ADR is now its justification of record.
- **The claims that stay orphaned:** `GLOBAL.F2`, `GLOBAL.F3`,
  `GLOBAL.ADR0010-CUT`, `GLOBAL.F4`, `GLOBAL.B15`, `GLOBAL.H5c`, `3x3.C1`,
  `QA-018` — eight of the ten `weizigo-claimlint` C1a orphans, one family, one
  cause.
- **Do not spend a machine-week on a writes-off regeneration.** It cannot settle
  F2/F3 (`QA-019`). The regen that *would* is **brackets-off**, which costs
  >5e8 nodes on the empty 4×4 root against ≤3.5e5 with cuts
  (`GLOBAL.H5c`, `open-hypotheses:286-291`) — three-plus orders of magnitude.
  That cost is the reason the premise was never re-examined, and naming it is
  part of the ruling.
- **ADR-0010's Decision survives as a mechanism, not as a soundness claim.**
  Bracket-guided move ordering (ADR-0010 item 2) and the aspiration window
  (item 3) are heuristics and do not depend on the premise. Only item 1, the
  **cutoff**, does.
- **The route to a real-game claim is representational, not a patch**:
  `GLOBAL.H5d` (bounded-history state) and the `QA-023` ruleset pivot. Weakening
  the bracket claim again is the failure mode `CLAIMS.md` §"repeated narrowing"
  measures — `GLOBAL.C3` has already been narrowed twice.

## What would falsify this ADR

Any one of the following discharges the burden and supersedes this ADR:

1. **A search-path exemption proof.** Show that every node at which the finisher
   takes a bracket cut has an arrival history under which `[L,H]` provably
   bounds the true value — for example, that cuts fire only at nodes whose
   arrival history cannot have removed a move by superko (a ban-set-emptiness
   argument), or that the fail-soft window makes the returned bound valid even
   when the bracket is not. This is a proof obligation about `src/retro.zig`, not
   a measurement.
2. **An exhaustive 3×3 cut-site check, on the goban where C3 is false.** Log
   every bracket cut the finisher takes over all 622 ko-sensitive orbit
   representatives at 3×3, and compare each cut's returned bound against the
   history-exact value at that node under its real arrival history. **Zero
   mismatches over every cut site would falsify this ruling as scoped to 3×3**
   and would be the first real evidence for the exemption. A single mismatch
   confirms the ruling and upgrades it from an argument to a measurement.
   Note the denominator matters: a *sample* of cut sites is not enough, because
   E2's own leak rate was 0.625% of games.
3. **A bracket re-derivation that does not require C3.** If `[L,H]` can be
   derived as a bound valid under arbitrary ban sets from the retrograde
   fixpoint alone, then ADR-0010's premise is a theorem and this ADR is wrong.
   ADR-0009's honesty clause (`GLOBAL.ADR0009-HONESTY`, `0010:70-81`) explicitly
   declines to claim this — "strong structural evidence, not a theorem" — so the
   derivation, if it exists, has never been written.

What does **not** falsify it: another measurement showing history-exact scores
falling inside their brackets at 2×2/3×2 (ADR-0010's "Finding 3"). That is the
evidence ADR-0010 already had when C3 was falsified at 3×3, and a wrong bracket
claim passes it — `4x4.BRACKET`'s wrong-answer-pass-rate is ~70%
(`claimlint-2026-07-28.md` §6). Per ADR-0016 and per-goban independence,
2×2/3×2 containment is empirical and does not carry to 3×3, let alone to 4×4.
