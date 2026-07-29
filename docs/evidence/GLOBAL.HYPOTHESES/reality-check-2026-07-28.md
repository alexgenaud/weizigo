Task: EXP-15 · Role: worker · Model: Kimi K2.7 · Date: 2026-07-28

# EXP-15 — `docs/research/open-hypotheses-2026-07-27.md` reality check

**Commit used as "now":** `eebe3c2` (per dispatch brief).

**Scope.** For each hypothesis H1..H5 and the sub-hypotheses listed in `docs/research/open-hypotheses-2026-07-27.md`, report the current state, a one-line verdict, and a one-line evidence pointer. No source document is edited in this task; the input docs remain unchanged.

**Calibration check.** The chainability finding (zero identity violations outside the KO_SENSITIVE flag at every measured size) is **CLOSED** by a committed measurement. Any reality-check table that tags that finding as OPEN would be using a different definition of "closed" than the project. This check is met: H4b below is tagged CLOSED.

---

## Per-hypothesis table

| id | hypothesis (one line) | verdict | evidence pointer | remediation |
|---|---|---|---|---|
| **H1** | The simple-ko pivot: PSK is non-Markovian while the table is Markovian; under simple ko + long-cycle ties the state `(position, side, ko_point)` would be chainable by construction. | **OPEN** | The interpretation is recorded in `docs/research/open-hypotheses-2026-07-27.md:30-118` and `docs/epistemic/PROGRESS.md:169-183`; the addressing census is closed below, but no simple-ko table or long-cycle rule has been built. | Dispatch a 2×2/3×2 simple-ko + long-cycle-ties retrograde pilot to test whether the existing converge machinery can pin loops to a tie value without reintroducing score-on-cycle. |
| **H1-CENSUS** | Reachable `(position, ko_point, side)` triple count at 4×4 under basic ko determines whether dense addressing fits the budget. | **CLOSED** | EXP-3 (Minimax-m3, 2026-07-28): `docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt` + `PROVENANCE.md`; write-up `docs/research/kostate-census-2026-07-28.md`. | Update `docs/research/open-hypotheses-2026-07-27.md` H1 experiment block to say GO/NO-GO is CLOSED and point to the census; update `docs/epistemic/boards/4x4/EPISTEMIC.md` `[T07-9]` D3 placeholder to the measured ≤ 354 MB figure. |
| **H1-LONGCYCLE** | "Long cycle = tie" is a loopy-game fixpoint computable by the existing converge machinery. | **OPEN** | `docs/research/open-hypotheses-2026-07-27.md:92-103` flags this as the unsettled design question; `docs/epistemic/CLAIMS.md` `GLOBAL.LONGCYCLE` is UNTESTED. | Derive or falsify a fixed-value cycle terminal before any simple-ko generation build starts; the constraint is that it must not need to know which earlier boards were seen. |
| **H2** | The greedy GTP player's loss rate strictly exceeds the arena's random-persona clean leak rate (3.4% / max 32 pts). | **OPEN** | The test is designed in `docs/research/open-hypotheses-2026-07-27.md:122-166`; the B43 measurement lives in `docs/research/arena-4x4-undef.md`; no greedy-vs-random run has been performed. | Run `bin/weizigo-arena data/oracle-4x4-parallel.checkpoint.wzo 100` and the same with `det` on the same artifact/seed set; compare CLEAN-LEAK rate and max leak magnitude. |
| **H3** | There is an empty-point count below which memo-free, bracket-free, history-exact 4×4 search under real history is affordable at play time. | **OPEN** | `docs/research/open-hypotheses-2026-07-27.md:170-214`; the lower-bound probe in `docs/research/ko-sensitive-chainability.md:269-274` used a linear history scan and no `zobrist.zig` / `scount`/`armed` prune. | Build a proper instrumented search (new file; no `src/retro.zig`/`oracle.zig`/`rules.zig`/`solve.zig` edit) using Zobrist + `scount`/`armed`; measure median wall time vs empty points on the two saved regression games. |
| **H4** | FP1 acceptance check 3 (V0/V1 Bellman identity) has residual gaps: `lo`/`hi` bracket form untested and 4×4 was sampled. | **IN PROGRESS** | Parent hypothesis in `docs/research/open-hypotheses-2026-07-27.md:217-261`; gap (a) remains open, gap (b) is now closed (see H4b). | Close H4a by folding it into the next scheduled 4×4 writes-off regen (F2/F3); update the H4 doc text to split the two gaps clearly. |
| **H4a** | V0/V1 identity holds on the in-memory `Retro(4,4).Tables.lo`/`.hi` quads (WZO1 stores no bracket columns). | **OPEN** | `docs/research/open-hypotheses-2026-07-27.md:224-228,233-235`; `docs/epistemic/CLAIMS.md` `GLOBAL.H4a` is UNTESTED. | Run the chainability identity directly against in-memory L/H tables after a 4×4 retrograde build; do not schedule a separate build just for this check. |
| **H4b** | Exhaustive (stride 1) chainability sweep at 4×4 over all non-settled slots. | **CLOSED** | `bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --examples 0` ran 2026-07-28 (87 s); recorded in `docs/research/ko-sensitive-chainability.md` Measurement 1, `docs/epistemic/boards/4x4/EPISTEMIC.md` M4, and `docs/epistemic/CLAIMS.md` `QA-021`. | Update `docs/research/open-hypotheses-2026-07-27.md` H4 to remove the "4×4 was a 1:37 sample" caveat and point to the exhaustive run; refresh `4x4.M4` row wording in `docs/epistemic/CLAIMS.md` and `docs/epistemic/boards/4x4/EPISTEMIC.md`. |
| **H5** | The GTP player can be made to stop asserting mispriced numbers without resolving any open epistemic question. | **OPEN** | `docs/research/open-hypotheses-2026-07-27.md:265-313`; no option has been selected or implemented. | The choice between H5a (sound-but-mute), H5b (history-exact horizon), and H5d (bounded-history ADR) is the user's; H5c is already rejected. |
| **H5a** | Restrict table steering to the chainable L==H region; sound but weak (empty 4×4 is itself KO_SENSITIVE). | **OPEN** | Premise proven by `GLOBAL.CHAIN-LH` (`docs/research/ko-sensitive-chainability.md:60-69`); weakness proven by `4x4.M5` (`docs/epistemic/boards/4x4/EPISTEMIC.md:199-205`); D-3 child-check and fallback conditions are not implemented (`docs/research/corrections-2026-07-27.md:99-132`). | Implement the guard in `src/gtp.zig`: check the Bellman identity at the chosen child (not only the current node) and fall back to a history-free quantity (settled area / Benson territory) when the check fails. |
| **H5b** | History-exact search to a Benson-settled horizon is sound (settled area is history-free by theorem). | **OPEN** | `docs/research/open-hypotheses-2026-07-27.md:281-284`; gated on H3's crossover number. | Dispatch after H3 delivers the crossover; build the player by terminating history-exact search once the position is Benson-settled. |
| **H5c** | Bracket-cut search is tractable but unsound because cutting on `[L,H]` under real history is claim C3. | **REJECTED** | `GLOBAL.C3` is FALSE-AS-SCOPED at 3×3 (`docs/epistemic/CLAIMS.md`; `docs/status/leak-crisis.md:26,74-79`); `docs/research/open-hypotheses-2026-07-27.md:286-291` and `docs/research/ko-sensitive-chainability.md:276-281` record the implication. | Mark H5(c) in `docs/research/open-hypotheses-2026-07-27.md` as rejected for shipping; keep it as a documented anti-solution so it is not rediscovered. |
| **H5d** | Bounded-history state is the representational route to a real-game claim. | **OPEN** | `docs/research/open-hypotheses-2026-07-27.md:288-289`; `docs/epistemic/CLAIMS.md` `GLOBAL.H5d` is CLAIMED. | User scopes a new ADR; this is a design decision, not an engineering task. |

---

## Counts

| verdict | count |
|---|---|
| CLOSED | 2 |
| IN PROGRESS | 1 |
| OPEN | 9 |
| REJECTED | 1 |
| **Total** | **13** |

(5 parent/sub-hypothesis rows for H1, 1 for H2, 1 for H3, 3 for H4, 4 for H5.)

---

## What to dispatch next

Ordered by cost and dependency:

1. **H2 — greedy-vs-random arena persona.** Two runs of `bin/weizigo-arena` on the same artifact and seed set. Cost: ~1 h, zero code change if the existing `det` flag suffices. Deliverable: a comparison of CLEAN-LEAK rate and max leak magnitude; relabels or retires the 3.4% figure.
2. **H4b was already closed; do H4a only when a 4×4 build is scheduled.** The cheapest remaining open item is H2, not H4a. H4a should ride along with the F2/F3 writes-off regen rather than claim its own build.
3. **H1-LONGCYCLE — 2×2/3×2 simple-ko + long-cycle-ties pilot.** A small retrograde build under the candidate rule. Cost: hours. Deliverable: whether the converge machinery can pin long cycles to a tie value, and whether the 2×2/3×2 published anchors (0 / 0) reproduce. Do **not** start a 4×4 simple-ko generation run before this answers.
4. **H3 — history-exact mid-game crossover.** Build the instrumented search and measure on the two saved regression games. Cost: 1–2 days. Deliverable: the empty-point count where median wall time crosses 1 s and 10 s; gates H5b.
5. **H5a — chainability guard in `src/gtp.zig`.** Implement the D-3 child-check and history-free fallback. Cost: ~1 day. Deliverable: replay of the two saved regression games shows the ply-16 −16 → +16 reversal no longer occurs. Must pass the #2 auditor before commit.
6. **H5d — bounded-history ADR.** User-only; no dispatch until the user scopes it.

---

## What to close — one-line doc edits for the owner

- **`docs/research/open-hypotheses-2026-07-27.md` H1:** Replace the "Experiment (cheap, go/no-go — run this FIRST)" block with a one-line note that the 4×4 reachable-state census is CLOSED (51,419,046 triples, 29,497,329 addresses, 177 MB dense) and point to `docs/research/kostate-census-2026-07-28.md`.
- **`docs/epistemic/boards/4x4/EPISTEMIC.md` `[T07-9]` D3 placeholder:** Change "≤ 32 GB (confirm with user)" to the measured "≤ 354 MB with passes folded, confirmed by EXP-3" and ask the user to confirm the new placeholder.
- **`docs/research/open-hypotheses-2026-07-27.md` H4:** Update the "(b) Sampled, not exhaustive" bullet to "(b) CLOSED — exhaustive 4×4 chainability PASS, see `docs/research/ko-sensitive-chainability.md` Measurement 1"; keep (a) as the remaining open gap.
- **`docs/epistemic/CLAIMS.md` `4x4.M4` / `QA-021` and `docs/epistemic/boards/4x4/EPISTEMIC.md` M4:** Refresh wording to say the 4×4 chainability sweep is exhaustive (not 1:37 sample) and that the 21.27% sample figure is superseded.
- **`docs/research/open-hypotheses-2026-07-27.md` H5(c):** Change the heading/status line to "H5(c) REJECTED — bracket-cut search is tractable but not shippable as sound (it is claim C3, falsified at 3×3)".

---

## What could not be established

- The exact current `bin/managent` board state was not inspected; verdicts rely on the committed docs and `docs/status/CURRENT.md` rather than a live task manager.
- No run was performed in this task; all numbers are citations of committed evidence.
