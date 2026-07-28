# EXP-9 — H5(a): play-time chainability-check mitigation (a weaker-but-honest player)

**Closes:** none (a stop-gap, not a fix). **Bears on:** QA-002, the user's
"know when the play is optimal and when it's not." **Blocks:** nothing.
**Blocked by:** nothing — parallel to EXP-2/3, no new artifact, no ruleset
change. **Holds:** `src/gtp.zig` only.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`msg_from_opus.md` §003 (the H5(a) proposal) and §006 (certified-fraction = 0%
in self-play; blindness is in the opening), then
`docs/research/ko-sensitive-chainability.md` (the Bellman-identity test), then
`src/gtp.zig` `choose()` and `v1_from_table`.

## The problem this mitigates (not solves)

`Session.choose` takes the extremum over children's stored V0 — one ply of
minimax over the table. That is only an evaluation where the history-free
Bellman identity `V0(P,s) = opt over children of V0(child,-s)` holds, i.e. the
L==H region. In the L<H (KO_SENSITIVE) region the finisher overwrote each slot
with an *independent* fresh-start PSK solve, so adjacent ko-sensitive slots
answer questions posed under mutually inconsistent premises: the extremum is
**comparing incommensurable quantities**, not a wrong evaluation. This is why
the engine hands over 32 points (the full-board swing) in the saved
`4x4-black-win-after-ko` game — the player greedily walks V0 children into L<H
slots and trusts their V0. See `docs/research/ko-sensitive-chainability.md`.

The real fix is the ruleset/representation change (EXP-2..8). This task is a
**play-time stop-gap** that stops the collapse *now*, with no new artifact, and
turns the refusal into the certification signal the user asked for.

## The mitigation

Before trusting `choose()`'s extremum at the current node, **verify the one-ply
Bellman identity there** (~`n` table lookups — read V0 of each legal child and
check `opt over children == stored V0(P,s)`). Three outcomes:

- **Identity holds** (L==H, or L<H where it happens to hold — the empty 4×4
  board holds through ply 7): play the extremum as today. No strength lost.
- **Identity fails** (the node is unchainable): **refuse to pick on V0.** Do
  **not** return the -16 child. Instead pass (if legal & not early-game) or pick
  a legal-only move (e.g. the one that minimises immediate loss / a capture-
  priority fallback), and **log the refusal** (`oracle: ... (UNCHAINABLE —
  refused V0 comparison)`). The refusal *is* the "this move is not certified
  optimal" signal.
- **No legal move / all children UNDEF:** existing behaviour (pass).

This is a **weaker but honest** player: it is optimal exactly where the table is
chainable and refuses (visibly) where it isn't, instead of silently
hallucinating a 32-point swing. It does **not** make the engine strong in L<H;
it stops it from being confidently wrong there.

## Acceptance

1. `zig build` clean; `zig test src/gtp.zig` 57/57 (the B+15.5 regression must
   still pass — the transcript is fixed, so its result is unchanged; only the
   *engine's* live play changes).
2. **No 32-pt collapse.** Re-run the `4x4-black-win-after-ko` Black moves with
   the engine as White (`genmove W`): at the ply where the old engine played
   the -16 child, the new engine **refuses** (logs `UNCHAINABLE`) and does
   something legal-but-not-catastrophic (pass or a non-losing move). The
   handed-over margin drops from 32 toward 0.
3. **No false refusal in L==H.** On a 3×3 even self-play (chainable), the
   identity holds at every node and the engine never logs `UNCHAINABLE`; the
   game still ends B+9. (3×3 is small enough to check the identity holds across
   the played line.)
4. **Cost is acceptable.** Report the per-genmove added lookups (≈ `n`, the
   legal-move count) and the wall-time hit on 4×4. If it doubles genmove time,
   say so — the user decides if that's fine.

## Prior near-miss (do not repeat)

H5(a) is **not** "play the bracket cut" (H5(c)) — bracket cuts are C3, falsified
at 3×3, and that path is closed. This task *refuses* the comparison; it does not
replace V0 with L or H. If you find yourself cutting on `[L,H]`, stop — that is
the falsified move.

## Deliverables

- `src/gtp.zig`: the identity check + refusal, comments only elsewhere.
- `docs/research/h5a-player-mitigation-2026-07-28.md`: what it does, the
  measured collapse reduction, the per-genmove cost, and the honest framing
  ("weaker-but-honest; optimal where chainable, visibly refuses where not").
- **Adversarial review:** route to Opus (it designed the chainability test).

## Do NOT

- Do not edit the engine (`src/retro.zig`/`oracle.zig`/`rules.zig`/`solve.zig`).
- Do not cut on `[L,H]`.
- Do not claim the engine is now "optimal" — it is honest about where it is
  *not*. Tag the claim CLAIMED, not PROVEN.