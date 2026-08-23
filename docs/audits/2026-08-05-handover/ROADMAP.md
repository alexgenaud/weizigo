# ROADMAP — mission audit and handover to the Orchestrator

Author: Fable (Claude Fable 5), holistic-audit seat · 2026-08-05 · at HEAD `345ab84`, tree dirty
Audience: the incoming Orchestrator (Opus). STATE.md remains the crash anchor; this file is
the mission-level audit and the ordered roadmap DIRECTION.md said was owed ("the roadmap that
decomposes it into tasks is a follow-up deliverable and belongs to the next session's court").
This document recommends; registering rows and writing delegation packages stays with Orcha.

Human-visible checkpoints for this roadmap live in `docs/epics/E1-markovian/LANDMARKS.md` — the
tiers below are the dependency truth; the landmarks are the same journey as observations.

Governing docs, in authority order: `docs/audits/2026-08-02-grand-audit/DIRECTION.md`
(+ Amendments 1–2) · `docs/epics/E1-markovian/WAYPOINTS.md` · `docs/infra/sprint.md` ·
`docs/infra/human-decisions.md` · STATE.md (working-tree version, see finding 3).

---

## 1. Mission — unchanged, ratified, still the right one

Complete E1-markovian in place: prove theorem Z — for each goban size in
{2×2, 3×2, 3×3, 4×3, 4×4} (4×3 inserted as ladder rung 4 by spec Rev 5), under ruleset R as
written in AXIOMS.md, the table gives the exact game-theoretic fresh-start [L,H] bracket for
every legal (position, side), with explicit non-claims for everything else. All register rows
presumed unverified until re-derived; kernel written once with epic-01's implementations
demoted to differential oracles; battery calibration by mutation testing gates *promotion*,
not dispatch (Amendment 2); every gate mechanized the day it is declared.

Nothing in this audit argues for amending the mission. The bar for any adjusted Z stands:
at least as good as today's 4×4 engine, fixed upon whatever is demonstrably better.

## 2. Where the mission stands, phase by phase

| phase | state | evidence |
|---|---|---|
| 0 — theorem & axioms | **done** | T271 AXIOMS.md; T305 mapped 323 register rows onto the requirement tree (116 proposed-retired, 6 new-work gaps), C9 (UNMAPPED) mechanized and at 0 |
| 1 — battery before code | **delivered** | T290 spec / T291 mutants / T292 baselines; golden-master gate inside `zig build test`, full sweep behind `zig build battery-sweep`; calibration PASS today |
| 2 — kernel extraction | **landed, unpromoted** | T273 (`koAfterCapture`, `stateKey`) + T339 MG-KERN (`legalMoves`/`applyMove`/`applyPass`, kernel-vs-solver differential 0 mismatches at 2×2/3×2/3×3 incl. ko≠NONE). Claims correctly held at CLAIMED per the Amendment 2 promotion gate |
| 3 — A–Z reverification | **begun de facto, never decomposed** | G3b (value-correctness gate) pass0 ran: 0 Bellman violations / 95,677,624 entries; 0 key mismatches / 99,133,036; 0 move-set mismatches at every rung incl. 4×3. **G3b NOT discharged** — closure (C-A1/C-A2) was tabled as PASS on a 22-entry sample and corrected to Deferred; I5 cycle containment incomplete at 4×3/4×4; M8/M10 mutants unwired. T363 holds the four gaps in cost order |
| 4 — the swap | not decomposed | correctly blocked on Phase 3 differential verification (dependency edge 4) |

The honest sentence from STATE.md §1 still governs and must not be shortened: *the 4×4
artifact is structurally complete; its values are verified for Bellman residual and key
agreement at full scale, and not yet for closure or cycle containment.*

## 3. Audit findings (2026-08-05, instruments run, not documents read)

1. **C7 (UNABSORBED findings) is live at 4 FAILS plus 3 non-conforming files.** STATE.md §4
   says C7=0 — stale; the end-of-session findings the Orchestrator committed on the consoles'
   behalf were never absorbed. `bin/weizigo-claimlint` run this session confirms. An absorb
   pass (STANDING-ABSORB) is owed before any gate reading counts.
2. **The deployed `bin/managent` is STALE** — built at `9247e2d`, source now `345ab84`
   including the T355 inbox loop. `bin/managent resume` says so itself. Rebuild and
   `zig build deploy-managent`, then `sh tools/smoke.sh` (STATE rule 6).
3. **The STATE.md rewrite is uncommitted.** The working tree carries the Opus close-down
   rewrite (586 lines → 120); HEAD still has the old long version. Commit it first — a crash
   now loses the anchor this whole recovery scheme depends on.
4. **24 unread directives (D007–D036) sit STALL in the bus**, including pause/kill directives
   for rows already closed. Dead noise for the new inbox loop; ack/drain them as part of T354
   (register triage) so the bus starts clean.
5. **C3 (UNBACKED) = 76 of 100 PROVEN rows have no committed evidence** — the largest
   epistemic debt, and report-only, which is exactly why it grew unnoticed. Also live:
   C4 = 40 dangling claim IDs, C5 = 4 shadowed dependencies (both report-only).
6. **T360's open question is answered and closed** — recorded in `findings/T335-g3b-build-sprint.json`:
   `qa023_brute_2x2` was never imported by any `zig build test` target; only bare `zig test`
   pulls it. Not a regression from T339's extraction. STATE rule 7 is the standing protection;
   no further diagnosis owed.
7. **T361 (old-vs-new 4×4 engine kifu, SGF for genuine losses) died with no work in tree.**
   The row is closed-abandoned, but the deliverable is unowned — and it is the mission's own
   Z-bar evidence ("at least as good as today's engine"). Re-register when a console is free.

## 4. The roadmap, in dependency order

**Tier 0 — hygiene, before anything reads a gate** (hours, one console or Orcha directly):
commit STATE.md → rebuild/deploy managent → smoke with zero STALE → run STANDING-ABSORB
(C7 4→0) → ack the stale directive backlog. None of this is optional; findings 1–4 above.

**Tier 1 — the critical path to Z:**
- **T363** (G3b completion): full 4×4 closure run, 4×3 retroactive rung for I4 (Bellman) and
  key agreement, I5 cycle containment at 4×3/4×4 with the owed memory breakdown (plan said
  ~1.2 GB, measured 4.1 GB — a 3.4× model error that must be explained, not shrugged at),
  M8/M10 mutant assertions. 8192 MB is authorised for the I5 runs; use
  `bin/subagent --rss-cap-mb` — two prior attempts were RSS-killed, not wrong.
- Orcha discharge ruling on G3b once all four close, with denominators (STATE rule 2).
- **T348** (DISCHARGE) — blocked in practice until that ruling; do not let a console claim it early.

**Tier 2 — decompose Phase 3 properly** (the step skipped so far; G3b is one lemma, not the phase):
- Ratify T305's 116 proposed-retired rows into `archives/` with epitaphs (operator ruling:
  archive, never delete — so no per-item approval needed).
- Open rows for T305's 6 new-work gaps.
- Row-by-row re-derivation against the requirement tree, ladder order
  2×2 → 3×2 → 3×3 → 4×3 → 4×4; kernel vs frozen fixtures differentially at every rung.
- Promote the Phase 2 kernel claims held at CLAIMED as their mutants are killed — C8
  (mutation adequacy) is the currency; consider making C8 fail rather than report as
  promotion volume grows.
- **T354** (register triage) with the C3 ratchet belongs to this tier: re-derivation is what
  backs the 76 UNBACKED rows; the ratchet is what stops the number regrowing.

**Tier 3 — Phase 4 swap.** Decompose only when Tier 2's differential rungs pass. Contents per
DIRECTION §5: kernel becomes production, legacy frozen as fixtures, engine/experiment
boundary in `src/`.

**Background, set G (fleet safety — cheap, protects a host that has already OOM-panicked):**
T362 (fleet-aware memory guard — per-process caps do not compose), T364 (parent-side exit
records + `managent reap` — this session's three orphans were undiagnosable without it),
T357 (measure the Ollama concurrency limit — the five-simultaneous belief is inference).
Also queued: T350/T351/T352/T353 (managent robustness), T328 (bakeoff harness).

**Frontier — hold until Z, and until the machine is quiet:** T358 (scaling census; it
rebuilds artifacts), the 5×4/5×5 entry decision informed by T359's measured 16× symmetry
fold (4×4 = 15.94×, Q2 truncation refuted). Epic-02 (k=2+) stays unchartered per DIRECTION §3.

## 5. Allocation notes (recorded behaviour only, per standing rule)

Briefs never name a model; for dispatch-time choice: glm-5.2 delivered I4, SMD1, T359 and
T356 cleanly; deepseek-v4-pro delivered I5/I11 code and KEY-4×4 but was RSS-killed twice at
4×4 scale — pair it with the raised cap; minimax-m3 delivered the inbox loop. T363 is a
whole-sprint package for one console per the Orcha-delegates-sprints ruling. Fable is
reserved for high value-per-token holistic work, handed over before 90% of 200k.

## Addendum — close of the Fable session, 2026-08-05 (after T365)

Written at handover, same authority as the rest of this document. What changed since §1–5:

- **Finding 3 is resolved:** STATE.md's rewrite is committed (`9a1a6ae`, via T365's
  path-limited escape hatch). **Attribution note for the incoming Orchestrator:** the
  rewrite rode along under T365's message, flagged by the worker itself for optional
  re-attribution; likewise `docs/infra/model-perf.md`'s belief-audit and temporary-default
  sections rode along in `048af65` (they are Fable's work, committed by the sweep). History
  stands; the findings notes carry the attribution.
- **T365 is done and verified by this seat** (instruments run, not report read): 0/32
  old-name hits repo-wide, `ls docs/audits/` chronological, C2=14 with calibration PASS.
  The governing document now lives at `docs/audits/2026-08-02-grand-audit/DIRECTION.md` —
  every doc citing the old path was repointed; out-of-repo pointers (operator memory,
  console prompts) must be hand-updated.
- **Temporary allocation ruling (expires 2026-08-12):** deepseek-v4-flash is the default
  for ALL new dispatches — worker rows and sprint-manager consoles — unless a task-type or
  role weakness is recorded in model-perf.md with the row that showed it. **T363's console
  is therefore the first sprint-manager trial on Flash.** At expiry, re-rule on the week's
  ledger. Full ruling: model-perf.md §Model versions.
- **Model evaluation is now chartered:** the confirmation-bias finding and the belief
  baseline live in model-perf.md §Belief audit; the head-to-head designs (five epistemic
  races, grading layers, entrance-exam property) live in `EPISTEMIC-RACES.md` beside this
  file, with a registration order for the Orchestrator. T328 carries the grader-validity
  and timing/token bars in its brief.
- **Tier 0 correction:** the absorb debt has grown — T365 added two more findings files;
  expect C7 (unabsorbed findings) above the 4 measured in §3. The managent binary is still
  stale. Tier 0 stands as written, only larger.
- **SIMD (operator question, answered):** no explicit SIMD anywhere in `src/`/`tools/`;
  ReleaseFast auto-vectorization and u64-bitset popcount are the current parallelism.
  Explicit `@Vector` work is a post-Z optimization, gated on T358's measured census — a
  frontier line item, not current work.

## 6. What this document is not

Not the Phase 3 task decomposition (Orcha's to register), not a plan-doc revision (spec and
plan are both Rev 5, RATIFIED, untouched), and not a claim of anything beyond §3's findings —
each of which cites the instrument that produced it.
