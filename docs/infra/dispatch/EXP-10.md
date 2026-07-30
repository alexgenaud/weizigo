<!--managent set=A caps=reasoning:sustained,independence:has-not-read-roadmap-critique-adr0015-->

# EXP-10 — QA-018/019 ADR: **refute** the D-5 ruling that ADR-0010 is refuted

**Closes:** drafts the ADR for `QA-018`/`QA-019`. **The ruling (DECISIONS D-5) is already made; this task attempts to REFUTE it.** If the refutation
succeeds, the ruling is overturned and F2 is un-orphaned; if it fails, the ADR
records the ruling as standing. **Blocks:** EXP-6 + any writes-off regen.
**Blocked by:** nothing. **Allocated per DECISIONS D-7** — the hardest
claim-semantics reasoning; an independent seat reviews adversarially and executes neither.
**Holds:** `docs/decisions/0015-*.md` (new) — docs-only.

**Read first:** `untracked/msg/milestone-01-ko-reframe/STATE.md`, then
`003-opus-to-glm.md` §"QA-018/019 — I am ruling", then `DECISIONS.md` D-5, then
`docs/epistemic/CLAIMS.md` (F2, O1, C3, ADR-0010 edges), then
`docs/decisions/0010-bracket-guided-finishing.md` and `0013-...`, then
`src/retro.zig:464` (`bracket cut: [lo,hi] holds under ANY arrival history ->
KO_CLEAN`) and `:2407` (`saveArtifact` hardcodes `bracketed = true`), then
`docs/research/c2-falsification-3x2.md` (E2 falsified C3 for *real-game*
histories).

## The ruling you must try to refute (D-5, verbatim)

> **ADR-0010's justification is refuted as stated.** Its cut rests on brackets
> holding "under ANY arrival history". For an **empty-goban root** the finisher's
> search path *is* a real game line — so E2's falsifying histories lie inside
> the very family ADR-0010 claims to cover. There is no third option: either
> "ANY arrival history" is too strong, or someone must prove the search-path
> family is exempt. **The burden is on ADR-0010 and it has not been discharged.**
> `GLOBAL.F2` stays orphaned until it is.

Note the scope: this is a claim about the *justification*, not a claim that every
shipped ko-sensitive value is wrong. Those values may well be right; what is gone
is the *argument that they must be*.

## Your job: attempt to discharge the burden — i.e. refute the ruling

An ADR that merely restates the D-5 position is worthless (D-5). You are tasked
with **finding the exemption if it exists**: is the finisher's *search-path*
history family (a fresh-start root, a single self-imposed ban set descending the
retrograde graph) genuinely **exempt** from the real-game PSK histories E2
falsified? If yes — write the proof/argument and **un-orphan F2** (overturn the
ruling). If no — the ruling stands; record it as standing with the failed
refutation as evidence.

Adjudicate both horns:

- **Horn A (ruling stands):** "ANY" over-reached; search-path and real-game
  histories are the same family (empty-goban root ⇒ search path *is* a real
  game line); C3's falsification applies; **F2 orphaned**; the only sound 4×4
  build is brackets-off (≫ cost — empty 4×4 root >5e8 nodes abandoned without
  bracket cuts vs ≤3.5e5 with).
- **Horn B (ruling overturned):** search-path histories are a strict subset / a
  different family from real-game PSK histories (arbitrary opponent arrival),
  and C3's real-game falsification does **not** transfer; F2 stands; ADR-0010 is
  reworded to "search-path arrival histories" and the finisher stands.

## Acceptance

1. `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` exists.
2. It **attempts the refutation** (Horn B) in good faith and with evidence, then
   records whether the refutation succeeded (F2 un-orphaned) or failed (ruling
   stands). It does **not** assume the conclusion.
3. It cites E2, ADR-0010, `retro.zig:464`, `retro.zig:2407`, the O1 chain, and
   states the consequence of each outcome (Horn A → brackets-off regen; Horn B →
   F2 stands, ADR-0010 reworded).
4. It ends with "Refutation succeeded/failed: …" and, if failed, "Ruling stands
   (D-5); the user owns the formal ADR promotion." If succeeded, "F2 un-orphaned
   pending independent adversarial review."
5. Auditable by a fresh agent reading only the ADR + the cited sources.

## Deliverables

- `docs/decisions/0015-*.md` (the ADR, structured as a refutation attempt).
- `docs/evidence/QA-018/` (the source citations).

## Do NOT

- Do not edit the engine, do not edit ADR-0010 (supersede, don't rewrite — the
  new ADR may supersede it once the user rules).
- Do not assert a ruling (the ruling is D-5; you attempt to refute it). Tag the
  analysis CLAIMED.
- Do not start a brackets-off regen; this ADR's outcome decides whether one is
  needed.