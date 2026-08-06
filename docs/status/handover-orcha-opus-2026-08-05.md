# Orchestrator handover — Opus 5 session, 2026-08-05 (evening)

Author: Opus 5, Orchestrator seat (took it from Fable 5 at `ca1a285` the same day).
Audience: the next Orcha. **STATE.md is the crash anchor; `docs/audits/2026-08-05-handover/`
(ROADMAP + LANDMARKS + EPISTEMIC-RACES) is the governing plan.** Read those first, this second —
this file is only what changed in my session. Everything is committed; the artifacts are the
handoff.

## The headline: L2 moved

**G3b is discharged** (`29477d9`) — the ruling is the final section of
`sprints/g3b-value-correctness/pass0/accept.md`. Four of the 4×4 table's correctness properties now
hold at full scale with denominators, where two did that morning. I re-ran the load-bearing check
myself rather than reading the report: `0 / 600,763,414` children not in table, `0 / 99,020,312`
reachable not in table, 239.5 s, 1124 MB — reproducing T363's figures exactly, wall time included.

**Four scope limits travel with that discharge and must be quoted wherever it is cited:** I11 at
4×4 is a **50,000-state sample of 99,133,036 (0.05%)** and the only non-exhaustive condition; the
4×3 I4 rung excludes 170,276 KO_SENSITIVE slots (WZO1 format boundary); the KO_SENSITIVE column is
still distrusted pending Track A — the checks pass *around* it; everything is fresh-start under R.

Promotions authorised (`4x4.C1`, `4x4.FP1` UNTESTED → CLAIMED; `GLOBAL.H4` text) and **executed by
T377** — nothing to PROVEN, since CLAIMED is the ceiling pending Phase 3.

## What I learned that is not obvious from the docs

1. **"Retrograde" here means sweep order, not un-play.** `src/retro.zig:19-26`: Bellman updates read
   **forward successors only**; *no un-move / un-capture code exists*. The whole key space
   `(colex, side, ko_point, passes)` is enumerated directly. So there is no backward ko
   reconstruction to get wrong — a worry I raised and then had to retract.
2. **The ko risk is the finisher, not the sweep.** Where `L == H` the value cannot depend on any
   cycle rule; where `L < H` the state is KO_SENSITIVE and its value comes from *"a forward
   fresh-start solve (oracle.zig: full history + `ko_ref` rule + eye-prune)"* — the `ko_ref` family
   whose writes-ON variant is `GLOBAL.F1` FALSE-AS-SCOPED, measured wrong on 45 of 378 slots at
   3×2. That is **3.49%** of the 4×4 table (3,455,412 of 99,133,036) and **26.45%** of 4×3. It is
   the concrete reason that column is distrusted. T380 carries it (directive D042 re-scoped the row
   after I found this).
3. **A single exact score per legal position does not exist, and that is measured, not assumed.**
   `3x2.T13` falsified C2 at 3×2: **154 of 508** reachable `L == H` slots (30.3%) have a reachable
   PSK history whose exact value differs. The bracket is not our approximation; it encodes a fact.
   And exact PSK solving is intractable at **2×2** (118,475,182 ban-set states, budget exceeded).
4. **The acceptance gate was not a gate**: 24 rows had closed `--skip-acceptance`, each with its own
   honest-sounding story for a red suite nobody owned. T369 owns the aggregate. T363 fixed red #1
   en route (the `vb_i11` target that could not compile since T346); the suite went 43/48 → 46/48
   steps, 681/685 → 691/695 tests.
5. **STATE rule 7's command is now wrong for four files.** Since `f713234`, `vb_i11`, `vb_closure`,
   `vb_mutants` and `smd1` need the `engine` module, so the bare `zig test src/<f>.zig` form fails
   with `no module named 'engine'` — loud, but it reads like a broken checkout. Rule 7 corrected.

## Two evidence regressions caught before they landed

Both found by looking at a dirty tree before committing; neither would have been caught by any gate:

- An **uncommitted partial overwrite of `findings/T366-engine-kifu.json`** — a 46-opening re-run
  about to replace the committed 132-game evidence (fA 66→46 games, 3→2 genuine losses). Restored;
  a copy preserved. This is what the never-`git add -A` rule protects.
- **T376's findings JSON is invalid** — a literal unescaped newline inside a string value at char
  372. Content intact, repair lossless. T377 owns it.

## Owed by the seat you now hold

1. **T379 (self-play trajectory consistency)** — held deliberately until T380 reports, because
   T380's ko census tells T379 where to look. The operator's invariant: a self-play game's final
   score must land inside the stored bracket of every earlier position; an escape means the table,
   the move selector, or the key is wrong. Nothing has tested new-vs-new; T366/T375 are both
   new-vs-old and both inspect one node per game.
2. **The Pro-vs-Flash token comparison** the operator asked for — races 3 and 5 are the vehicle
   (packets authored, keys sealed, ~2k tokens per lane, mechanically graded). Two consoles side by
   side; token readouts are operator-collected by protocol, so the harness structurally cannot do it.
3. **T373 (register triage Step 0)** — unblocked now. Re-base the calibration fixtures **first** or
   it wedges every console's commits.
4. **T357** still wants a quiet fleet.
5. **2026-08-12: the Flash-for-everything ruling expires.** This session's ledger supports keeping
   it — see below.

## Allocation note, on recorded behaviour

Flash ran ten rows today, all verdict pass, and the signals that matter are the ones that cost it
something: T363 declined to discharge its own sprint and reported a vacuity finding against its own
sprint's premise; T366 self-corrected a silent two-ply bug and published that its earlier numbers
were wrong; T372 found a defect in a file it was not working on; T375 disclosed its own overlap;
T376's second dispatch noticed the duplicate and stood down. Consistent weakness is **artifact
hygiene, not judgment** — four of five non-conforming findings files are Flash rows.

**The Flash-vs-Pro comparison is still not established.** The only head-to-head (T371) is confounded
because Flash authored the packets. Treat any impression as a hypothesis until races 3 and 5 run.

## Landmarks

`MILESTONES.md` is now `LANDMARKS.md`, `M<n>` → `L<n>` (operator ruling). The ID change matters
beyond taste: `M1`–`M10` are already the **mutant** IDs, and they sat twelve lines apart in
`accept.md`. Swept by enumerated file, never by pattern. As-run records were deliberately left
verbatim, including `race3/r3-p6/PACKET.md`, which says "milestone M6" and is **SHA-256-sealed** in
the packet manifest — editing it would invalidate T371's completed race. `AGENTS.md` now carries the
framing rule so every console inherits it: say which landmark a row serves, say which direction a
result cuts, and let a row that advances no landmark say so.

---

# Session close — 2026-08-06, Opus 5

The first half of this file was written mid-session. This is the rest, and it revises parts of it.

## What moved

**`L2 (proven 4×4 values)`** — G3b discharged (`29477d9`), then **amended twice**, and both
amendments are worth more than the ruling.

- **Amendment 1** — T380's F-7: `vb_closure.zig:467/:794` decoded the key-byte ko as `kb >> 1`
  where the contract says `kb >> 2`. Reachable `99,020,312 → 98,999,934`, not-root-reachable
  `112,724 → 133,102`. Verdicts unchanged at 0. **The lesson:** I had "independently verified" the
  closure figure by re-running it, and it matched exactly — *because both runs executed the same
  defective decoder*. Re-running the same instrument tests determinism, not correctness.
- **Amendment 2** — T391 adjudicated the I5 pair by a third independent route: `vb_graph` was wrong
  on every graph metric while passing (`passes == 2` successors though two passes end the game;
  quadruple→triple SCC projection, contradicting its own calibration constant). `vb_scc_4x4`, which
  produced the discharge readings, was right. Discharge unchanged. **But a third defect was found in
  the instrument that was right** — CR propagation walked component IDs descending where correctness
  needs ascending, which **fabricated the "24 natural violations" at 4×3** that T344 reported and
  T363 repeated. True reading **0**; the claim is cited in the register and T396 carries the
  withdrawal.

**Standing lesson, twice earned:** *compare the counts, not the verdicts.* Two runs of one
implementation agreeing proves determinism. Two different implementations agreeing on a **verdict**
while disagreeing on every underlying **count** is worth less than either alone — the shared `pass`
concealed three real defects.

**`L4 (the ledger is clean)`** — T373 executed triage Step 0: register **334 → 207 rows**,
`C1a ORPHANED` **10 → 0**, `C2` 14 → 11, C3 floor declared at **48**.

**`L3`** — T389: **0 bracket escapes / 1,027 engine-decision plies** in self-play; frame B
**0/1,191**. The engine never leaves its own brackets. The operator's ko hypothesis is settled: not
a new-engine defect, confirmed as the old engine's failure class.

**`L0`** — T381 played three independent engines (GNU Go, Pachi, Fuego) over 204 games:
**0 losses from claimed-won positions**. Fuego's default positional superko produced the only
tie-from-claimed, correctly resolved as ruleset mismatch. T388 mapped instrument coverage and its
cross-size differential **fired on first use** — which is how T391 started.

## What the ko investigation actually found — the narrative changed

The ko thread was aimed at the wrong target and the correction is the session's most useful result.

- **"Retrograde" means sweep order, not un-play.** `retro.zig:19-26`: Bellman updates read *forward
  successors only*; no un-move code exists. There is no backward ko reconstruction to get wrong.
- **The bracket is not about ko.** T380: 92.6% of bracket-valued positions carry zero ko shapes.
  T385 at 3×3, exact census: **93.8% of bracketed entries are ko-free anywhere** — no shape, no
  reachable ko, no ban-parent. And **nothing we tested predicts the bracket**: SCC membership is
  near-vacuous (100% of `L<H` in a non-trivial SCC — but so is 98.1% of `L==H`), and ko-reachability
  points the *wrong way*.
- **`L < H` is a value-structure property** — reachable value-*ambiguous* cycles — not a graph or ko
  property. **Ruling: the flag is renamed `BRACKETED` / `SINGLE-SCORE`**, not `CYCLE-UNDETERMINED`,
  because naming it after cycles would repeat the error being fixed. Sweep queued, unperformed
  (~27 src files, ~185 docs; file by file, never a global `sed`).
- **The KO_SENSITIVE region is NOT finisher-filled** (T380 F-8) — the current WZO2 table came from a
  pure fixpoint. I told the operator otherwise from a stale header comment; the *old checkpoint's*
  values are the distrusted ones.

## The live thread: the capture budget

The operator's idea, resisted for days and now the most promising line. **Every cycle must contain a
capture** — returning to a position requires the stone count to come back down, and only captures
do that. Bound total captures and the graph becomes a DAG; a DAG has a unique minimax value, so the
bracket cannot exist. **T387's seeded control: 135,494 back-edges in the base graph, 0 with the
budget.** Confirmed structurally.

It reaches what superko cannot: the operator's absurd games — hundreds of plies of clump-die-repeat
— *never repeat a position*, so superko never bites them.

Open: cost, and **Bellman consistency**. Budget-from-here (the operator's design, memo key
`(colex, side, ko, passes, c)`, no table growth, ~17.7M memo entries at X=8) may break the identity,
since `V(P)` consumes `V(Q, c>0)` while the table stores `V(Q, 0)`. Not hypothetical — T386 measured
that class at 80/2,748 (3×3) and 496/51,318 (4×3). T387 is measuring it.

T386 also confirmed the graft's coherence: PSK diverges from the fixpoint **only** at `L < H`, never
at `L == H`, at both sizes, and never leaves the bracket.

## Fleet lessons, all earned the hard way

1. **Claim-at-close makes every safeguard decorative.** Claim and done timestamps are identical or
   seconds apart on many rows. `holdsConflict` refuses only against an *in-progress* holder — so if
   a row is never in-progress until finished, no claim conflicts, no `holds=` bites, and the sets
   protect nothing. Three duplicate dispatches followed (T376, T389, T350); T390 fixed the guard.
2. **The operator caught every duplicate and both zombies**, not any instrument. T370 now makes
   liveness real (three states, not one useless "stale").
3. **A dirty main tree is not a valid instrument.** A binary built from it panicked; T350's suite
   run reported nine failures that T391's clean run does not show. That may retroactively explain
   part of the `--skip-acceptance, pre-existing red` history — some reds may never have existed at
   any commit. **T392 is establishing the real failing set at clean HEAD.**
4. **Duplication without a differential is two chances to be wrong.** The doctrine (one in
   production, the rest as fixtures) was half-implemented. **T395** establishes one production
   implementation per property, with a differential per pair and today's four defects seeded as the
   controls that prove each fires.

## Queue for the next seat

**T387** (capture budget) and **T392** (suite bisect) are running — both long, both nudged by
directive. **T396** absorbs the day's register rows. **T395** is the structural row and the one I'd
prioritise. **T369** (suite truth) is unblocked but should wait for T392's clean-HEAD reading.
**T357** still wants a quiet machine. Fable holds the end-game and bracketed-score hypotheses
(**T393**, **T394**) — a coherent thread; leave it whole.

**Owed rulings:** the `BRACKETED` rename sweep (approved, unscheduled); T395's demotion proposals;
whether T387's residual makes budget-from-here viable or forces the counter into the key.
