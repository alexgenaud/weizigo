# CURRENT — in-flight task status (ephemeral; updated often)

**Purpose:** the single file a fresh session reads to resume *without loss*
after a context clear / compact / handover. Not durable — milestones live in git +
`../epistemic/PROGRESS.md` + `../decisions/` + `../research/`. If this file is stale, read
`../epistemic/PROGRESS.md` → `leak-crisis.md` and rebuild it.

Last refreshed **2026-07-29 04:00** (MiniMax-M3 host-panic-recovery session);
**2026-07-29 succession + D-8 + EXP-10-done correction by GLM-5.2
(Orchestrator)** — see the new section at top.

> **⚠ 2026-07-29 — WITHDRAWN: the QA-023 "falsification" is a probe artefact.**
> The banner that stood here reported 2B-4's 390/1080 disagreements (36.1%),
> later re-run by 2B-FIX-KO as 454/1133 (40.1%), as a falsification of the
> keystone claim. **Both numbers are invalid.** `truncated_value` was called
> with an arrival set containing the target state σ itself, so its opening
> revisit check matched σ against σ and returned TIE before the terminal check,
> before `moves()`, before any recursion — **measured: 1,133 σ-in-arrival
> collisions out of 1,133 evaluations.** "Disagreements" merely counted sampled
> states whose median fixpoint is non-zero. The tells were in every recorded
> run: value-agreements **0** and budget-exhausted **0**, at every history
> depth from 2 to 40, with a flat 34–43% rate. Evidence, worked counterexample
> and the corrected build:
> `docs/evidence/QA-023/probe-defect-2026-07-29/README.md` (Orchestrator/Opus 5).
>
> **QA-023 is neither falsified nor cleared — it has not been tested.** The
> corrected instrument does discriminate (45 value-agreements) and leaves **12
> disagreements out of 77 within-budget evaluations**, all in the *opposite*
> direction (truncation has a value, the fixpoint over-pins TIE), with 93% of
> the sample lost to budget exhaustion. Those 12 bear on **C2** (the
> `median(L,TIE,H)` formula = `QA-026` / proof-v2 Thm 5.1), **not** on **C1**
> (Markovian state-sufficiency = what the `QA-023` row asserts). No observation
> so far contradicts C1. The two have opposite roadmap consequences and must
> never again be reported as one verdict. **Nothing is absorbed into
> CLAIMS/PROGRESS.** Gate: `2B-PROBE-FIX` (registered, dispatchable) → `2B-6`.
> What still stands: the 2B-FIX-KO ko-rule fix (independently verified against
> Python), the 2B-2 census, and 2B-5's calibration — noting that 2B-5's POS arm
> exercises a *parallel* PSK code path and so did not cover the defective call
> site. Attribution: 2B-4 was **DeepSeek Pro** (human-confirmed; the PROVENANCE
> mis-recorded MiniMax-M3, corrected).

**Outgoing handover:** `docs/status/handover-minimax-m3-2026-07-29.md`. Read
that file first on resume; it supersedes this one for the unit-of-recovery
view. The 2026-07-29 / 2026-07-28 sections below are durable; the 2026-07-27
section is historical context.

## 2026-07-29 — Orchestrator succession (GLM-5.2)

Took the Orchestrator role from MiniMax-M3 (context full; handover above).

**Board at succession:** EXP-2B (minimax-m3), EXP-10 (fable-5), EXP-8
(kimi-k2.7) all in progress; 0 dispatchable; 5 blocked; 17 done.

**D-8 — dispatch/claim protocol simplified (user ruling).** The 2026-07-29
"Orchestrator does not claim on the agent's behalf" rule is **rescinded** as
ceremony that blocked the Orchestrator from keeping the board honest. The
Orchestrator owns delegation status end-to-end: it records dispatches on the
human's behalf, records claims when a worker has started but not claimed, and
marks `done` when a worker has finished but not updated the board —
attributing claims with `--agent <worker>` (never its own name). Worker
self-claim / self-done remain the normal path. Edited:
`docs/infra/roles/ORCHESTRATOR.md`, `docs/infra/delegation/ROLES.md`,
`DELEGATOR.md`, `DELEGATEE.md`; recorded in `DECISIONS.md` D-8 and `STATE.md`.
`managent/spec.md` needed no change (already neutral on who runs the
commands). The stale rule in `handover-minimax-m3-2026-07-29.md` is annotated,
not rewritten.

**EXP-8 model pick:** Kimi-k2.7 (worker), per the EXP-8 brief naming T13's
C2-falsification probe as the harness template; GLM-5.2 (worker) the
documented alternative. All three dispatchable ran in parallel (no shared
`holds`); EXP-8's 4×4 measurement defers until EXP-6 lands.

**EXP-10 board corrected (D-8 in action).** On succession I found EXP-10 had
landed — Fable 5 filed
`docs/decisions/0017-bracket-cut-refutation-attempt-failed.md` +
`docs/evidence/QA-018/` + message 025, and updated CURRENT.md — but never ran
`managent done EXP-10`, so the board still read `in_progress` and
`QA-018-RULING` stayed blocked. Verified deliverables on disk and marked
EXP-10 done. **QA-018-RULING is now dispatchable.** Verdict: the D-5
refutation **failed** — the search-path family is not exempt (T13's 12
pointwise mismatches ride the finisher's own search-shaped histories, 8/12
empty-rooted), so ADR-0015 stands, strengthened. Per Fable's 025, adversarial
review of QA-018-RULING must go to a **third party, not Opus**.

**QA-018 RESOLVED 2026-07-29 (unanimous three-seat review + human ruling).**
The blind panel (`QA-018-REVIEW-A/B/C`: GLM-5.2, DeepSeek Pro, Kimi-k2.7)
returned unanimously that ADR-0017's "refutation failed" verdict is SOUND
and ADR-0015 STANDS; all three convicted the two planted calibration
defences (6 MTD self-verification, 7 `bracket_fail` gate) as WRONG. The
human ruled (ADR-0018): **ADR-0015 confirmed; F2 remains orphaned; the
finisher remedy is a new task (`F2-REMEDY`), not a brackets-off regen**
(which inherits the same premise through CERTCORE-dependent seeds). Board:
QA-018-REVIEW-A/B/C + QA-018-RULING marked done; QA-018-REVIEW (single) closed
as superseded. CLAIMS.md `QA-018` / `GLOBAL.ADR0015-BURDEN` updated to cite
ADR-0018. `F2-REMEDY` registered (design task, ANALYSIS, gated on `QA-023`).

## 2026-07-29 — EXP-10 done (Fable 5): D-5 refutation attempted, FAILED

The QA-018/019 refutation ADR is filed:
`docs/decisions/0017-bracket-cut-refutation-attempt-failed.md` + evidence in
`docs/evidence/QA-018/`. Verdict: the search-path family is **not** exempt —
T13's 12 pointwise mismatches at 3×2 ride exactly the finisher's search-shaped
histories (8/12 empty-rooted), so ADR-0015 stands, strengthened. New:
E2 is an outcome-level falsification (the pointwise one is T13), and a
**brackets-off regen is not sufficient** — all modes read CERTCORE-dependent
certified seeds (empty fingerprint passes `fpDisjoint` under deps). Adversarial
review must go to a **third party, not Opus** (`QA-018-RULING.md`); then the
human ruling QA-018-RULING is unblocked. Details:
`untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md`.

## 2026-07-29 — EXP-8 set A done (Kimi-k2.7): harness built, partial run, blocker recorded

**Owned:** `src/psk_divergence.zig` (new file; no engine files, no `data/`/`artifacts/` writes).  
**Deliverables:**
- `src/psk_divergence.zig` — generic PSK-divergence harness; compares loaded
  table value/move against history-exact PSK (`retro.Retro(w,h).O.solve`,
  `memo=false`, `brackets=false`).
- `docs/evidence/QA-012/` — raw stdout, SHA-256 sums, `PROVENANCE.md`.
- `docs/research/psk-divergence-2026-07-29.md` — findings and explicit blocker.

**Findings:**
- 2×2 frame A (`random`, 200 games): 56 PSK-solved positions, 28 value
  divergences (50%, 95% CI [0.3733, 0.6267]), 31 budget exclusions.
- 2×2 `mixed` (100 games): 49 solved, 22 value divergences (44.9%, CI
  [0.3185, 0.5869]).
- 3×2 (20 games, max-empties 1): only 3/130 sampled positions solved; exact
  PSK under reachable histories is already largely intractable.
- Known-bad synthetic calibration: perturbing `vb[0]` on 2×2 from +1 to 0
  increases the divergence count, confirming the harness detects mismatches.

**Blocker / honest negative:** the actual new-rule-vs-PSK divergence cannot be
measured because new-rule (basic-ko + long-cycle tie) tables do not exist;
EXP-4/5/6 are blocked behind EXP-2B.  The numbers above compare the existing PSK
tables against history-exact PSK, quantifying the `C2` gap in reachable play,
not the rule-divergence gap.  The research note labels this and states the
re-run command once new-rule tables exist.

**Ownership cleared.**

## 2026-07-29 — host-panic-recovery session (MiniMax-M3, Orchestrator)

**EXP-8:** `kimi-k2.7` owns `src/psk_divergence.zig` for the PSK-divergence harness (set A); no engine files, no `data/`/`artifacts/` writes.

**Stand down reason:** context full. The outgoing handover is
`docs/status/handover-minimax-m3-2026-07-29.md`; the crash-anchor is
`untracked/msg/milestone-01-ko-reframe/STATE.md` (overwritten in place,
always current). Per the standing rule, this Orchestrator does not touch
the board again.

### What happened this turn

1. **2026-07-29 02:35:57 host kernel panic on cpu 0** — `watchdog timeout:
   no checkins from watchdogd in 91 seconds`. **Root cause** (corrected in
   019 from 017's initial wrong-but-honest guess): a `zig build-exe -O Debug`
   of `src/oracle.zig` (or similar) blew 12.5 GB RSS / 21.8 GB peak while
   the compressor was at 100% of segment limit. Jetsam demonstrably does
   not act before the kernel watchdog does. **`bin/weizigo-oracle.dSYM`
   (left on disk) is the tell** — there is no oracle target in `build.zig`;
   it's always an ad-hoc `zig build-exe`, and `tools/play_oracle.py` uses
   `-O ReleaseFast`. The dead agent used Debug. **Full record:**
   `docs/infra/host/incident-2026-07-29.md` (durable in git) +
   `/Library/Logs/DiagnosticReports/Retired/panic-full-2026-07-29-023700.0002.panic`
   + `JetsamEvent-2026-07-29-023323.ips`.
2. **The fix: B-2 RSS runner** — `tools/runner` (Python, stdlib only,
   12 KB executable) + `docs/infra/runner.md` (the brief). Auto-adds
   `-O ReleaseFast` (or `-Doptimize=ReleaseFast` for `zig build`) to every
   `zig` invocation that lacks an optimize flag; SIGKILLs the process
   group on a 4 GB RSS breach. Test: 100 MB cap kills a 509 MB Python
   bytearray in 0.1 s with exit 124. Opus 5 used this pattern in EXP-9
   and the panic did not recur.
3. **The dispatch gap in `managent`** — schema had `added`, `claimed`,
   `done` but no field for the moment the human dispatched. The
   `managent dispatch <id> --to <agent> [--note <text>]` command plus
   three new schema fields (`dispatched`, `dispatched_to`, `note`) close
   the gap. The task stays `dispatchable` per the existing claim
   protocol; the dispatch is the queueing signal, the claim is the
   start signal, the done is the completion signal. **The Orchestrator
   does not claim on the agent's behalf.** *(Rescinded later 2026-07-29
   by D-8; see the GLM-5.2 section above.)* Schema in
   `docs/infra/managent/spec.md`; protocol in
   `docs/infra/roles/ORCHESTRATOR.md` §"The dispatch / claim protocol".
4. **EXP-9 (Opus 5) closed** — H5a `Session.choose` mitigation
   complete, sign defect fixed (and pinned by a new antisymmetry
   test), `weizigo_chaincheck` GTP introspection command added, +6.8%
   per-genmove cost, ply-7 prediction of the brief honestly falsified
   (A2 mechanism is real but fires at ply 13, not ply 7; structural
   reason named in §5 of the deliverable). **CLAIMED, not
   verified-optimal.** Deliverable:
   `docs/research/h5a-player-mitigation-2026-07-28.md`.
5. **EXP-12 (Kimi-k3) closed** — denominator sweep across
   `docs/research/*.md`; deliverables
   (`docs/evidence/GLOBAL.DENOMINATORS/sweep-2026-07-28.md` and
   `PROVENANCE.md`) were on disk at 02:23 — 10 minutes before the
   panic. The h5a-player-mitigation addendum was swept on resume (2 %
   tokens, both PASS). **"The crash took the report, not the work."**
   Headline: 14 research-tree FAILs + 2 PROGRESS annex FAILs; the
   pattern is "measurement tables clean, every failure is prose
   re-quoting a number at a distance." Worst: `kostate:224`'s "+98%"
   (wrong denominator, flips a conclusion) and the phantom "21–49%" /
   "8–18%" bounds with no committed source. Kimi-k3 flagged the
   `CLAIMS.md` status update as the file-owner's call (GLM).
6. **EXP-2 brief retired** — the work is in `EXP-2A` (done 2026-07-28,
   Fable 5) + `EXP-2B` (dispatchable, holds `src/qa023_probe.zig`,
   the 3×2 history-sensitivity probe — the actual computational half
   of the QA-023 gate). Board `EXP-2.status = done, done:
   2026-07-28T23:50:00Z`.
7. **EXP-2B dispatched to Minimax-m3** per the human's 03:50 ruling.
   `managent dispatch EXP-2B --to minimax-m3 --note "QA-023 gate
   computational half. … B-2 RSS runner (tools/runner) is the
   precondition. …"`. The agent claims when ready.
8. **Instruction files updated** — `AGENTS.md` (Build / test / run +
   Where-to-go-next tables mention `tools/runner`, `managent
   dispatch`, `docs/infra/runner.md`); `ORCHESTRATOR.md` (new
   "Dispatch / claim protocol" + "Ad-hoc builds go through
   `tools/runner`" + "Do not schedule the human into multi-party
   conversations"); `ROLES.md` (new "Dispatching, claiming, and the
   human/agent boundary"); `DELEGATOR.md` (new `DISPATCH:` row in
   the header); `DELEGATEE.md` (new "The first thing you do: claim
   the task" + "Builds go through `tools/runner`" + "Writing to the
   board"); `EXP-2B.md` (new "Build precondition" section calling
   out the runner).

### What was **not** done (deferred to the successor)

- **The EXP-10 dispatch** — held for Fable per D-7; the user / Dabir
  call, not mine. The board has `EXP-10.dispatchable, agent: null,
  holds: docs/decisions/`. **Do not pre-empt.**
- **The Fable-channel question** — 018 (Fable 5 as Dabir) and 010
  (Fable 5 as Opus) are role collapses. I am absorbing 018's content
  (correct) but not ratifying the form. **Dabir + the user rule on
  whether the proposals log (Dabir's `SPEC-msgbus.md`) is the place
  to settle it.** See 023 §4 for the three explicit questions.
- **The docs wave commit** — 31 files uncommitted; the host incident
  doc, the runner, the h5a deliverable, the EXP-12 evidence, the
  managent schema + binary, the dispatch field, the instruction-file
  updates, this handover. **The standing rule: never commit the
  dispatch field on its own** — it goes in with the docs wave per
  the `managent` spec ("the board does not survive a fresh clone,"
  D-2 residue). One commit per topic; `git add` by path, never `-A`.
- **The 022 §B.4 four-part EXP-2 agenda is withdrawn.** The human
  said "I have no idea what you are talking about" on 2026-07-29
  03:50. The brief is retired, the gate is EXP-2B, and everything
  else is on a clear dispatch path. The four parts remain as
  standing items; they resolve when the human brings them up, not
  on my schedule.

### The board at 04:00

```
$ bin/managent status
  dispatchable (3)
    EXP-2B  set A, holds src/qa023_probe.zig, dispatched minimax-m3
    EXP-8   set A, holds src/psk_divergence.zig
    EXP-10  set A, holds docs/decisions/  (Fable per D-7; dispatch is the user / Dabir call)
  in progress (0)
  blocked (5)
    EXP-4←EXP-2,EXP-2B
    EXP-5←EXP-4
    EXP-6←EXP-5
    EXP-7←EXP-6
    QA-018-RULING←EXP-10
  done (17)
    B34 B35 B40 B41 B42 B43 B44 B45 EXP-2 EXP-3 EXP-9 EXP-11 EXP-12
    EXP-13 EXP-14 EXP-15 EXP-16
```

---

## EXP-2A (Fable 5) — EXP-2 Part A trichotomy repair — DONE 2026-07-28, ownership cleared

- **Result:** corrected rule `V = max(L, min(T, H)) = median(L, T, H)`; v1's
  "`L<H ⇒ V=T`" is FALSE (counterexample committed); `L`/`H` proven to *be*
  the threshold-attractor values, so no computation beyond the two existing
  sweeps is needed — the reframe's cost story survives with the corrected
  line. Adversarial review (independence condition honored, verdict verbatim
  in the proof §10.1): **REPAIRABLE-GAPS — "every theorem as literally stated
  withstood attack"**; all six findings repaired, none changed a theorem.
- **Deliverables:** `docs/evidence/QA-023/proof-v2-2026-07-28.md` (proof of
  record), `docs/research/qa023-basicko-markovian-2026-07-28.md` (findings +
  re-cost + EXP-4 spec + CLAIMS one-liners), supersession pointer atop
  `docs/evidence/QA-023/proof.md`, msg `010-fable-to-opus.md`.
- **QA-023 status: CLAIMED** — Part A repaired+reviewed; gate still needs
  EXP-2B (3×2 probe, non-zero cycle census). New sub-claims QA-023.M1/M2
  (MIGOS ruleset match; adjudication-trigger equivalence) — UNTESTED.
- **Needs from others:** commit of the two new docs (durability); CLAIMS
  owner folds §3 of the research doc (incl. QA-026 wording = FALSE as it
  stands); roadmap §2 sentence correction by its owner; EXP-2B told: no
  state-keyed memo on truncated values, truncation keys on the full tuple.

### Dispatch record (was: IN PROGRESS)

- **Agent: Fable 5 (claude-fable-5)**, dispatched by the user per DECISIONS D-7 /
  msg 008 §1. Board ID is `EXP-2` Part A (msg 009 kept the stable ID; the user's
  dispatch name is `EXP-2A`; no routing brief exists — content lives in
  `untracked/msg/milestone-01-ko-reframe/004-opus-to-pi.md` §"Repair order",
  `005` §"Fable policy", `008` §1, and `docs/evidence/QA-023/audit-opus-2026-07-28.md`
  §"What would repair it").
- **Owns** (docs only, ~2 h): `docs/evidence/QA-023/proof-v2-2026-07-28.md` (new),
  a 3-line supersession pointer at the top of `docs/evidence/QA-023/proof.md`,
  `docs/research/qa023-basicko-markovian-2026-07-28.md` (new), this entry.
  Does NOT own `src/qa023_*.zig` (EXP-2B / Minimax holds those per msg 009) and
  touches no engine file, no `data/`, no `artifacts/`, no `CLAIMS.md`.
- The "EXP-2 (Minimax-m3) — claiming work" entry below is **stale for Part A**:
  Part A doc ownership passed to this console per msg 007 Q1 / 009 ruling;
  Minimax keeps Part B (`src/qa023_probe.zig`).

## EXP-3 (Minimax-m3) — DONE 2026-07-28

- Wrote `src/kostate_census.zig` (new file, no engine file touched). Standalone
  except std; `pos_from_move` and `is_legal` reimplemented to avoid pulling
  rules.zig in (per dispatch intent).
- HEADLINE NUMBERS (standard basic-ko detector, no sampling, no stride):
  - **3×3:** 22,736 reachable (b,side,ko) triples; 13,997 distinct (b,ko) addresses; 7.11% of naive dense; 16 sweeps; <1 s.
  - **4×3:** 638,266 triples; 375,281 addresses; 5.43% of dense; 25 sweeps; 2.2 s.
  - **4×4:** **51,419,046 triples; 29,497,329 addresses; 4.03% of dense; 29 sweeps; 4 min.**
- Implied artifact size at 6 B/address: **177 MB at 4×4** (0.69× current PSK 4×4
  artifact of 258 MB; 25× smaller than naive dense 4.39 GB). With `passes ∈
  {0,1}` folded (a′, b′), 354 MB. **GO on dense addressing at 4×4** under the
  D3 placeholder (≤ 32 GB).
- Calibration: legal position counts match OEIS A094777 (3×3=12,675;
  4×4=24,318,165; 4×3=321,689 ground truth). Broken detectors
  (`every_capture`, `every_move`) move the count in the predicted direction
  and magnitude.
- **Calibration-2 caveat noted in the research doc:** the dispatch's expected
  "no-ko collapses to (pos, side) slot count" is overstated — the slot count
  is the total addressable space, not the B-to-move reachable space. The
  honest figure is the B-to-move reachable (20,888 at 3×3, 45,734,854 at
  4×4) — a separate independent depth-parity BFS confirms this.
- Deliverables (all committed, ready to cite):
  - `src/kostate_census.zig`
  - `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md` + 8 raw stdout files
  - `docs/research/kostate-census-2026-07-28.md` (the four numbers per
    board, the addressing GO/NO-GO, every claim tagged, calibration
    caveat stated up front)
- **Status update for CLAIMS.md (owner folds):** `GLOBAL.H1-CENSUS` (4×4)
  was UNTESTED → **PROVEN** with this census + calibration runs. Proposed
  per-board IDs `3x3.H1-CENSUS` and `4x3.H1-CENSUS` → owner assigns. (I
  did not edit CLAIMS.md per dispatch.)

## EXP-2 (Minimax-m3) — claiming work

- Reading `docs/infra/dispatch/EXP-2.md` now. EXP-2 is THE GATE for the
  roadmap; does **not** touch any engine file. Plan: write
  `docs/evidence/QA-023/proof.md` (Part A) and a 2×2 implementation
  (`src/qa023_basic_ko_2x2.zig`) plus a brute-force reference
  (`src/qa023_brute_2x2.zig`), then both calibration and acceptance runs.
  Binaries: `weizigo-exp2-<id>` under `/tmp`, caches under
  `/tmp/weizigo-zigcache-exp2`.
- Files I will own for EXP-2: `docs/evidence/QA-023/**`, `src/qa023_*.zig`,
  `docs/research/qa023-basicko-markovian-2026-07-28.md`. None of the four
  engine files. ETA: one session.

## Where the project stands right now (2026-07-27)

The 2026-07-27 evening session produced one finding that reorders the queue:
**the GTP player steers by numbers that are not comparable to each other.**

- **PROVEN (2026-07-27, `bin/weizigo-chainability`):** outside the KO_SENSITIVE
  flag there are **zero** history-free-Bellman-identity violations at
  2×2/3×2/3×3/4×3 (exhaustive) and 4×4 (`--sample 37`). The single-score (L==H)
  region *is* chainable. Violations are exactly co-extensive with the flag
  (16/16, 72/72, 688/688, 6,092/6,092, 11,402/11,402).
- **PROVEN (same run):** the empty 4×4 board is itself KO_SENSITIVE (bracket
  [−6, +16]), and 16 of 19 plies of both saved regression games are flagged. On
  4×4 the player never has table guidance it is entitled to chain.
- **PROVEN (two saved 4×4 games):** positional-superko bans changed the best
  available value at **0 of 19 plies**. The ko *rule* costs the engine nothing.
- **Not a bug.** Each ko-sensitive slot is an independent fresh-start PSK solve
  and owes its parent no agreement — the violations are C2 restated per-slot.

Full record and the fix fork: `../research/ko-sensitive-chainability.md`.
Strategic framing (do not duplicate it here): `../epistemic/PROGRESS.md`.

**The headline gap this exposes (CLAIMED, an interpretation):** PSK is
non-Markovian while the stored table is Markovian. PROGRESS has recorded since
2026-07-24 that PSK is abandoned as the *generation* rule with basic/simple ko
as the tractable candidate — but the 4×4 artifact and the GTP player are both
**still PSK**. That unexecuted pivot is now the top item. Nothing asserts simple
ko will work: its state-space census has not been run and the long-cycle
resolution rule is undecided.

## Uncommitted / unverified right now

Working tree is **dirty**; last commit is `753584f` (2026-07-27 23:28, the 4×4
regression fixture + `zig` test). Uncommitted:

| path | what it is | verified? |
|---|---|---|
| `src/chainability.zig`, `build.zig` | new `weizigo-chainability` tool + build target | builds clean `-Doptimize=ReleaseFast`; no test coverage of its own |
| `docs/research/ko-sensitive-chainability.md` | the finding (new) | numbers reproducible via the commands in the doc |
| `docs/research/corrections-2026-07-27.md` | errata ledger (new, another agent) | in flight |
| `docs/research/open-hypotheses-2026-07-27.md` | open-work queue H1–H5 (new, another agent) | in flight, may not exist yet |
| `docs/epistemic/GLOSSARY.md` | new term **chainable** | — |
| `docs/epistemic/boards/4x4/EPISTEMIC.md` | new measured facts M4, M5; FP1 check 3 → done-with-caveat | — |
| `docs/epistemic/PROGRESS.md`, `docs/status/CURRENT.md` | B45 doc hygiene + this refresh | — |
| `docs/epistemic/boards/4x3/` | 4×3 epistemic tree (B45) | — |
| `regressions/README.md` | diagnosis section (another agent) | in flight |

**Known-unsound statements already in the repo** (being logged in
`../research/corrections-2026-07-27.md`, do not re-derive): commit `753584f`
and `regressions/README.md` blamed the blunder on PSK history (zero bans were
active at that node) and called it "the C2 falsification in action" (C2 is
scoped to L==H; every blundering node is KO_SENSITIVE, outside C2's scope); and
ADR-0013's closing line says the GTP player shares the finisher machinery and
inherits its fix — it does not, `Session.choose` in `src/gtp.zig` does table
lookups only and never searches.

**Scope caveats to carry:** the chainability check validated the shipped
`vb`/`vw` columns only (WZO1 stores no bracket columns, so the `lo`/`hi` form is
untested), and 4×4 was a 1:37 stride sample, not exhaustive.

## Next actions — ordered by cost (cheapest first)

1. **H1 first experiment — simple-ko reachable-state census at 4×4.** Count
   reachable `(position, ko_point, side)` triples. This is a counting job, not a
   solve, and it is the one number that says whether the simple-ko pivot is
   tractable at all. Highest value per hour on the board. Do **not** start a
   simple-ko generation run before this number exists.
2. **Commit the chainability work.** `src/chainability.zig`, `build.zig`,
   `docs/research/ko-sensitive-chainability.md`, `GLOSSARY.md`,
   `boards/4x4/EPISTEMIC.md`, the corrections + open-hypotheses docs, and the
   status refresh. One commit per topic; the tree has four concurrent authors,
   so `git add` by path, never `-A`.
3. **H2 — greedy-vs-random arena persona.** Runs on existing machinery
   (`bin/weizigo-arena`). Falsifies or confirms the CLAIMED reading that B43's
   3.4% clean leak rate is a *lower bound* for the greedy GTP player. If greedy
   does not leak more, the "flattering false premise" mechanism is wrong.
4. **H4 — close the FP1 check-3 residue.** Exhaustive 4×4 chainability pass
   (drop `--sample`) plus an in-memory `lo`/`hi` bracket-table variant of the
   same identity. Cheap to state, long to run.
5. **H5 — player hardening.** Only after (1): the fork in
   `../research/ko-sensitive-chainability.md` is sound-but-mute (steer only
   where chainable) vs tractable-but-unsound (bracket cuts = C3, falsified at
   3×3) vs bounded-history state (new ADR). **This is the user's call, not an
   agent's** — no engine change was made on this finding.
6. **H3 — mid-game tractability crossover** for history-exact search (where does
   a real-history search become affordable?). Open-ended; lowest priority.

Detail and falsification tests for H1–H5: `../research/open-hypotheses-2026-07-27.md`.

## Concurrency — who owns what (2026-07-27 evening)

Four agents were writing this tree in parallel. One writer per file; if you pick
up a file listed above, check `git status` first and post a one-line intent here
before editing `src/retro.zig` / `oracle.zig` / `rules.zig` / `solve.zig`.
No engine file is currently claimed.

## Completed 2026-07-27

- **Chainability finding** — `bin/weizigo-chainability` built; five artifacts
  measured; PROGRESS, GLOSSARY, 4×4 EPISTEMIC, regressions README updated.
- **`753584f`** — 4×4 regression fixture (`regressions/4x4-history-blunder.{gtp,sgf}`,
  `4x4-black-win-after-ko.txt`, README) + artifact-independent `zig` test
  `4x4 regression: user-win B+15.5 …` in `src/gtp.zig` (final area 16 → B+15.5
  at komi 0.5).
- **GTP play-policy sequence** (`c03d40b`…`e94b107`) — pass/resign policy,
  early-game min-stones gate, capture-priority tie-break.
- **B45 doc hygiene (Kimi)** — PROGRESS + CURRENT refresh, new
  `docs/epistemic/boards/4x3/EPISTEMIC.md`; UD-1/2/3 resolved; docs-only.
- **B43/B44** — arena UNDEF guard (clean 4×4 leak rate **3.4%**, max 32 pts;
  `../research/arena-4x4-undef.md`) and repo cleanup.

## Completed 2026-07-28

- **EXP-2A (Fable 5)** — Part A proof of state sufficiency under basic ko
  + fixed tie, REPAIRABLE-GAPS → repaired, all six findings accepted;
  proof of record at `docs/evidence/QA-023/proof-v2-2026-07-28.md`. See
  `010-fable-to-opus.md` in the milestone.
- **EXP-3 (Minimax-m3)** — kostate census at 3×3/4×3/4×4; **GO on dense
  addressing at 4×4** under the D3 placeholder (≤ 32 GB); 177 MB at 4×4.
  Source `src/kostate_census.zig`; research note
  `docs/research/kostate-census-2026-07-28.md`. AGENTS.md: H1-CENSUS
  PROVEN.

## Completed 2026-07-29 (host-panic-recovery session)

- **EXP-9 (Opus 5)** — H5a `Session.choose` mitigation; sign defect
  fixed (pinned by a new antisymmetry test); `weizigo_chaincheck` GTP
  command added; +6.8% per-genmove cost; ply-7 prediction honestly
  falsified (A2 fires at ply 13, not ply 7; structural reason in §5).
  **CLAIMED, not verified-optimal.** Deliverable
  `docs/research/h5a-player-mitigation-2026-07-28.md`.
- **EXP-12 (Kimi-k3)** — denominator sweep across
  `docs/research/*.md`; 14 research-tree FAILs + 2 PROGRESS annex
  FAILs; "the crash took the report, not the work" (deliverables
  were on disk 10 min before the panic). Deliverables
  `docs/evidence/GLOBAL.DENOMINATORS/{sweep,PROVENANCE}.md`.
- **`managent` schema + command** — three new fields (`dispatched`,
  `dispatched_to`, `note`); new command
  `managent dispatch <id> --to <agent> [--note <text>]`. Closes the
  dispatch gap. Spec in `docs/infra/managent/spec.md`; protocol in
  `docs/infra/roles/ORCHESTRATOR.md`.
- **B-2 RSS runner** — `tools/runner` (Python, stdlib only) +
  `docs/infra/runner.md`. Auto-adds `-O ReleaseFast` /
  `-Doptimize=ReleaseFast`; SIGKILLs the process group on a 4 GB
  RSS breach. Prevents the 02:37 panic class.
- **Host incident record** — `docs/infra/host/incident-2026-07-29.md`
  (durable in git). Corrected root cause; the four follow-ups
  (B-1 done, B-2 done, B-3 Dabir's call, B-4 Dabir's call).
- **EXP-2 brief retired**; the work is in `EXP-2A` (done) +
  `EXP-2B` (dispatchable, dispatched to Minimax-m3, gated on the
  runner).
- **Instruction files updated** — `AGENTS.md`, `ORCHESTRATOR.md`,
  `ROLES.md`, `DELEGATOR.md`, `DELEGATEE.md`, `EXP-2B.md` all
  mention the dispatch/claim protocol and `tools/runner`.
