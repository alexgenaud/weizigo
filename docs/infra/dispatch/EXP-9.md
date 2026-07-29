<!--managent set=A-->

# EXP-9 — H5(a): play-time chainability-check mitigation (weaker-but-honest player)

**Closes:** none (a stop-gap, not a fix). **Bears on:** QA-002, the user's
"know when the play is optimal and when it's not." **Blocks:** nothing —
parallel to EXP-2/3, no new artifact, no ruleset change. **Holds:** `src/gtp.zig`
only. **Corrected per DECISIONS D-3**: a node-only check is insufficient,
and "refuse" must not mean pass.

**Read first:** `untracked/msg/milestone-01-ko-reframe/STATE.md`, then
`003-opus-to-glm.md` §"H5(a)" and §"Model allocation", then
`docs/research/ko-sensitive-chainability.md`, then `src/gtp.zig` `choose()` /
`v1_from_table`, then `src/score.zig` (`is_definitive`/`chinese_area`/
`benson_alive` — the history-free fallback).

## The problem this mitigates (not solves)

`Session.choose` takes the extremum over children's stored V0 — one ply of minimax
over the table, only an evaluation where the history-free Bellman identity holds
(L==H). In L<H (KO_SENSITIVE) the finisher overwrote each slot with an
*independent* fresh-start PSK solve, so adjacent ko-sensitive slots answer
questions under mutually inconsistent premises: the extremum **compares
incommensurable quantities** — a 32-pt hallucination. The real fix is the
ruleset/representation change (EXP-2..8). This is a play-time stop-gap that stops
the collapse now and makes the refusal the certification signal.

## The mitigation (with both D-3 corrections)

Before trusting `choose()`'s extremum, verify the one-ply Bellman identity **at
the current node AND at the chosen child** (~`2n` lookups; still cheap).

- **A1 — check the current node** `P`: `opt over children of V0(child,-s) == V0(P,s)`?
- **A2 — check the chosen child** `C*` (the move `choose` would return): the
  identity must hold at `C*` too. **This is the correction:** the identity
  holding at P certifies only that `V0(P)` agrees with its children; it says
  nothing about whether the child you move into is itself chainable. The D-3 trace:
  plies 1–7 pass, and the ply-8 failure was *created by* moves 1–7 — a node-only
  check warns after you are already in trouble. Checking the chosen child catches
  the move that *would* enter the unchainable region.

Three outcomes:

- **Both hold** (L==H, or L<H where it happens to hold — the empty 4×4 holds
  through ply 7): play the extremum as today. No strength lost.
- **Either fails** (the node or the chosen child is unchainable): **refuse to
  pick on V0.** Do **not** return the -16 child. The fallback is a
  **history-free** quantity — `chinese_area`/`is_definitive` (`src/score.zig`),
  or a Benson-alive-territory count — **sound by theorem regardless of history**,
  which is exactly the property needed. **"Refuse" must NOT mean pass**: passing
  in the opening is itself a blunder and 86% of plies 0–3 are flagged, so a
  pass-on-refusal player passes out of the opening. Pick the legal move that
  maximises the history-free fallback (e.g. the move that maximises settled area
  / own Benson-alive territory), and **log** `oracle: ... (UNCHAINABLE — refused
  V0 comparison; played <history-free fallback>)`. The refusal *is* the "this
  move is not certified optimal" signal.
- **No legal move / all children UNDEF:** existing behaviour (pass).

This is a **weaker but honest** player: optimal where the table is chainable and
visibly refuses (with a sound fallback) where it isn't.

## Acceptance

1. `zig build` clean; `zig test src/gtp.zig` 57/57 (the B+15.5 fixed-transcript
   regression is unchanged — only the engine's *live* play changes).
2. **No 32-pt collapse.** Re-run the `4x4-black-win-after-ko` Black moves with
   the engine as White (`genmove W`): at the ply where the old engine played the
   -16 child, the new engine **refuses** (logs `UNCHAINABLE`) and plays a
   history-free fallback (not pass). Handed-over margin drops from 32 toward 0.
3. **No false refusal in L==H.** On 3×3 even self-play (chainable), the identity
   holds at every node AND every chosen child; the engine never logs
   `UNCHAINABLE`; the game still ends B+9.
4. **The chosen-child check catches the ply-8 entry.** A test on the
   `4x4-black-win-after-ko` line: at ply 7 the node identity holds but the
   chosen child's does not → the engine refuses at ply 7 (not ply 8). Cite the
   trace.
5. **Cost.** Report the per-genmove added lookups (~`2n`) and wall-time hit on
   4×4. The user decides if acceptable.

## Prior near-miss (do not repeat)

H5(a) is **not** "play the bracket cut" (H5(c)) — bracket cuts are C3,
falsified at 3×3. This task *refuses* the V0 comparison and falls back to a
history-free quantity; it does not replace V0 with L or H.

## Deliverables

- `src/gtp.zig`: the node+child identity check + history-free refusal, comments
  only elsewhere.
- `docs/research/h5a-player-mitigation-2026-07-28.md`: what it does, the
  measured collapse reduction (target: 32→0 on the ko-win line), the per-genmove
  cost, the honest framing ("weaker-but-honest; optimal where chainable, visibly
  refuses with a sound fallback where not").

## Do NOT

- Do not edit the engine (`retro/oracle/rules/solve`).
- Do not cut on `[L,H]`. Do not pass on refusal. Do not claim the engine is
  "optimal" — tag the claim CLAIMED.