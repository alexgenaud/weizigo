# Week-close audit — 2026-08-08 (before the holiday)

**Author:** claude-fable-5, holistic audit at the operator's request. **Audience:** the operator and
the next Orchestrator, returning after roughly a week away with no memory of this thread.
**Read order on return:** this file → `docs/status/ROADMAP-2026-08-07.md` (Orcha's self-carrying
roadmap, still current) → `bin/managent status` and `git log` **before dispatching anything**.

Every number below was read from the repository or a live instrument on 2026-08-08 between
09:40 and 10:00 CEST, at HEAD `95d63e8`. Where a number has no denominator, it is not a number.

---

## 0. One-paragraph state of the project

The 4×4 table is solved fresh-start and the engine plays in Sabaki (`bin/weizigo-gtp
data/oracle-4x4-v2.wzo2`, board 4×4, komi 0). The operator's central question of the week —
*can optimal play by both sides sustain a loop?* — is **answered: yes**, exhaustively at 3×3
(12 forced cycles / 80 states of 47,456) and by sample at 4×4 (available, not yet shown forced).
The honest ply cap is measured from the table (max decisive depth-to-termination 9 at 3×3, 17 at
4×4 — T407's 400 was 24–44× generous). T381's engine-strength claim survived its strongest
available falsifier (T420: GNU Go / Pachi / Fuego at maximum strength, 0 losses from claimed-won
in 68 games per engine). The live risk at close is **evidence hygiene**, not the kernel: 344
`/tmp` paths were cited as evidence across 72 committed docs, 43 of them already destroyed;
the rescue is committed and the re-point row (T421) is in flight — **status uncertain, see §3**.

---

## 1. What was DONE this week (since the 2026-08-05 handover)

Each row is closed, audited, and committed. IDs are kanban rows (`docs/infra/managent/tasks.json`);
sprint reports live in `docs/status/sprint-2026-08-*.md`; landmarks (L0–L7) are defined in
`docs/audits/2026-08-05-handover/LANDMARKS.md`.

| row | what it established | landmark |
|---|---|---|
| **T411** | Dispatchers now verify the **work**, not the reply: nonce echo + declared-deliverables check + row-left-dispatchable, wired into both `bin/subagent` and `bin/ollama-subagent` (`tools/dispatch_verify.py`). The lazy-"OK." incident (a worker replying OK and doing nothing) is now mechanically impossible to record as a pass — seeded lazy stub fails rc=2 through both dispatchers, regression in `zig build test`. | L1 (dashboard tells the truth) |
| **T412** | Loop onset located: 5,080 / 47,456 3×3 positions (10.70%) have *every* optimal child loopy; 6,073 / 200,000 sampled at 4×4. Ply cap read from the table: max decisive DTT **9** (3×3) / **17** (4×4). Consequence: the 96% of 3×3 tournament games that hit the 400-ply cap were **looping, not long** — the cap never truncated a resolvable line. | L2 (proven 4×4 values) |
| **T413** | Instruction-corpus cleanup: 10/16 T410 findings executed, 5 deferred with reasons, 1 disputed (F09 — premise refuted). The false Ollama five-agent-cap retraction corrected to the standing wording (the cap exists; a 9-second warm probe could not have detected it — that overclaim was **Orcha's own error**, now audit-gate check 7). | L4 (ledger is clean) |
| **T415** | Solution-tree provenance: 18 of 45 construction sub-steps PROVED (40%), falling monotonically to 1/9 at 4×4. The construction's weakest rungs are now named. | L4 |
| **T416** | **The headline answer.** The optimal-move subgraph contains cycles: 3×3 exhaustive — 54 cyclic SCCs / 4,550 states, **12 FORCED cycles / 80 states** where every alternative is strictly worse; 4×4 sample (150,001 nodes, 0.15%, seed 42) — 6 cycles / 24 states, all indifferent. The tie-handling trap is real and demonstrated: keeping one optimal child instead of all ties **fabricates ACYCLIC** at 4×4 (45,905 vs 208,908 edges). Any re-run must keep all ties. | L2 |
| **T417** | Sprint console #4 (deepseek-v4-flash) — ran, audited, and accepted T415+T416, including two T416 infra kills by the 4 GB RSS guard handled as infra, not findings. | — |
| **T418** | Absorbed the 5-row findings backlog into the claims register: register/mapping lockstep at **226 rows**, one PROVEN→CLAIMED downgrade (resolver budget-quarantine — load-bearing datum was single-instrument). | L4 |
| **T419** | Full loopy-child taxonomy (new instrument `src/t419_taxonomy.zig`, 17 unit tests): of 15,008 3×3 positions with a loopy child, optimal play **declines the loop in 63%**, median margin 9 points. Sequential forcing decays depth-1 5,080 → depth-3 3,656 against only 80 never-escaping states — **the pathology is far narrower than the depth-1 count suggests**. Its null control caught a real wiring defect before reading. | L2 |
| **T420** | Third-party engines at **maximum** strength as a falsification instrument: Pachi at 75.3k playouts/move (T381's run was actually ~11.5k), Fuego at ~30–230k/move, GNU Go already at its documented max. **0 losses / 0 ties from claimed-won positions in 68 games per engine.** Wins from non-claimed roots did *not* fall with strength — the earlier margin was not opponent weakness. Refuted Orcha's own prediction; still a sample measurement, not a proof. | L0 (engine never loses from claimed-won) |
| **Evidence rescue** (`07d8c54`) | Orcha's sweep found 344 `/tmp` paths cited across 72 committed docs; 301 still existed and 278 files were copied to `docs/evidence/RESCUED-tmp-2026-08-08/` with a MANIFEST; **43 citations were already dead** — the evidence is gone. | L4 |

**Whose losses, plainly:** the operator's per-position "no-problem" expectation failed (loops are
sustainable, and forced at 3×3) — but the operator's *refinements* (D056 sibling test, D058 cycle
test) were what made the answer trustworthy. Orcha's Ollama-cap retraction and its T420 prediction
were both wrong, both corrected on the record. The kimi lazy-reply incident was a worker failure,
now structurally impossible.

---

## 2. Open questions at close (ranked)

1. **Does 4×4 have a FORCED cycle?** Open. The 0-forced reading is from a 0.15% sample — a lower
   bound, not a result. Per-goban independence forbids inferring from 3×3's 12/54. Needs a larger
   sample or exhaustive run; the 4 GB RSS guard killed the bigger attempts (see §5, CPU/RSS knob).
2. **Why is `life ⟹ L==H` true?** Categorical over 99,133,036 entries, zero exceptions, no proof,
   not score-forced. The best theorem candidate in the project (roadmap §5.1).
3. **Which claims lost their evidence?** 43 dead `/tmp` citations — T421's most important output.
   If any supported a PROVEN or CLAIMED register row, that row is now unsupported. **Unknown until
   T421 reports.**
4. **Is the 4×3 root `[+4, +12]` right?** Single instrument, never audited. Gates anything citing it.
5. **What is forcible at exactly the decisive roots?** "Can-force-settled-and-ahead" is the
   candidate predicate — the formal version of the operator's "strong territory".
6. **Track A** — regenerate `KO_SENSITIVE` columns with `memo_writes=false`. Until then every 4×4
   real-game claim carries the distrust caveat.

---

## 3. IN FLIGHT — what you must check before dispatching anything

- **T421 (evidence re-point) is `in_progress`, claimed 2026-08-08T07:38Z, claim_count 1, agent
  unrecorded, no commits yet at audit time.** No worker process was visible on this machine at
  09:45. The store has understated live consoles before (2026-08-04 handover) — **run `git log`
  and look for `findings/T421-evidence-repoint.json` / `docs/infra/evidence-repoint-2026-08-08.md`
  before re-dispatching.** If nothing landed during the holiday, the claim is stale: reset and
  re-dispatch. Brief: `untracked/T421-evidence-in-tmp-repoint.md`. It also closes the claimlint
  hole (C2 only flags *missing* paths, so a live `/tmp` citation passes silently until the file is
  destroyed) and holds its claimlint deploy until no row is mid-close.
- **T422 (absorb 2026-08-08b) is `dispatchable`, gated behind T421** — absorb T419/T420 findings
  after the evidence paths settle. Brief: `untracked/T422-absorb-2026-08-08b.md`.
- **D063 to T420 was never read** (`read: false`; posted 07:36:24Z, T420 closed 07:37:02Z — a
  38-second miss, the same pattern as D058's 41-second miss with T412). No harm done this time:
  T420's evidence *is* committed under `docs/evidence/4x4-THIRD-PARTY/` and its 4 residual `/tmp`
  strings are reproduction command lines, not evidence citations. But **two directives in one week
  arrived seconds after row close and were silently unread** — the close path could check the
  inbox one final time. Nobody owns that idea yet.
- **Uncommitted working tree (2 files)** — commit these before or on return, they are real:
  - `docs/infra/model-perf.md` — 4 dispatch-verify ledger lines from today's T415/T416 dispatches
    (the new T411 machinery writing its per-model claim-vs-verified data, working as designed).
  - `untracked/msg/milestone-01-ko-reframe/STATE.md` — one-word label fix (M3 → L3).
- **STANDING-CLEANUP** is flagged: "tree dirty across two turns" — the two files above.

---

## 4. Health at close

- **Claims register:** 226 rows parsed / 0 unparsed, register↔mapping lockstep (C9 = 0).
- **claimlint** (run live for this audit): C1a orphans 0, C1b stale-negations 0, C2 dangling
  evidence paths **11**, C3 PROVEN-without-committed-evidence **48** (both floor-gated in
  `claimlint-floor.json` — honest debt, not regressions), C6 miscited 0, **C7 unabsorbed 2**
  (pre-existing; T422 will absorb), C8/C5 clean, calibration PASS.
- **Test suite: UNRESOLVED — not a clean green in this run.** `zig build test` at HEAD took
  **~52 minutes** (documented figure: ~610 s) and reported **923/931 tests passed, 7 crashed,
  1 skipped, plus 2 `run sh` step failures** (6 of 62 build steps failed). Three facts temper
  this before anyone calls it a regression:
  1. **Nothing reproduces standalone.** The one step the build named as failed (`vb_closure`)
     passes **12/12** re-run directly, and the three environment-sensitive shell regressions
     (`git-commit-mine`, `subagent-prompt`, `dispatch-verification`) all **PASS** standalone.
     No stale `MANAGENT_*`/`WEIZIGO_*` env vars were present (the D060 confounder is excluded).
  2. **The run was resource-saturated:** *two* test binaries were simultaneously executing the
     same `vb_scc_4x4` seeded-defect test (a full 4×4-table SCC scan in `checkI5Wzo2`), each
     pegged at 100% CPU for 25+ minutes at ~3.2 GB RSS. The crash pattern is consistent with
     memory/CPU pressure under the parallel test graph, the same class as the T416 RSS-guard
     kills and the 2026-07-29 OOM kernel panic.
  3. **The tree was 2 files dirty** (the §3 files) — and T350 established that a dirty tree is
     not a valid instrument.
  **First session back: one clean-tree, low-load re-run before trusting or acting on this.**
  The duplicated concurrent `vb_scc_4x4` execution and the 52-min wall time (5× the documented
  610 s) deserve a row of their own regardless of the re-run's verdict — a suite this heavy will
  keep tripping the CPU guard on worker-run suites.
  Small positive datum: the in-suite dispatch-verification regression appended **zero** lines to
  the live `model-perf.md` ledger across all these runs — T411's scratch-ledger isolation works.
- **Engine:** plays in Sabaki today; from bracketed positions vs the old engine 150 better /
  120 equal / 0 worse of 270, and 0/270 below its own table's floor.
- **Backlog debt:** nine `dispatchable` rows from earlier sets predate the current thread and were
  neither worked nor killed this week: T351 (failed-command source fix), T352 (t227 timeout),
  T353 (orient generator), T357 (Ollama concurrency limit), T358 (scaling census), T362
  (fleet-aware memory guard), T364 (orphan reaper), T369 (suite truth), T378 (qa023 probe inverted
  guards). **On return, triage: re-affirm, re-brief, or kill each** — a week-stale dispatchable row
  is a trap for the next console.

---

## 5. SHORT TERM — the first session back

In this order (dependency order, not priority order):

1. **Re-run the suite on a clean tree under low load** and settle the §4 suite verdict. If it
   crashes again, bisect by test binary; if green, register the suite-weight row (52 min wall,
   duplicated `vb_scc_4x4` execution) and update the documented baseline.
2. **Settle T421.** Check `git log` first (§3). Its "which claims lost evidence" report may
   reclassify register rows — read it before trusting any PROVEN row it names.
3. **Dispatch T422** (absorb) once T421's paths are stable.
4. **Triage the nine stale backlog rows** (§4) — decide, don't let them sit a second week.
5. **Audit the 4×3 root `[+4,+12]`** — single-instrument, gates citation (roadmap §4.1).
6. **The 4×4 forced-cycle question** — needs a bigger run than the 4 GB RSS guard allows; pair it
   with the **CPU/RSS-guard knob** row (a 40-minute suite run once tripped the 1-hour cumulative
   ceiling and killed a worker mid-row; T416 was killed twice by the RSS guard).
7. **Fixed-reference-opponent tournament** — the unconfounded strength arm (`N vs R` compared to
   `O vs R`), which `new/new` vs `old/old` is not.
8. Smaller queued items: cost axis in the resolver registry; regenerate stale claim-index files
   (T406 generator fix); D060 env-leak scrub in regression harnesses; F13 short-name scan residue;
   F09 ratification (operator ruling needed).

**Process notes for the first day back:**
- The **DS Flash-default TEMP window expires 2026-08-12** — mid-holiday. First session back,
  decide whether to extend it or revert to per-row model choice; T363 was the first
  sprint-manager trial and T414/T417 both ran clean on flash consoles.
- Seats at close: **claude-opus-5 holds the Orchestrator seat** (`docs/status/handover-orcha-2026-08-05.md`);
  Fable is used sparingly for holistic work (this audit is one such use).

---

## 6. LONG TERM (unchanged from the roadmap, still right)

1. **Attempt the `life ⟹ L==H` theorem** — proof is the only thing that promotes anything here.
2. **The weakest forcible predicate** holding at exactly the decisive roots — formalises "strong
   territory", the thing the operator's original hypothesis was reaching for.
3. **Rule-independence at new rungs** (4×2, 5×2) via T394's generic closure instrument, with the
   prediction recorded *before* measurement.
4. **Track A** — ko-sensitive regeneration; unblocks real-game claims.
5. **5×5 scoping** — requires a *sound* pruning oracle; `canForceLife` is not one (85.3% of its
   prune class is decisive).
6. **BRACKETED / SINGLE-SCORE rename sweep** — approved, unscheduled (~27 src files, ~185 docs,
   file by file, never a global `sed`).

---

## 7. Traps — corrections already paid for; do not re-make them

- **`canForceLife = false` for both players is NOT a draw certificate** — 85.3% of that class at
  4×4 is decisive. Two agents have already re-derived this; a third will try.
- **Keeping one optimal child instead of all ties fabricates ACYCLIC** (T416). Any cycle re-run
  keeps all ties.
- **Bracketed ≠ loop-preferred; ko-freeness points the wrong way** (93.8% of bracketed 3×3 entries
  are ko-free); SCC membership is a near-vacuous predictor.
- **Termination + Bellman consistency ≠ correctness** (the capture budget, ADR-0022: a different
  game, not an approximation of ours; it may never write to the canonical table).
- **A silent wrong answer outranks a loud crash** — every defect this week was tooling reporting
  success while doing nothing. Every instrument needs a null control and a seeded-defect control
  before its first reading counts.
- **`/tmp` is not evidence.** Anything a document cites must be committed under
  `docs/evidence/<claim-id>/` before the row closes. 43 citations died learning this.
- **A dirty tree is not a valid instrument** (T350's nine "failures").
- **Absence of an observed effect is not evidence of absence** (the Ollama-cap overclaim; now
  audit-gate check 7 on every sprint).

---

*Written by claude-fable-5 on 2026-08-08 at HEAD `95d63e8`. Sources: `git log`,
`docs/infra/managent/tasks.json` + `directives.jsonl` (live reads), `bin/weizigo-claimlint` (live
run), `docs/status/ROADMAP-2026-08-07.md`, `docs/status/sprint-2026-08-09.md`,
`docs/status/sprint-2026-08-08b.md`, `untracked/T421-evidence-in-tmp-repoint.md`,
`docs/audits/2026-08-05-handover/LANDMARKS.md`.*
