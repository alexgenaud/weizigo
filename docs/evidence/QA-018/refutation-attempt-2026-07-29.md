# QA-018 evidence — EXP-10 refutation attempt (Fable 5, 2026-07-29)

Verbatim source citations for ADR-0017
(`docs/decisions/0017-bracket-cut-refutation-attempt-failed.md`). Every quote
was read from the working tree on 2026-07-29. Line numbers are cited so a
fresh agent can audit drift.

## 1. The ruling (D-5) and its record

- `untracked/msg/milestone-01-ko-reframe/003-opus-to-glm.md` §"QA-018/019 — I
  am ruling" — the D-5 text quoted in ADR-0017 verbatim. Durable copy:
  `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`
  ("Decision (the ruling)").
- `untracked/msg/milestone-01-ko-reframe/DECISIONS.md` row D-5 and Residue #5
  (the 0015/0017 numbering redirect).
- Dispatch: `docs/infra/dispatch/EXP-10.md`; human gate:
  `docs/infra/dispatch/QA-018-RULING.md` ("the OVERSEER cannot review EXP-10
  … Route the verdict to a third party").

## 2. ADR-0010's premise (the claim under test)

`docs/decisions/0010-bracket-guided-finishing.md:16-18`:

> The L/H tables assign every node — certified AND ko-sensitive region, V0 and
> V1 — a score bracket that holds under ANY arrival history

and `:27-29` (item 1): bracket cutoffs "are valid under any ban set (the
bracket is), so they fire deep inside the ko-tangled opening … They carry
`ko_ref = KO_CLEAN`."

## 3. The code (what a cut actually sees)

`src/retro.zig`, working tree 2026-07-29:

- `:642-655` `ab_value_from_root` — per MTD probe: `hist.reset();
  hist.push(pos);` then `ab_solve(t, ctx, pos, to_move, 0, mid-1, mid, hist,
  …)`. **Root history = `{root}`; null-window probes.**
- `:575-577` — descent: `hist.push(&e.child); r = try ab_solve(…);
  hist.pop();`. **Arrival history at any interior node = root + search path.**
- `:542-548` — PSK ban against that history: `if
  (hist.repeatsIndex(&child)) |j| { ctx.saw_ban = true; … continue; }`.
- `:537-540` — move generation is eye-pruned (`R.is_own_eye`, ADR-0006).
- `:462` — `if (passes >= 2 or t.settled[idx]) return t.score[idx] …` —
  `settled` is the *static* property `R.is_settled` (`:227-228`), history-free
  by ADR-0004; distinct from retrograde-certified.
- `:464-472` — the cut, comment verbatim: `// bracket cut: [lo,hi] holds under
  ANY arrival history -> KO_CLEAN`. `blo == bhi` returns the stored score on
  **any** visit, independent of the window (`:469`); `bhi <= alpha0` /
  `blo >= beta0` return bounds (`:470-471`). No history condition of any kind.
- `:478-495` — memo reads. With `deps` off: unconditional reuse (`:485,491`).
  With `deps` on: `const dep = ctx.dep_map.?.get(…) orelse O.fp_zero;` —
  **seeded entries are absent from `dep_map`, get the empty fingerprint, and
  always pass `fpDisjoint`** (`:486-487,492-493`).
- `:1006-1015` — `base_cb`/`base_cw`: "The certified-only baseline" — every
  legal, defined, non-`KO_SENSITIVE`, non-`FROM_FORWARD` slot is pre-seeded.
  These are exactly the non-settled `L==H` slots.
- `:1090-1096` — `runRoot` dispatches `ab_value_from_root` (bracketed) or
  `O.value_from_root` (plain); both get `f.hist`.
- `:2407` — `var f = try RT.Finisher.init(&t, gpa, finisher_budget, true, …)`
  — the artifact-producing caller hardcodes `bracketed = true` (`QA-019`).

## 4. E2 — what it measured (the outcome claim)

`docs/status/leak-crisis.md`:

- `:9-15` — leak definition: final score vs the **strongest promise** (stored
  fresh-start score at the audited player's turns). An outcome-vs-promise
  audit, not a per-node value comparison.
- `:36` — "E2 found 3×3 leaks (25/4000 games: promise +3 → final −9, 12-pt
  leak)."
- `:76-79` — leak signature: "The +3 line becomes PSK-illegal as the game
  proceeds; Black is forced into −9."
- `:81-83` — the policies: "Black maximizes `lo[child]`; White minimizes
  `hi[child]`."
- Register rows `3x3.E2-RUN1`/`3x3.E2-RUN2` (`CLAIMS.md:287-288`): 25/4,000
  and 50/8,000, both 0.625%, max 12 pts (D-1: two runs, independent
  replication).

ADR-0017's Defence-2 analysis: a leak of this shape follows from PSK bans
breaking the *chaining* step (no legal child achieves the parent's `lo`)
without requiring any node's pointwise bracket to be wrong; E2 therefore
falsifies the outcome reading of C3, not the pointwise reading the cut needs.

## 5. T13 — the pointwise, in-family falsification

`docs/research/c2-falsification-3x2.md` (committed; probe source deleted —
`QA-022`):

- Method (`:19-43`): enumerate **PSK-legal placement-only game lines** (≤10
  ply, from every legal start position); for each line ending at an `L==H`
  slot run `retro.ab_solve` with `memo=false`, `brackets=false`, full window,
  `O.History` pre-populated with every board of the line. "Alpha-beta without
  memo and without brackets is exact."
- Result (`:15-17, 45-59`): 508 non-trivial histories, **12 mismatches**;
  fresh-start sanity 0/540.
- Contradictions (`:78-91`), all twelve verbatim in the source; the first:

      idx=314 side=B depth=9 expected=+6 got=-6  history=0 2 26 40 110 278 57 154 314

  Eight of twelve histories are rooted at index 0 (the empty board):
  idx 314, 413, 410, 459, 267, 433, 237, 273. The remaining four are rooted at
  legal positions idx 1, 2 (two lines), 4 — each with initial ban `{root}`,
  the fresh-start-root shape.

Family membership (ADR-0017 Defence 1 + 2): each history is a PSK-legal
placement line from a root with initial ban `{root}` — the exact shape
`ab_value_from_root`/`ab_solve` generate (§3). An `L==H` slot's bracket is the
point `[s,s]`, so each mismatch is a node `(P,h)` with `V(P,h) ∉ [lo,hi]`, `h`
in the search-path family. Caveat: whether every line respects the eye-pruned
generator is not re-verifiable without re-running the probe (`QA-022`).

## 6. The O1 chain and the register rows

`docs/epistemic/CLAIMS.md` (2026-07-29 working tree):

- §4.1-O1 (`:601-622`): `GLOBAL.F2 ⟵d GLOBAL.ADR0010-CUT ⟵d GLOBAL.C3`; the
  "nuance to preserve, not resolve" paragraph this ADR resolves.
- `GLOBAL.C3` (`:274`) — FALSE-AS-SCOPED (at 3×3), the conflated row;
  ADR-0017 suggests the C3-VALUE / C3-PLAY split.
- `3x2.T13` (`:270`) — PROVEN (falsification), 12/508.
- `GLOBAL.CERTCORE` (`:254`) — FALSE-AS-SCOPED; `GLOBAL.F3` (`:307`) lists
  `d:GLOBAL.CERTCORE` — the brackets-off/Track-A dependency ADR-0017's
  Horn-A sharpening rests on.
- `GLOBAL.H5c` (`:443`) — ≤3.5e5 vs >5e8 nodes, empty 4×4 root; the >5e8
  figure comes from runs with the certified-seed baseline in place (the
  Finisher always builds it, `src/retro.zig:1006-1015`), so it is a **floor**
  for a CERTCORE-clean solve.
- `GLOBAL.ADR0009-HONESTY` (`:255`) + `0009:78-89` — the honesty clause
  naming the exact leak T13 later measured.
- `QA-019` (`:530`) — `bracketed`/`memo_writes` independence.

## 7. Chain of custody

Analysis: Fable 5 (EXP-10, D-7 allocation), 2026-07-29. No engine file, no
`data/`/`artifacts/`, no ADR-0010/0015, and no `CLAIMS.md` edits were made.
Per `QA-018-RULING.md`, the verdict must be adversarially reviewed by a third
party (not the ruling's author, Opus).
