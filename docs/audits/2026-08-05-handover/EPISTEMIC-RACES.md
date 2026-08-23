# EPISTEMIC RACES — head-to-head model evaluation on the capabilities this project runs on

Author: Fable · 2026-08-05 · companion to `ROADMAP.md` (this directory) and `docs/epics/E1-markovian/LANDMARKS.md`
Protocol substrate: T328 bake-off harness (answer-key-first, blind grading, sealed lane map,
both clocks + operator-collected tokens, tokens-now-prices-later). Baseline beliefs to race
against: `docs/infra/model-perf.md` §Belief audit 2026-08-05.

**Why these capabilities.** The ledger says the project's scarce resource is not coding:
every catastrophic failure was epistemic (the tautological differential, the stubbed battery,
the 22-entry sample tabled as PASS, 76 PROVEN rows without evidence), and the only mechanism
that ever found a real defect was independent re-implementation plus differential comparison.
The doctrine mechanizes epistemic *discipline* (claimlint, mutation gates, controls); what
cannot be mechanized — and what these races measure — is generating the right doubts.

**Who evaluates: nobody trusted, everybody checked.** Grading is layered so judgment shrinks
to a checkable residue — claimlint's architecture applied to model evaluation:
1. **The answer key** does most of it — written and hash-committed BEFORE dispatch (T316
   pattern); lanes run in worktrees that do not contain it; keys drawn from the project's
   historical defect catalogue, so key-author bias is minimal (history wrote the key).
2. **The harness executes** what can be executed (race 1 is graded by running the outputs).
3. **A blind grader console** handles only prose residue, under the T328 grader-validity
   bars: family exclusion, null + seeded calibration before scores count, lane map sealed
   until scores recorded. Mechanical anchors are present in every race, so a grader whose
   scores contradict the anchors flags itself.
4. **The human rules only on discoveries** — unkeyed findings that claim to be real.

---

## Race 1 — falsification design (graded by execution, not opinion)

- **Input:** a claim packet (claim, code, evidence) seeded with N defects from the
  historical catalogue — key mismatch, tautological differential, control that cannot fire.
- **Output (one doc per lane):** the experiments that could kill the claim, **as runnable
  tests, not prose**.
- **Scoring, fully mechanical:** run each proposed test against the clean twin and the
  seeded mutant. Kills the mutant AND passes the clean version → point; anything else →
  zero. Report recall (seeds caught / N) and false-alarm rate. The mutant grades the
  proposal — no judge involved. This is the mutation doctrine turned onto the models.
- **Direct project benefit:** winning tests are real battery candidates; a proposed killer
  nobody thought of is a new battery check regardless of which lane wrote it.

## Race 2 — honest refusal (a confusion matrix, fully mechanical)

- **Input:** M claim packets — some genuinely promotable, some carrying exactly one flaw
  each (no denominator, dangling evidence path, sample presented as census; all historical).
- **Output:** a verdict doc per packet — promote or refuse, **with the gap named**.
- **Scoring:** confusion matrix against the key. Naming the *correct* gap earns the point,
  not the refusal itself — **blanket skepticism must lose**: refusing everything scores as
  badly as promoting everything. The measured quantity is calibration.
- **Contamination control:** lanes receive only the packet, never repo access — the
  register contains the answers.

## Race 3 — prior-art mapping (keyed names, judged residue)

- **Input:** de-jargoned descriptions of project methods and open problems.
- **Output:** literature name + citation + what the literature offers that we have not
  imported.
- **Scoring:** name-match is mechanical (key holds: mutation testing DeMillo–Lipton–Sayward
  1978; golden master, Feathers 2004; retrograde/tablebase methods; proof-number search;
  **van der Werf's 5×5 Go solution 2003 — the exact prior art for the 5×4/5×5 frontier;
  Schaeffer's checkers proof — the exact prior art for landmark L6**). Only the
  "what it adds" paragraph needs the blind grader.
- **Direct project benefit:** unkeyed mappings that survive human ruling are free research
  leads — this race can amend the roadmap.

## Race 4 — procedural reliability (NOT a race document; measured in situ)

Measured on real rows only: checkpoints polled, holds declared, both findings files
present, committed through the tool, budget respected. The ledger scores it; the scorecard
counts violations per dispatch. An artificial exam here would measure exam behavior, not
work behavior. (T365, deepseek-v4-flash post-bump, is the current clean specimen: read the
isolation doc before touching an Orchestrator-owned file, re-verified its reference map
against the post-rename tree, proved content integrity by reverse-application — none of it
demanded by the brief.)

## Race 5 — formal precision (seeded inconsistency audit)

- **Input:** an axiom set plus a subtly inconsistent variant (the real MIGOS tie-semantics
  contradiction is the canonical historical seed).
- **Output:** a consistency audit document.
- **Scoring:** seeded inconsistency found or missed, false alarms counted — mechanical
  against the key; prose residue blind-graded.

---

## Standing properties

- **Entrance exam:** any new model or preview-channel bump runs the same five packets
  before joining the roster. The item bank grows the way the mutation catalogue does —
  every new real defect the project suffers becomes an exam item, so the exam hardens
  exactly as fast as the project learns.
- **Nothing is throwaway:** race-1 winners join the battery; race-3 discoveries amend the
  roadmap; packets double as grader-calibration fixtures for future runs.
- **Per-seat scoring, never one ranking:** capabilities 1–3 and 5 concentrate in Auditor
  and research seats; capability 4 dominates workers and sprint managers; they are nearly
  independent. "Best model" is a per-seat answer, which is the shape the tokens-now,
  prices-later accounting already anticipates.
- **In-vitro caveat, recorded honestly:** races 1–3/5 measure capability under exam
  conditions. The 22-entry-sample catch happened embedded in a live session under competing
  pressures — exam results are evidence, not proof, of seat performance. Race 4 stays
  in situ and the operator's ~daily deep audits remain the backstop regardless of winners.
- **Cost:** packets are bounded; per-lane cost is a fraction of one real row — cheap enough
  to re-run per roster change, which is what makes temporary-default experiments (e.g.
  Flash-for-everything, expires 2026-08-12) reversible with data instead of impressions.

## Registration order (for the Orchestrator)

1. T328 dry-run (harness plumbing) — already registered, dispatchable.
2. **Packet authoring + key sealing** — one row; keys hash-committed before any lane runs.
   The packet author's model family is recorded; historical seeds keep authorship thin.
3. First runs: Pro-vs-Flash on races 1 and 2 (operator's demanded comparison, now with the
   preview-bump serving-tag caveat from model-perf.md), then the wider roster.
4. Orchestrator-aspect races (triage, verdict discipline, inbox, crash recovery, dispatch
   authoring — see model-perf.md §Belief audit) share the same protocol and can reuse
   packet infrastructure.
