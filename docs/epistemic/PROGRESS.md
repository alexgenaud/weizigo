# PROGRESS — the living specification of weizigo

This is the single overview document. Read it first. It is a **living
specification**: it states what we *know*, what we *need to know*, and what
we *need to build in order to know*. The ultimate goal is **provable
knowledge** — a perfect, provable account of larger and larger Go games.

It is short on detail per topic (one paragraph each) and links downward into
`../decisions/`, `../research/`, `../status/`, and leaf files. Resolution increases as
you traverse. When a claim is **proven** it is stated concisely; when **open**
it carries a `TODO` and links to the experiment that closes it.

> **Epistemic reset (2026-07-25).** Previous versions asserted "the proven
> core and brackets remain solid." That assertion is **withdrawn** — it is
> an unverified claim, not a fact. Nothing is called "proven" below unless
> its verification status is PROVEN in `../status/leak-crisis.md`. The method:
> `../about-this-document.md`.

## What the project is

`weizigo` is a provably-correct solver for small Go boards (Weiqi/Baduk),
written in Zig 0.16. The goal is a **position-to-score table** — the
game-theoretic score of every legal position for either side to move — built
by retrograde value iteration, then extended to larger boards (5×5 → 6×6 →
7×7). Published anchors matched through 4×4: 3×3 = +9, 4×4 = +2 (under
positional superko). 5×5 is known to be +25 under a simpler repetition rule
and is the next frontier. **None of these "matches" is asserted as proof of
real-game correctness until the crisis resolves; see below.**

## The rules we play under

Chinese (area) scoring, komi 0. Scores are always written **Black-positive**
(+2 = Black ends 2 ahead). The historical solving rule was **positional
superko (PSK)**, now **abandoned as the generation rule** (intractable to
solve exactly even on the empty 2×2). Tractable generation candidate is
**basic (simple) ko**; play-time can enforce any ko rule. See
`../research/ruleset-options.md`.

## The two contexts (do not conflate)

1. **Offline solving** — build the table once per board size, under one fixed
   tractable rule.
2. **Live play** — use the table in a real game, which has a *real* move
   history. The central crisis is the error of conflating them: assuming the
   offline (fresh-start) score governs the live (real-history) game.

## Per-board epistemic independence

**Each board size is its own epistemic universe.** A result at 2×2, 3×2,
3×3, or 4×4 does not imply anything about any other size unless a
monotonicity theorem is provided — and no such theorem exists here. The
project keeps an independent claim status for every size it tests.

## The central partition (canonical names — proposed, `names.md`)

Every (position, side) is labelled one of two regions. **How the label is
decided: from the FUTURE, not the past.** The L/H fixpoints are value
iteration over the forward move graph with cycle resolutions at extremes;
the label is a property of a position's future game tree. It does **not**
use the actual past moves of any game. *But* the property it claims to detect
is **past-independence** — and that claim is **falsified at 3×2 (T13, 2026-07-26)**.
The L==H scores are fresh-start exact (C1), not real-game exact.

- **The single-score region** — positions where L==H: the score was *claimed*
  history-independent (a single integer score). ~66 / 74 / 79% of slots at
  3×3 / 4×3 / 4×4. **Status: FALSE-AS-SCOPED as a real-game claim.** T13
  (2026-07-26) falsified history-independence at 3×2: reachable non-trivial PSK
  histories change the score of L==H positions. The L==H scores remain correct
  as *fresh-start* scores (C1), but they are not real-game scores and must not
  be called a "proven core". **New (2026-07-27), and the region's first
  positive property: the single-score region is *chainable*** — the history-free
  Bellman identity holds there with **zero** violations, so "take the best
  stored child value" is a defined operation inside it. **PROVEN** at 2×2 / 3×2
  / 3×3 / 4×3 (exhaustive) and 4×4 (`--sample 37`, 657,566 positions /
  1,313,248 slots on `data/oracle-4x4.checkpoint.wzo`), under both the full and
  the ADR-0006 eye-pruned move sets, via `bin/weizigo-chainability`
  (`src/chainability.zig`). **Scope caveat, carry it:** this validated the
  shipped `vb`/`vw` columns only — the WZO1 format carries no bracket columns,
  so the `lo`/`hi` form of the check is still untested — and 4×4 was a sample,
  not exhaustive. This closes FP1 acceptance check 3 in
  `boards/4x4/EPISTEMIC.md` (M4), previously listed untested.
  `../research/ko-sensitive-chainability.md`.
- **The ko-sensitive region** — positions where L<H: the score depends on
  cycle history; we ship a **ko-sensitive range `[L,H]`**, a *claimed* bound.
  ~34 / 26 / 21%. **Status: claimed bound, not proven the true range.**
  (C3 is additionally falsified at 3×3 by E2; see `../status/leak-crisis.md`.)
  **It is also not chainable — PROVEN (2026-07-27):** identity violations are
  *exactly co-extensive* with the KO_SENSITIVE flag (16/16, 72/72, 688/688,
  6,092/6,092, 11,402/11,402 at 2×2 / 3×2 / 3×3 / 4×3 / 4×4); no unflagged slot
  ever violates. Misprice rate *within* the flag spans 3.58% (4×3) to 19.51%
  (2×2) — **not monotone in board size**; 4×4 is 4.08%. Per-size table in the
  research note. **The violations are not a generation bug *in kind*** — a
  ko-sensitive slot holds an independent fresh-start PSK solve, so it owes its
  parent no agreement across a history-free edge; that much is C2 restated
  per-slot. Their *magnitude* on the committed artifact is a separate question
  and appears to include a real bug contribution: see M6 in
  `boards/4x4/EPISTEMIC.md` (writes-off 1.67% vs writes-on 4.08% at 4×4). **CLAIMED:** for
  every board with n ≥ 6 the worst misprice is exactly **2n** (12, 18, 24, 32) —
  the full board swing, since area score spans [−n, +n]; 2×2 is the exception
  (2, not 8). Four sizes, no proof, and per-board independence forbids carrying
  it to 5×5. Sampling cross-check: the tool reports the 4×4 ko-sensitive
  fraction as 21.27% against M1's exhaustive 21.32%.

The table entries are **scores** (game-theoretic area scores, Black-positive,
komi 0) — deterministic final scores under optimal play. **Not** win rates,
expectations, or probabilities. The table is the **position-to-score table**
(artifact format `.wzo`). Full naming + the naming tension in `names.md`.

## The leak crisis (the focus — read `../status/leak-crisis.md`)

The fresh-start player — which reads the table's fresh-start scores and
plays them as if they were real-game scores — **leaks** on real-game PSK
histories. On 2×2/3×2 (proven-correct fresh-start tables) the arena leak
rate is in the T06 baseline band of 8–18%. On the 4×4 parallel artifact
the **clean** leak rate (excluding games that touch an UNDEF slot) is
**3.4%**, max 32 pts, after the arena's UNDEF sentinel guard was added
(B43, 2026-07-27; `../research/arena-4x4-undef.md`). The earlier
**45.3% / 144-pt figure was a measurement artifact**: the unguarded arena
read `-128` as a real child/promise value. 32.5% of audited 4×4 games touch
a UNDEF slot and are **out of scope** of the belief audit (a UNDEF slot
holds no fresh-start belief).

We are **not asserting** whether this is a table bug, a player bug, or a
false assumption — we are separating the claims and testing each:

- **C1** fresh-start scores correct as fresh-start scores — **PROVEN** (2×2/3×2).
- **C2** single-score region is history-independent — **FALSE-AS-SCOPED at 3×2** (T13 falsified it; see `../status/leak-crisis.md`). 4×4 arena audit corroborates history-dependence at scale after the UNDEF guard (real divergence events remain; see `../research/arena-4x4-undef.md`).
- **C3** the range `[L,H]` bounds the real-game score — **FALSE-AS-SCOPED at 3×3** (E2: 50/8000 leaks, max 12 pts; `../status/leak-crisis.md`).
- **C4** fresh-start = real-game — **FALSE** for ko-sensitive (the leak refutes it); false for single-score because C2 is false.

The leak is the refutation of C4 on ko-sensitive positions. It exposes that
"proven" was being used as if it meant "proven final game score," when it
meant "proven fresh-start score." C2 and C3 — the claims that would actually
let us call something a proven final score or a true range — are **not**
established. **Resolution by reframing: the table is a fresh-start oracle, not a real-game oracle. The two decisive experiments** (in
`../status/leak-crisis.md`):

- **E1 / C2-probe:** completed 2026-07-26 (T13). C2 is **falsified**
  at 3×2: 12 L==H positions diverge under reachable non-trivial PSK
  histories. There is no "proven core" of real-game scores.
- **E2 (tests C2+C3, the sound player):** completed earlier; C3 is falsified
  at 3×3 (range-aware player leaks; see `../status/leak-crisis.md`).

**This crisis is resolved by reframing, not by more experiments.** The
strategic fork and the 5×5 build are on hold: the previous "proven real-game
score" foundation is falsified.

## The GTP player is defective on 4×4 (known problem, 2026-07-27)

`Session.choose` in `src/gtp.zig` picks its move by taking the extremum over
children's stored values — an operation that is only defined on a *chainable*
region, and on 4×4 it is almost never in one. **PROVEN (2026-07-27):** the
empty 4×4 board is itself KO_SENSITIVE (bracket [−6, +16]) and **16 of 19
plies** in both saved regression games are flagged, so the player does not
*enter* the unchainable region when a ko appears — it starts there and steers
by unchainable numbers from move one (it even prints `KO_SENSITIVE` and uses
the number anyway). **PROVEN (same two games):** positional-superko bans changed
the best available value at **0 of 19 plies** — the ko *rule* costs the engine
nothing; chaining unchainable values costs it the game, cashing out as a 32-point
(= 2n) reversal in a single ply. **CLAIMED:** the greedy extremum systematically
selects the child whose false premise is most flattering, so the B43 clean arena
leak rate (3.4%, max 32 pts, `../research/arena-4x4-undef.md`) is a **lower
bound** on the greedy player's loss rate, not an estimate of it — a falsifiable
greedy-persona-vs-random-persona arena test is designed and **not yet run**.
Full analysis, and the fork between a sound-but-mute player and a
tractable-but-unsound one, in `../research/ko-sensitive-chainability.md`;
4×4 record: `boards/4x4/EPISTEMIC.md` (M4, M5).

## One mismatch, not five problems (CLAIMED — an interpretation, not a theorem)

The leak crisis, C2, C3, C4 and the chainability collapse are plausibly all
symptoms of a single mismatch: **positional superko is a non-Markovian rule**
(legality depends on unbounded history) while the project stores a **Markovian**
position→score table for it. The table has nowhere to put the information the
rule depends on, so every "wrong value" result is really the state being the
wrong *shape*. This is an interpretation offered to organise the findings, not
a proved theorem. It also names the headline gap: PROGRESS already records
(2026-07-24) that PSK is abandoned as the generation rule and basic/simple ko
is the tractable candidate, **but the 4×4 artifact and the GTP player are both
still PSK.** Nothing here asserts that simple ko will work — the state-space
census has not been run and the long-cycle resolution rule is an unsettled
design question. Hypotheses and their falsification tests:
`../research/open-hypotheses-2026-07-27.md`.

## What we know (proven — only C1, plus proven falsifications)

- **C1:** fresh-start scores match the history-aware exact solver at 2×2/3×2.
  This says nothing about real-game scores.
- **C2:** the single-score (L==H) region is **not** history-independent;
  T13 falsified it at 3×2 (12 mismatches on 508 non-trivial histories).
  The "certified core" is fresh-start correct only.
- **Chainability (2026-07-27):** the single-score (L==H) region satisfies the
  history-free Bellman identity with **zero** violations at 2×2/3×2/3×3/4×3
  (exhaustive) and 4×4 (1:37 sample) — the shipped `vb`/`vw` columns only, not
  the `lo`/`hi` bracket tables. Violations are exactly co-extensive with the
  KO_SENSITIVE flag at every size. `bin/weizigo-chainability`;
  `../research/ko-sensitive-chainability.md`.
- **The GTP player's move rule is undefined where it mostly operates (4×4):**
  the empty board is KO_SENSITIVE and 16/19 plies of both regression games are
  flagged, while superko bans changed the best value at 0/19 plies. See above.
- The address system (colex) is a verified bijection through 4×4; position
  counts match OEIS A094777 through 4×4.
- Benson's life theorem is exhaustively falsification-confirmed at 3×3.

(Everything else — single-score history-independence, range bounds, anchor
matches as real-game truth — is CLAIMED, listed in the crisis chapter.)

## What we need to know (open)

- **`TODO` (C1 at 3×3/4×4):** writes-off regen to promote from CLAIMED to PROVEN.
  4×4 parallel artifact is 99.8% complete (83K unfilled, mostly 2-ko+).
- **`TODO` (C2 at 3×3/4×4):** untested. Falsified at 3×2 (T13), per-board
  independence prevents inheritance.
- **`TODO` (arena audit):** DONE — 4×4 parallel artifact audited with UNDEF guard
  (B43). Clean leak rate **3.4%** / max 32 pts; 32.5% of games touch UNDEF slots
  (out of scope). See `../research/arena-4x4-undef.md`.
- **`TODO` (greedy-vs-random arena):** untested. Acceptance test for the CLAIMED
  lower-bound reading of 3.4%: run a greedy-max persona and a random persona on
  the same artifact and compare leak rate and magnitude. If greedy does not leak
  more, the "flattering false premise" mechanism is falsified.
- **`TODO` (chainability, remaining scope):** the `lo`/`hi` bracket columns are
  **not** covered (WZO1 stores none) and 4×4 was a 1:37 sample; an exhaustive
  4×4 pass and an in-memory bracket-table check would close FP1 check 3 fully.
- **`TODO` (the PSK gap — headline):** the generation rule is abandoned (PSK)
  but the shipped 4×4 artifact and the GTP player are both still PSK. No
  simple-ko state-space census has been run and the long-cycle resolution rule
  is undecided; **do not assume simple ko works.**
  `../research/open-hypotheses-2026-07-27.md`, `../research/ruleset-options.md`.
- **`TODO` (which player to ship):** sound-but-mute (steer only where chainable)
  vs tractable-but-unsound (bracket cuts = C3, falsified at 3×3) vs
  bounded-history state (new ADR). User's call; fork laid out in
  `../research/ko-sensitive-chainability.md`.

## What we need to build (in order to know)

- **`TODO`:** user-chosen reframe document — **RESOLVED**. The fresh-start-only
  near-term deliverable was adopted (B05/B11). Track A 2×2/3×2 regen is complete
  (B15). 4×4 bracket-only artifact produced 2026-07-27 (T14.1). UD-1, UD-2,
  UD-3 acted on as YES (see `../../untracked/SUBAGENTS.md`). Longer-term options
  (approximate play-time rules, CGT decomposition) remain research directions,
  not blocking.
- **`TODO`:** if the reframe is "fresh-start tables": regenerate 2×2..4×4
  with the sound finisher setting and pass the #2 auditor (`../decisions/0013-sound-finisher-and-dependency-guarded-memo.md`).
  **2×2/3×2 Track A regen complete (B15, byte-identical). 4×4 parallel artifact
  99.8% complete; 83K unfilled (mostly 2-ko+).**

## Status

**2026-07-29 update (supersedes the bullets below where they conflict):**

- **Host panic + runner.** A 2026-07-29 02:37 kernel panic (a `zig build-exe
  -O Debug` blew 12.5 GB RSS) is the precedent for `tools/runner` (B-2), the
  standing RSS-guard wrapper every `zig` build goes through. Full record:
  `docs/infra/host/incident-2026-07-29.md`.
- **EXP-9 (Opus 5) done** — H5a `Session.choose` mitigation shipped
  (child-side refuse-on-divergence + settled-area fallback; a sign defect in
  the draft was found and fixed; +6.8%/genmove; acceptance 4 PARTIAL). The
  GTP-player defect below is **mitigated, CLAIMED not verified-optimal**.
- **EXP-10 / ADR-0017 (Fable 5) done** — the refutation of ADR-0015 was
  attempted and **failed**: the search-path family is not exempt (T13's 12
  pointwise mismatches at 3×2 ride the finisher's search-shaped histories).
  ADR-0015 stands, strengthened.
- **QA-018 resolved — unanimous three-seat blind review + ADR-0018.** GLM-5.2,
  DeepSeek Pro, Kimi-k2.7 all returned ADR-0015 STANDS and convicted both
  planted calibration defences. **F2 is confirmed orphaned; the finisher
  remedy is a new task, not a brackets-off regen** (which inherits the premise
  via CERTCORE-dependent seeds — ADR-0017 finding 2).
- **F2-REMEDY design (Fable 5) done** — the sound finisher is *no finisher*:
  rebuild the L/H fixpoints with `converge` on `(board, side, ko_point, passes)`
  under basic ko + constant tie `T`, then `V = median(L, T, H)` (proof-v2
  Thm 5.1, proven-as-scoped, contingent on EXP-2B). QA-026's "pin to tie"
  wording corrected to the median (v1's `L<H ⇒ V=T` was false). Design only;
  gated on EXP-2B + EXP-4. `docs/research/f2-remedy-design-2026-07-29.md`.
- **EXP-2A done / EXP-2B in flight** — QA-023 Part A (the proof) done (Fable
  5); the computational half (3×2, Minimax-m3, gated on `tools/runner`) is the
  load-bearing gate for the whole roadmap.
- **EXP-8 in flight** — the PSK-divergence harness (Kimi-k2.7); the value
  complement to EXP-1's legality result.
- **D-8 (user)** — the Orchestrator owns delegation status end-to-end
  (dispatch/claim/done), rescinding the "Orchestrator does not claim" ceremony.
- **Role reallocation (Fable-as-Dabir, user-corrected)** — Dabir=DeepSeek-Pro,
  Orcha=GLM-5.2, Auditor=Kimi-k2.7, Workers=Minimax-m3; Opus reserved for
  adversarial review, Fable for D-7 hardest reasoning. See
  `docs/infra/model-perf.md` §"Role allocation".

- **Done:** retrograde L/H engine; colex addressing; artifact format WZO1;
  GTP player; arena audit (with UNDEF guard, B43); ruleset research
  (PSK/score-on-cycle/kill-X% intractability for exact solve); scoring UI
  (ADR-0014, `src/score.zig`, `weizigo_{settled,estimate,score}` GTP commands);
  chainability audit (2026-07-27, `bin/weizigo-chainability` /
  `src/chainability.zig`) — artifact-only, no history, no reference solver.
- **In progress (focus):** the honest fresh-start-only deliverable, now re-gated
  on **EXP-2B** (the QA-023 computational half, 3×2). The 4×4 writes-off full
  artifact (F2/F3) is **no longer the path** — ADR-0018 foreclosed a
  brackets-off regen as the F2 remedy (it inherits the falsified premise via
  CERTCORE seeds); the remedy is the **F2-REMEDY median build** (above), gated
  on EXP-2B. The GTP-player defect is mitigated by EXP-9 (CLAIMED, not
  verified-optimal). Characterisation of C2/C3 leak magnitudes is secondary.
- **Resolved/falsified:** B1 fixpoint correctness; C3 false at 3×3 (E2);
  C2 false at 3×2 (T13); reframe adopted (fresh-start-only, B05/B11);
  UD-1/UD-2/UD-3 resolved as YES and acted on; FP1 acceptance check 3 **passes**
  for the shipped single-value columns (M4, 2026-07-27); the ko *rule* is
  cleared as the cause of the 4×4 regression losses (0/19 plies affected).
- **On hold:** 5×5 build and alternative reframes until the 4×4 deliverable is
  finished and the user scopes the next board size.
- **Stale, not trusted:** committed ko-sensitive single-number scores
  (`data/oracle-4x4.wzo`, small artifacts). The single-score columns are C1-
  level correct as fresh-start scores; C2 is now falsified at 3×2, so they are
  not real-game scores.

## Roadmap (the round trip) — fresh-start-only reframe adopted

The previous roadmap (5×5 → 6×6 → 7×7 full tables as provable real-game
scores) is blocked because the single-score region is not real-game correct.
B05 scopes option 1 (fresh-start tables) in detail (`untracked/B05-glm.md`
subtask 2); the project adopted it as the near-term deliverable (B05/B11).
UD-1, UD-2, and UD-3 are resolved as YES and acted on (Track A 2×2/3×2
regen complete, 4×4 bracket-only artifact produced, fresh-start-only
near-term deliverable adopted). Options 2/3 remain research directions, not
blocking.

No new board-size target is committed until the 4×4 deliverable is finished
and the user explicitly scopes the next step.

## Document map

- `boards/CONCEPTS.md` — the cross-size concept-inventory (definitions only).
- `boards/4x4/EPISTEMIC.md` — the 4×4 epistemic tree (the active focus).
- `boards/4x3/EPISTEMIC.md` — the 4×3 epistemic tree (now created).
- `names.md` — canonical names (single scores / ko-sensitive ranges).
- `../status/leak-crisis.md` — the crisis record (condensed; resolution + C2 open).
- `../research/ko-sensitive-chainability.md` — why the GTP player loses once
  there is a ko (2026-07-27); the chainability measurements and the fix fork.
- `../research/corrections-2026-07-27.md` — corrections to earlier claims.
- `../research/open-hypotheses-2026-07-27.md` — the non-Markovian-rule framing,
  the simple-ko question, and their falsification tests.
- `../about-this-document.md` — the method.
- `GLOSSARY.md` — terms.
- `../../AGENTS.md` (repo root) — agent behavior rules and foreclosures.
- `../decisions/` — ADRs (append-only). `../research/` — findings & dead-ends.
  `../status/HANDOVER.md` — session continuity. `../engine/ARCHITECTURE.md` — module map.
  `../engine/TODO.md` — legacy backlog (being superseded by this file + `../status/`).
