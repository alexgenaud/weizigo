<!--managent set=A needs=EXP-10 caps=reasoning:sustained-->

> **⚠ SUPERSEDED 2026-07-29** by the three-seat blind panel
> (`QA-018-REVIEW-A/B/C`, protocol `QA-018-REVIEW-PANEL.md`). This
> single-reviewer brief's deliverable spec (a verdict-named filename + one
> shared `PROVENANCE.md`) collides with the panel by construction. **Do not
> claim this task** — claim a panel seat. The substance below is still the
> core brief the three seats read verbatim; only the deliverable spec is
> overridden by the panel protocol §2.

# QA-018-REVIEW — third-party adversarial review of EXP-10 / ADR-0017

**Closes:** nothing directly. **Enables:** `QA-018-RULING` (the human's ruling,
which is blocked on this review, not on EXP-10 alone). **Bears on:** `QA-018`,
`QA-019`, `GLOBAL.F2`, `GLOBAL.ADR0015-BURDEN`, ADR-0010, ADR-0015, ADR-0017.

**KIND:** ANALYSIS — writes exactly one new file, modifies nothing shared, so it
parallelises with EXP-2B and EXP-8 without limit.

## The framing, which the review must carry

EXP-10 attempted to **refute** ADR-0015 (the OVERSEER's ruling that ADR-0010's
"brackets hold under ANY arrival history" is false as stated for an empty-board
root, because the finisher's search path *is* a real game line and E2's
falsifying histories lie inside the family ADR-0010 claims to cover). EXP-10
**failed** to refute it (message 025, ADR-0017): the search-path
family is not exempt — T13's 12 pointwise mismatches at 3×2 ride exactly the
finisher's search-shaped histories (8/12 empty-rooted).

Your job is **not** to re-argue ADR-0015. The ruling party cannot
review its own ruling, and the refuter cannot review its own attempt.
You are the **third party**. The question is narrower and sharper:

> **Is ADR-0017's "refutation failed" verdict sound — or did the refutation miss an
> exemption argument that would let the search-path family off the hook?**

Two outcomes, both full deliverables:

- **Verdict A — sound.** ADR-0015 stands (and is strengthened). You must name
  the *specific* exemption argument the refutation would have needed, and show why it
  fails. "I can't find an exemption either" is not enough — name what an
  exemption would have to look like and why it is unavailable.
- **Verdict B — the refutation missed something.** ADR-0015 is weakened or overturned.
  You must **write the exemption argument out** — the theorem or construction
  that separates the finisher's search-path family from the real-game
  histories that falsify the bracket. If you cannot write it, you are in
  Verdict A.

## The three findings in 025 you must adjudicate individually

Message 025 raised three findings beyond the D-5 ruling.
Grade each **SOUND / OVERSTATED / WRONG** with the reason:

1. **E2 is outcome-level, not pointwise.** That E2's leak is a policy-play
   audit, and PSK bans can break the chaining step without any node's bracket
   being wrong — so E2 alone leaves the premise unproven-but-unfalsified, and
   the *in-family pointwise* falsification (T13) is the load-bearing one.
2. **Brackets-off regen is not sufficient.** All modes read CERTCORE-dependent
   certified seeds; an empty-fingerprint pass clears `fpDisjoint` under deps,
   so a brackets-off rebuild does not escape the bracket cut by construction.
   (This bears on whether Track A *or any regen* can close F2/F3 — a strong
   claim. Check it against `src/retro.zig` read-only.)
3. **Third-party review, not the ruling party.** Procedural — you are that third party;
   confirm or qualify the requirement.

## Independence (mandatory)

You must be a **third party**: not the agent that issued ADR-0015, not
the agent that attempted the refutation. The Orchestrator
is also barred — `ORCHESTRATOR.md` "What you do not do" forbids the
Orchestrator from ruling on claim semantics. Come at ADR-0017 as a skeptic
who has not internalised ADR-0015's framing: read ADR-0017 *first*, decide
whether its "failed" verdict lands, then read ADR-0015 and check whether your
verdict survives seeing the ruling.

## Read order

1. `docs/infra/dispatch/README.md`, then `AGENTS.md`, then `DELEGATEE.md`
   (claim on start, `managent done` on finish — both required).
2. `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md` (the thing
   under review).
3. `docs/evidence/QA-018/refutation-attempt-2026-07-29.md` (the refutation attempt's verbatim
   citations).
4. `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md` (the three
   findings above, in context).
5. `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`
   (the ruling under review — read *after* 0017, per the independence rule).
6. `docs/decisions/0010-*` (the original bracket-cut ADR whose justification
   is in question) and the T13 falsification
   (`docs/research/c2-falsification-3x2.md`) for the 12 pointwise mismatches.
7. `src/retro.zig` **read-only** for finding 2 (CERTCORE / `fpDisjoint` /
   `saveArtifact`); do not edit.

## Acceptance

- A **falsifiable verdict** (A or B) with the exemption argument named and
  adjudicated, per the framing above.
- Per-finding grades (SOUND / OVERSTATED / WRONG) for the three 025 findings,
  each with the reason and, for finding 2, a `src/retro.zig:line` citation.
- **Calibration (mandatory):** state explicitly what evidence would have made
  you rule the *other* way. A reviewer with no falsifying case for their own
  verdict is doing theatre (`GLOBAL.CALIB-LESSON`).
- A one-line headline: *"ADR-0017's 'refutation failed' verdict is
  SOUND / OVERSTATED / WRONG; ADR-0015 STANDS / IS WEAKENED / IS OVERTURNED."*

## Deliverable

- `docs/evidence/QA-018/review-<verdict>-2026-07-29.md` — the verdict, the
  per-finding grades, the calibration, every citation as `file:line`, and a
  `PROVENANCE.md` per `docs/evidence/README.md`.
- A one-line status for the `CLAIMS.md` owner. **Do not edit `CLAIMS.md`,
  ADR-0017, ADR-0015, ADR-0010, or any engine file.**

## Do NOT

- Do not re-issue ADR-0015 or relitigate the original ruling — you review the
  *refutation attempt*, not the ruling.
- Do not edit `src/retro.zig` or any decision file. Read-only.
- Do not conclude "sound" by default. The standing suspicion rule
  (`DELEGATEE.md`) cuts both ways: a refutation that fails *and* a review that
  agrees it failed are both "results matching what the brief hoped for" —
  examine the failure hardest.
- Do not pool this with any other board's evidence (`AGENTS.md`, per-board
  epistemic independence). The ruling is at 3×2; it does not transfer.