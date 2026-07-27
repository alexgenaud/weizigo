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
  3×3 / 4×3 / 4×4. **Status: FALSE-AS-SCOPED.** T13 (2026-07-26) falsified
  history-independence at 3×2: reachable non-trivial PSK histories change the
  score of L==H positions. The L==H scores remain correct as *fresh-start*
  scores (C1), but they are not real-game scores and must not be called a
  "proven core".
- **The ko-sensitive region** — positions where L<H: the score depends on
  cycle history; we ship a **ko-sensitive range `[L,H]`**, a *claimed* bound.
  ~34 / 26 / 21%. **Status: claimed bound, not proven the true range.**
  (C3 is additionally falsified at 3×3 by E2; see `../status/leak-crisis.md`.)

The table entries are **scores** (game-theoretic area scores, Black-positive,
komi 0) — deterministic final scores under optimal play. **Not** win rates,
expectations, or probabilities. The table is the **position-to-score table**
(artifact format `.wzo`). Full naming + the naming tension in `names.md`.

## The leak crisis (the focus — read `../status/leak-crisis.md`)

The fresh-start player — which reads the table's fresh-start scores and
plays them as if they were real-game scores — **leaks** (under-delivers on
its own promises) in 14–46% of games, **even on tables whose fresh-start
scores are proven correct** (2×2, 3×2). We are **not asserting** whether this
is a table bug, a player bug, or a false assumption — we are separating the
claims and testing each:

- **C1** fresh-start scores correct as fresh-start scores — **PROVEN** (2×2/3×2).
- **C2** single-score region is history-independent — **FALSE-AS-SCOPED at 3×2** (T13 falsified it; see `../status/leak-crisis.md`).
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

## What we know (proven — only C1, plus proven falsifications)

- **C1:** fresh-start scores match the history-aware exact solver at 2×2/3×2.
  This says nothing about real-game scores.
- **C2:** the single-score (L==H) region is **not** history-independent;
  T13 falsified it at 3×2 (12 mismatches on 508 non-trivial histories).
  The "certified core" is fresh-start correct only.
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
- **`TODO` (arena audit):** test the new 4×4 parallel artifact for leaks.

## What we need to build (in order to know)

- **`TODO`:** user-chosen reframe document (e.g. fresh-start-only oracle,
  approximate play-time rules, or CGT decomposition).
- **`TODO`:** if the reframe is "fresh-start tables": regenerate 2×2..4×4
  with the sound finisher setting and pass the #2 auditor (makes
  fresh-start scores trustworthy). `../decisions/0013-sound-finisher-and-dependency-guarded-memo.md`.
  **4×4 parallel artifact produced 2026-07-27: 99.8% complete, 83K unfilled (mostly 2-ko+).**

## Status

- **Done:** retrograde L/H engine; colex addressing; artifact format WZO1;
  GTP player; arena audit; ruleset research (PSK/score-on-cycle/kill-X%
  intractable for exact solve).
- **In progress (focus):** strategic reframe after T13. C2 is false at 3×2;
  the core-only deliverable collapses as a "proven real-game score" claim.
  The active question is what honest deliverable remains.
- **Resolved/falsified:** B1 fixpoint correctness; C3 false at 3×3 (E2);
  C2 false at 3×2 (T13).
- **On hold:** strategic fork; 5×5 build (until C2/C3 settle).
- **Stale, not trusted:** committed ko-sensitive single-number scores
  (`data/oracle-4x4.wzo`, small artifacts). The single-score columns are C1-
  level correct as fresh-start scores; C2 is now falsified at 3×2, so they are
  not real-game scores.

## Roadmap (the round trip) — on hold pending reframe

The previous roadmap (5×5 → 6×6 → 7×7 full tables as provable real-game
scores) is blocked because the single-score region is not real-game correct.
B05 scopes option 1 (fresh-start tables) in detail (`untracked/B05-glm.md`
subtask 2); recommends adopting it as the near-term deliverable. Options 2/3
remain research directions, not blocking.
Possible reframes:

1. **Fresh-start tables only**: build larger fresh-start oracles, label them
   honestly as such, and ship them with a bracket for the ko-sensitive region
   (both labelled CLAIMED, not proven).
2. **Approximate / play-time rules**: abandon exact-solve as the generation
   target and build a KataGo-style configurable ruleset + bounded-history
   engine.
3. **Combinatorial game theory**: pursue local decomposition / CGT methods
   that do not rely on a global history-free table.

No new board-size target is committed until the user chooses a reframe.

## Document map

- `boards/CONCEPTS.md` — the cross-size concept-inventory (definitions only).
- `boards/4x4/EPISTEMIC.md` — the 4×4 epistemic tree (the active focus).
- `names.md` — canonical names (single scores / ko-sensitive ranges).
- `../status/leak-crisis.md` — the crisis record (condensed; resolution + C2 open).
- `../about-this-document.md` — the method.
- `GLOSSARY.md` — terms.
- `../../AGENTS.md` (repo root) — agent behavior rules and foreclosures.
- `../decisions/` — ADRs (append-only). `../research/` — findings & dead-ends.
  `../status/HANDOVER.md` — session continuity. `../engine/ARCHITECTURE.md` — module map.
  `../engine/TODO.md` — legacy backlog (being superseded by this file + `../status/`).
