# PROGRESS — the living specification of weizigo

This is the single overview document. Read it first. It is a **living
specification**: it states what we *know*, what we *need to know*, and what
we *need to build in order to know*. The ultimate goal is **provable
knowledge** — a perfect, provable account of larger and larger Go games.

It is short on detail per topic (one paragraph each) and links downward into
`decisions/`, `research/`, `status/`, and leaf files. Resolution increases as
you traverse. When a claim is **proven** it is stated concisely; when **open**
it carries a `TODO` and links to the experiment that closes it.

> **Epistemic reset (2026-07-25).** Previous versions asserted "the proven
> core and brackets remain solid." That assertion is **withdrawn** — it is
> an unverified claim, not a fact. Nothing is called "proven" below unless
> its verification status is PROVEN in `status/leak-crisis.md`. The method:
> `about-this-document.md`.

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
`research/ruleset-options.md`.

## The two contexts (do not conflate)

1. **Offline solving** — build the table once per board size, under one fixed
   tractable rule.
2. **Live play** — use the table in a real game, which has a *real* move
   history. The central crisis is the error of conflating them: assuming the
   offline (fresh-start) score governs the live (real-history) game.

## The central partition (canonical names — proposed, `names.md`)

Every (position, side) is labelled one of two regions. **How the label is
decided: from the FUTURE, not the past.** The L/H fixpoints are value
iteration over the forward move graph with cycle resolutions at extremes;
the label is a property of a position's future game tree. It does **not**
use the actual past moves of any game. *But* the property it claims to detect
is **past-independence** — and that claim is **unverified** (see crisis).

- **The single-value region** — positions where L==H: the value is *claimed*
  history-independent (a single integer score). ~66 / 74 / 79% of slots at
  3×3 / 4×3 / 4×4. **Status: claimed, not proven.** Will be called "proven
  core" only if E1 passes.
- **The ko-sensitive region** — positions where L<H: the value depends on
  cycle history; we ship a **ko-sensitive range `[L,H]`**, a *claimed* bound.
  ~34 / 26 / 21%. **Status: claimed bound, not proven the true range.**

The values are **scores** (game-theoretic area scores, Black-positive,
komi 0) — deterministic final scores under optimal play. **Not** win rates,
expectations, or probabilities. The table is the **position-to-score table**
(artifact format `.wzo`). Full naming + the naming tension in `names.md`.

## The leak crisis (the focus — read `status/leak-crisis.md`)

The fresh-start player — which reads the table's fresh-start scores and
plays them as if they were real-game scores — **leaks** (under-delivers on
its own promises) in 14–46% of games, **even on tables whose fresh-start
values are proven correct** (2×2, 3×2). We are **not asserting** whether this
is a table bug, a player bug, or a false assumption — we are separating the
claims and testing each:

- **C1** fresh-start values correct as fresh-start values — **PROVEN** (2×2/3×2).
- **C2** single-value region is history-independent — **CLAIMED, unverified**.
- **C3** the range `[L,H]` bounds the real-game score — **CLAIMED, unverified**.
- **C4** fresh-start = real-game — **FALSE** for ko-sensitive (the leak refutes it); true for single-value only if C2 holds.

The leak is the refutation of C4 on ko-sensitive positions. It exposes that
"proven" was being used as if it meant "proven final game score," when it
meant "proven fresh-start score." C2 and C3 — the claims that would actually
let us call something a proven final score or a true range — are **not**
established. **Resolution = two falsifiable experiments** (in
`status/leak-crisis.md`):

- **E1 (cheap, decisive for C2):** does a single-value position ever
  *diverge* (its best achievable child value under real history differs from
  its stored value)? Zero such events ⇒ C2 supported; any such event ⇒ C2
  falsified (no proven core). Run first.
- **E2 (tests C2+C3, the sound player):** a range-aware player (maximin over
  `L`) — zero leaks ⇒ `L` is a true lower bound; any leak ⇒ C3 falsified.

**This is the project's focus until it resolves.** The strategic fork and the
5×5 build are on hold: building on unverified C2/C3 would compound an unproven
foundation.

## What we know (proven — only C1)

- **C1:** fresh-start scores match the history-aware exact solver at 2×2/3×2.
  This says nothing about real-game values.
- The address system (colex) is a verified bijection through 4×4; position
  counts match OEIS A094777 through 4×4.
- Benson's life theorem is exhaustively falsification-confirmed at 3×3.

(Everything else — single-value history-independence, range bounds, anchor
matches as real-game truth — is CLAIMED, listed in the crisis chapter.)

## What we need to know (open)

- **`TODO` (E1):** are single-value positions truly history-independent? Run
  the divergence test. `status/leak-crisis.md`.
- **`TODO` (E2):** is `L` a true lower bound on real-game scores? Run the
  range-aware zero-leak test.
- **`TODO`:** Are C2/C3 theorems (fixpoint/lattice arguments) or only
  empirical? If theorems, write the proofs; if not, E1 must run at every
  board size.
- **`TODO`:** Which generation rule is tractable AND worth shipping — or do
  we accept that only single-value scores + ko-sensitive ranges are shippable?

## What we need to build (in order to know)

- **`TODO`:** E1 instrumentation — tag each arena diverged event with the
  position's region; re-run; record counts.
- **`TODO`:** E2 — range-aware `genmove` (maximin over `L`, real-history
  superko legality); "range-aware promise" metric; run arena; record.
- **`TODO`:** Track A — regenerate 2×2..4×4 with the sound finisher setting
  and pass the #2 auditor (makes residue *fresh-start* values trustworthy;
  still not real-game values). `decisions/0013`.
- **`TODO`:** Canonical-name propagation — `names.md`.

## Status

- **Done:** retrograde L/H engine; colex addressing; artifact format WZO1;
  GTP player; arena audit; ruleset research (PSK/score-on-cycle/kill-X%
  intractable for exact solve).
- **In progress (focus):** the leak crisis — E1 (diagnostic) done; **E2 found a
  critical 3×3 leak** (range-aware player leaks on 3×3, zero on 2×2/3×2). The
  bracket may be unsound as a real-game bound; E3 (exact-solver cross-check)
  resolves it. `status/leak-crisis.md`.
- **On hold:** strategic fork; 5×5 build (until C2/C3 settle).
- **Stale, not trusted:** committed residue single-numbers
  (`data/oracle-4x4.wzo`, small artifacts). The single-value columns are C1-
  level correct as fresh-start values; their history-independence (C2) is what
  E1 tests.

## Roadmap (the round trip)

5×5 → 6×6 → 7×7, each a separate wall measured on its own (results do not
extrapolate upward). 5×5 is the largest board on which optimal play
annihilates one side (+25); from 6×6 both sides live. The provable-knowledge
horizon for full tables ends at 5×5; beyond needs local decomposition (the
query-engine / CGT direction).

## Document map

- `names.md` — canonical names (proposed; with the naming tension).
- `status/leak-crisis.md` — the crisis: claims C1–C4, verification status,
  experiments E1/E2, the classification answer.
- `about-this-document.md` — the method.
- `GLOSSARY.md` — terms (update queued behind name sign-off).
- `AGENTS.md` (repo root) — agent behavior rules and foreclosures.
- `decisions/` — ADRs (append-only). `research/` — findings & dead-ends.
  `HANDOVER.md` — session continuity. `ARCHITECTURE.md` — module map.
  `TODO.md` — legacy backlog (being superseded by this file + `status/`).
