# STATE — crash-recovery anchor

**Read this first. Overwritten in place; always current.**
Last updated: **2026-08-05, evening — Opus 5 Orcha session, after G3b was discharged and the
fleet drained.** Fable 5 retired from the seat earlier the same day; its session delta is
`docs/status/handover-orcha-2026-08-05.md`.
Resume: `bin/managent resume`, then this file, then your row's brief. Nothing else.

---

## 1. Where things stand

**The 4×4 artifact is structurally complete, and its values are now verified at full scale for
Bellman residual, key agreement, closure (both directions) and cycle containment — with move-set
consistency at 4×4 verified on a 50,000-state sample rather than exhaustively.** That is the
honest sentence as of 2026-08-05; do not shorten it to "solved", and do not drop the word
*sample* from the last clause.

G3b pass0 ran and delivered ten rows. Established at 4×4, each behind an instrument licensed
with a null control **and** a seeded defect shown to fire:

- **0 Bellman violations / 95,677,624** entries
- **0 key mismatches / 99,133,036** entries
- **0 move-set mismatches at every rung**, including 4×3 (0 / 643,378) and at ko-active states

**G3b is DISCHARGED (Orchestrator ruling, 2026-08-05, `29477d9`)** — the signed ruling is the
final section of `pass0/accept.md`. T363 closed all four gaps; the seat re-ran the load-bearing
check itself rather than reading the report (0 / 600,763,414 children, 0 / 99,020,312 reachable,
239.5 s, 1124 MB — reproducing T363's figures exactly). Promotions authorised, executed by
**T377**: `4x4.C1` and `4x4.FP1` UNTESTED → CLAIMED, `GLOBAL.H4` text drops "partial". **Nothing
to PROVEN** — CLAIMED is the ceiling pending Phase 3.

**Four scope limits travel with that discharge and must be quoted wherever it is cited:** I11 at
4×4 is a 50,000-state sample of 99,133,036 (0.05%) and the only non-exhaustive condition; the 4×3
I4 rung excludes 170,276 KO_SENSITIVE slots (WZO1 format boundary); the KO_SENSITIVE column itself
is still distrusted pending Track A — the checks pass *around* it; and everything is fresh-start
under R, never real-game. **Accepted vacuity finding:** spec §7.2's premise that 3×2 is the first
non-vacuous I5 rung is false in the full graph, so the lower I5 rungs could not have failed and
were never evidence — the 4×4 rung is the one that counts, and it carries the red-then-green
seeded control. G3b is one lemma of Phase 3, not Phase 3.

Spec is **Rev 5**, plan is **Rev 5**, both RATIFIED. 4×3 is ladder rung 4: **no 4×4 reading
counts until that check has passed at 4×3.**

## 2. Rules that cost the most to learn — obey these

1. **Run the instrument; do not read the document.** `sprint.md:93` — document review has found
   zero of this project's real defects. Every defect found on 2026-08-04 came from running
   something: parsing an artifact header, dry-running a dispatch, sampling a stuck process.
2. **A pass condition without a denominator is not a pass.** This is how a 22-entry sample got
   tabled as PASS at 4×4.
3. **Every instrument needs a null control and a seeded-defect control before its first reading
   counts.** A comparison never shown to fail is not evidence.
4. **Verify a finding's `file:line` before accepting it.** One audit finding was substantively
   right and cited a blank line.
5. **Floors move down only, by the Orchestrator, on evidence of a committed fix**
   (`docs/infra/roles/ARGUS.md:97-100`). Never widen a floor to admit a citation — rescue the
   file into tracked evidence and re-point instead. Eleven dangling paths were checked on
   2026-08-04 and every one was already gone from disk.
6. **Commit, then `zig build deploy`, then `sh tools/smoke.sh` with zero STALE — every time.**
   Deploy staleness is a hard suite failure again since T337 wired the check.
7. **Verify a leg with `zig test src/<f>.zig --test-filter <tag>` (one flag per test — the
   filter is a SUBSTRING match, so a `\|` alternation string matches nothing and passes
   vacuously; assert the reported test count), never unfiltered.** The unfiltered form pulls
   the full import graph and drags in `qa023_brute_2x2`'s explosive smoke test. It now fails
   fast on a 20M-node budget (T360); **do not raise the budget.** (`zig build test` accepts no
   filter in this build.zig — the previous wording here prescribed a command that does not run.)
   **Since T363 (`f713234`) four files need the `engine` module and the bare form no longer
   compiles them** — `vb_i11`, `vb_closure`, `vb_mutants`, `smd1`. For those, map the module
   explicitly, e.g.
   `zig test -O ReleaseFast --dep engine -Mroot=src/vb_closure.zig -Mengine=src/smd1_engine.zig --test-filter "<tag>"`.
   The bare form fails with `error: no module named 'engine' available within module 'test'` —
   a compile error, so it is loud, but it looks like a broken checkout rather than a stale recipe.
   Verified by this seat on 2026-08-05 while re-running the 4×4 closure check.
8. **One writer per file, declared as `holds=`.** `holdsConflict` refuses a claim only against an
   **in-progress** holder (`src/managent/main.zig`), so declaring the hold is what mechanizes it.
9. **Commit through `tools/git-commit-mine <paths> -m <msg>`**, never `git add -A`.
10. **Declare both findings deliverables** on every row: `findings/<id>-<slug>.json` **and**
    `findings/<id>-context.json`. They are different artifacts.
11. **`managent dispatch --to` records bookkeeping and spawns nothing.** Launch with
    `bin/ollama-subagent <id> --model <tag>:cloud` or `bin/subagent <id> --dspro`. The `:cloud`
    suffix is load-bearing — bare tags do not resolve.
12. **Never ask a model to introspect its identity** (2/2 wrong). An agent *told* its identity
    echoes it reliably (4/4). `unknown/T999` is an untold agent, not a lying one.
13. **Poll `bin/managent inbox <id> --ack` at every checkpoint.** The operator is no longer the
    relay. A console that does not poll blocks for hours on a directive it never read.

## 3. In flight and owed

**The fleet is empty as of 2026-08-05 evening.** Every dispatched row closed. Dispatchable now,
in the order this seat would run them:

| Row | What | State |
|---|---|---|
| T377 | Execute the G3b promotions + repair the 5 non-conforming findings files | **dispatchable — do this first**, it records M2's result in the ledger |
| T373 | Register triage Step 0 — 132 rows to `archives/`, live register 334→202, C3 floor 48 | **unblocked** (needed T363, now done). Wedge risk: re-base the calibration fixtures FIRST |
| T369 | Suite truth — enumerate every red, known-red manifest firing both ways | dispatchable. Red #1 is FIXED by T363; the remaining red is qa023's T360 fail-fast (4 crashed tests) |
| T370 | Task identity into `tools/runner` — liveness blind, directives cannot land | dispatchable; serialises with T362/T364 (set G) |
| T357 | Ollama concurrency measurement — **needs a quiet fleet, which it now has** | dispatchable |
| T362 / T364 | Fleet-aware memory guard; parent-side exit records + `managent reap` | dispatchable, hold `tools/runner` |
| T350–T353 | managent robustness (set C, one at a time) | dispatchable |
| T358 | Scaling census — rebuilds artifacts, wants a quiet machine | dispatchable, frontier-held |
| STANDING-CLEANUP | Triggered: tree dirty across two turns | dispatchable |

Closed 2026-08-05 (evening): **T363** (all four G3b gaps + the `vb_i11` build defect),
**T348** (discharge, closed by the seat — the verdict was never a worker's to give),
**T366** + **T375** (M3 and its mirror), **T371** (first race), **T368** (standing triggers),
**T372** (Z-R-TIE contrast), **T374** (showscores crash), **T376** (bakeoff worktree).

## 4. Gates, as of now

`C1a ORPHANED` 10 · `C1b STALE-NEGATION` 0 · `C2 DEAD-LINKS` 14 · `C6 MISCITED` 0 ·
`C7 UNABSORBED` 0 · `C9 UNMAPPED` 0 · calibration PASS — all at floor.
**`C3 UNBACKED` = 76 of 100 PROVEN rows have no committed evidence.** Report-only, which is why
it grew unnoticed. T354 proposes the ratchet.

**Suite, 2026-08-05 evening: 46/48 steps, 691/695 tests** (up from 43/48 and 681/685). T363 fixed
red #1 — the `vb_i11` target that could not compile since T346 — via a shared `engine_mod` now
imported by `vb_i11`, `vb_closure`, `vb_mutants` and `smd1`. The remaining 4 crashed tests are the
documented pre-existing `qa023_brute_2x2` fail-fast (T360's 20M-node budget; do not raise it).
**T369 still owns the aggregate**: a known-red manifest that fires in both directions, so a new
red is loud and a fixed red must be struck. Also still true, and the reason T369 matters:

**the acceptance gate has not been a gate.** `bin/managent audit` reports **24 done rows closed with `--skip-acceptance`**, each with
its own honest-sounding story for why the suite was already red (T338's uncommitted work, T360's
node budget, `vb_i11` wiring, an 1800 s runner kill, claimlint's floor). No two stories agree and
no row owned the aggregate, so 24 consecutive rows self-certified on a partial leg. Red #1 is
verified by execution: `build.zig:407` empties the `vb_i11` test target's import table while
`src/vb_i11.zig:58` imports `engine`. **T369** owns the fix, the enumeration of the remaining
reds with an owner and a defect/red-by-design verdict each, and a known-red manifest that fires
in both directions. Until then: cite T369 when skipping acceptance — do not invent a new story.
Corollary of the same reading: the I11 null and seeded-defect controls have **never** run inside
`zig build test`; G3b's move-set evidence was taken by the standalone recipe at
`src/vb_i11.zig:42-46`, which does pass. Say so when citing it.

## 5. Operator rulings, 2026-08-04/05

- **Orcha delegates sprints to consoles; it does not manage their internals.** Orcha's output is
  the delegation package and the set plan.
- **Archive, never delete.** Rows leaving the live register move to `archives/` in full with a
  one-line epitaph. Because nothing is destroyed, agents may move without per-item approval.
- **IDs and names coexist**; a name never replaces an ID. Spell out an ID's meaning at least
  once per session when writing to the operator.
- **Fable: hand over before 90% of 200 k and use sparingly.** The 200 k line is a **cost**
  boundary, not capacity — the window reaches 1 M. Mechanism undocumented; do not restate as fact.
- **4×3 is ladder rung 4** (spec Rev 5), for transposition coverage and as the 5×4 rehearsal.
- **8192 MB authorised** for the I5 runs. Host has 48 GB and took an OOM kernel panic at 12.5 GB.
- **deepseek-v4-flash is the default for ALL new dispatches until 2026-08-12** (worker rows and
  sprint consoles); at expiry, re-rule on the week's ledger — `model-perf.md` §Model versions.
- **Concurrency:** the five-agent ceiling is the Ollama pool only; no DeepSeek limit known
  (operator, 2026-08-05: six DeepSeek + five Ollama + several Claude simultaneously is fine).
  Real constraints are sets, `holds=`, and host RAM.
- Decisions that cannot be delegated: `docs/infra/human-decisions.md`.

## 6. Epitaphs — do not re-open these

- **PSK solving** — abandoned 2026-07-24; intractable and not real Go. Committed residue
  (including a 4×4 "+2") is untrustworthy; the certified L/H core is sound.
- **MIGOS +2 as an anchor** — a different cycle-resolution rule, i.e. a different game (T274).
  Ours is +1. Comparing across rulesets produced a false acceptance failure.
- **The 716-gap escalation** — the *check* was wrong, not the solver (T287). L<H is the honest
  output where the state does not determine the value (axiom E3).
- **`CODE.WZO2-INCOMPLETE`** — FALSE-AS-SCOPED. The "missing 6.77M entries" were 131,068
  genuinely unreachable single-colour gobans; the original figure overstated 51.7×.
- **Credential stripping for subagents** — rejected 2026-08-03; solves nothing on a single-user
  host.
- **The mkdir store mutex** — replaced by `flock(2)` after it wedged the fleet for eight hours.
  `std.process.exit` skips `defer`; the kernel releases an flock on death. Do not reintroduce a
  filesystem mutex.

## 7. Seats

| seat | status |
|---|---|
| Orchestrator | **Opus 5, seated 2026-08-05** (Fable 5 retired from the seat on operator instruction the same day; Opus 5 also held it 2026-08-04/05 before Fable) |
| Sprint consoles | seated per package, closed when the package closes |
| Auditor | ephemeral, spun per gate (DIRECTION §6) |
| Fable | **unseated** — available for high value-per-token holistic work only; never cheap audits |

**Governing documents:** `docs/audits/2026-08-02-grand-audit/DIRECTION.md` + Amendments 1–2 ·
`docs/epic-01-markovian/PHASES.md` · `docs/infra/sprint.md` · `docs/infra/human-decisions.md`.
When the kanban and DIRECTION disagree, DIRECTION wins and the kanban is the bug.
