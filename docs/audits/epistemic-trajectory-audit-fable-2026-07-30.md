<!--managent set=A-->

Task: user-dispatched trajectory audit · Role: Auditor · Model: Fable 5 · Date: 2026-07-30

# Are we going in circles? — an epistemic-trajectory audit

**Question asked (the user, verbatim in substance):** review the epistemic
tree, recent tasks, tasks in progress and queued. Are we going in circles on a
wild goose chase, or making epistemic and go-playing progress?

**Verdict up front: this is a spiral, not a circle — but one leg of the
current experiment ladder is walking toward the project's characteristic
failure a third time, and it should be stopped before EXP-6 spends the 4×4
build.**

A circle returns to the same question with no new constraint. A spiral
returns to it with the space narrowed. Every revisit in the last week added a
constraint, and the audit trail shows it. The go-*playing* progress, by
contrast, is close to zero and honestly so — see §4.

Scope reviewed: `docs/epistemic/` (PROGRESS.md, CLAIMS.md, knowledge-ladder.md),
`docs/status/CURRENT.md`, the kanban (`bin/managent status`: 33 done, 2 in
progress, 2 blocked, 1 failed), the last 30 commits, the EXP-4 deliverable
(`docs/research/newrule-2x2-3x2-2026-07-28.md`), the EXP-5/6/7 briefs, and a
live `bin/weizigo-claimlint` run.

---

## 1. Evidence this is progress, not circling

**1.1 The foreclosures are measured, monotone, and non-repeating.** PSK exact
solve (R1), score-on-cycle (R2), bounded N-ply (RPLY), kill-X% (R3) — each was
tested once, measured, closed, and never re-opened. Nobody has re-litigated a
foreclosed candidate. That is the signature of a search, not a chase.

**1.2 The error-correction machinery catches its own defects — twice over.**
The sequence that looks most like a circle from a distance is QA-023/QA-026:
falsified → withdrawn → re-falsified under one semantics, untested under the
other. Read closely, it is the opposite of circling:

- the 2B probe "falsified" C2 → 2B-3-AUDIT found the history generator
  systematically biased (C1 was *untested*, not unrefuted);
- 2B-PROBE-FIX fixed it → the falsification stood on numbers that were
  artefacts (σ in its own arrival set, 1,133/1,133 collisions);
- the corrected falsification stood on a **defective kernel** — found
  independently by two seats (Kimi-k3, Kimi-k2.7) via re-implementation:
  `fixpoint_kernel` never updated White-to-move states, so
  `median(−6,TIE,+6)=0` by construction and every counterexample was
  White-to-move;
- the corrected kernel produced a **hand-traceable C1 witness** at 3×2
  (state (178,0,6,0): two arrivals → −3 vs −6, fixpoint says −6), verified
  node-for-node by two independent implementations (QA023-C1-WITNESS).

Each pass through the "same" question retired a specific instrument defect
and left a sharper claim. The register now correctly splits the question by
semantics (`GLOBAL.H1-MARKOV:UNTESTED` vs `GLOBAL.H1-COMPUTABLE:FALSE-AS-SCOPED`).
This cost ~a week and it was worth it: the standing rules in PROGRESS.md §9
("independent re-implementation is the only thing that has ever found a
defect in this project") are now demonstrably enforced, not aspirational.

**1.3 EXP-4 is the first genuinely new go-domain result of the pivot.** 2×2
and 3×2 return **0** under basic-ko + TIE=0 where PSK returns **+1** — the
first anchor comparison in project history where the rule difference *bites*
and the build lands on the published side of it. Every prior anchor match
(3×3 +9, 4×4 +2) was agreement between different games where the difference
didn't bite. The gate was designed to be falsifiable (0-vs-+1) and it passed.

**1.4 The narrative layer is now mechanically honest.** PROGRESS.md is
cite-tagged and linted (C6: 0 mismatches, calibration PASS). "What not to
say" (§8.3) exists and is right. The knowledge ladder separates epistemic
strength from rule fidelity — which is precisely the axis on which the
project has historically fooled itself.

---

## 2. The live wild-goose-chase risk: the semantic fork under the EXP ladder

This is the finding of this audit.

**ADR-0019 (accepted) says first-revisit truncation *is* the rule.** Under
that semantics, at 3×2, the state `(board, side, ko_point, passes)` is
**insufficient** (`GLOBAL.H1-COMPUTABLE:FALSE-AS-SCOPED`) and the median pin
rule is **falsified** (`QA-026:FALSE-AS-SCOPED`).

**EXP-4 built the fixpoint-median object anyway** — and its own write-up
documents the divergence *at fresh start*, not just under exotic histories:

- 2×2 brute-force sample: **24/172 mismatches**, every one of the pattern
  fixpoint = ±4 vs truncation = 0;
- the committed 1-ko-shape anchor from `qa023_brute_2x2.zig` (expected 0)
  **disagrees** with the fixpoint (−4);
- 3×2: 165/165 within-budget agreements, but 335/500 exhausted — the
  agreement sample is budget-censored exactly where cycles live.

So the object EXP-4/5/6/7 are building is internally sound (L=Φ(L), H=Φ(H),
0 inversion violations) but it is the value table of the **loopy-game
fixpoint semantics**, which the project's own accepted ADR says is not the
rule. The roots agree at 2×2/3×2; the tables provably do not.

**Why this is the characteristic failure recurring.** The knowledge ladder
names the pattern: a high Axis-A score (exact, converged, symmetric,
reproducible) reported as settling Axis B (*which game is this the value
of?*). It happened with `4x4.ANCHOR` (PSK +2 "matches" a basic-ko
publication). It happened with the "certified core" (fresh-start exactness
sold as history-independence). The EXP ladder is now positioned to do it a
third time: EXP-5's acceptance criterion is a **root** anchor (+9) plus
internal consistency — and EXP-4 just demonstrated that root agreement
coexists with per-state divergence from the declared rule. A matched +9 at
3×3 will *feel* like validation of "the rule EXP-2 pinned down" while the
non-root table is the value of a different semantics. EXP-6 then spends the
long 4×4 build (minutes-to-hours, 177 MB-class artifact) on an object whose
rule identity is unadjudicated.

To be precise about what is and is not wrong: the loopy-game fixpoint
semantics is a legitimate, well-defined, Markovian game, and it may well be
*closer* to what MIGOS II actually computed than truncation is — that
question is open. The failure mode is not "wrong object"; it is **unstated
object**. The fix is cheap and it is an adjudication, not an experiment.

**Recommendation R1 (before EXP-6, ideally before EXP-5 reports):** the user
rules on which semantics the deliverable is the value of — amend ADR-0019 or
file ADR-0020. Two coherent positions exist: (a) the deliverable *is* the
loopy-game fixpoint table, truncation demoted to a reference probe, and every
EXP write-up states "value under loopy-game semantics; diverges from
first-revisit truncation at N known states"; or (b) truncation stands as the
rule, in which case the EXP ladder's tables are not the deliverable and the
ladder halts at EXP-5 pending PINRULE-SUFFICIENCY-class work on a richer
state. What is not coherent is passing gates under (a) while the register
scopes falsifications under (b).

**Recommendation R2:** EXP-5's calibration case 2 (the checker must
distinguish the new table from the PSK artifact *below* the root) is well
designed — keep it. Add a third calibration: the 24 known 2×2
fixpoint-vs-truncation mismatch states as a standing known-divergence
fixture, so every later build re-measures the semantic gap instead of
forgetting it.

---

## 3. The meta-work ratio — high, defensible, and at its ceiling

Of the last 30 commits, roughly **half** are orchestration/infrastructure:
managent schema and derive-status, agent identity, role files, stream
discipline, standing cleanup, orchestrator automation, narrative/index/
claims-hygiene wave, handovers and successions. In progress right now:
WORKER-CHANNEL (infra) alongside EXP-5 (domain) — the working tree's +610
lines are all managent/runner.

Judgement: this was mostly *earned* overhead, not displacement activity. The
kernel panic was real (12.5 GB Debug build → watchdog death; `tools/runner`
fixed the class). The kanban defects were real (a gated task stayed
claimable; everything printed to stderr). And the infra demonstrably paid
epistemic dividends — the multi-seat dispatch machinery is what produced two
independent kernel-bug discoveries and the unanimous QA-018 panel.

But the ratio is at its ceiling. The infra now works; further polish is
displacement. **Recommendation R3:** after WORKER-CHANNEL lands, hold new
infra registrations unless they block the EXP ladder. If the next 30 commits
are still one-third meta, that — not the QA-023 spiral — is the circling to
worry about.

---

## 4. Go-playing progress, honestly

Near zero, and the tree says so itself. The GTP player still consults
fresh-start PSK tables and is **K5 (guess)** in the ko-sensitive region,
which at 4×4 includes the empty board — so it is K5 from move one. EXP-9's
H5a mitigation is real but PARTIAL (fires at ply 13, not the predicted 7;
+6.8% per genmove; CLAIMED, not verified-optimal). No playing-strength change
since.

This is acceptable *if* it is understood: the plan routes all playing
improvement through the new-rule tables (EXP-6) plus a new player, which is
two gates away. Nothing on the kanban shortcuts that, and given C3's
falsification (bracket leaks up to 12 points at 3×3), a shortcut would be
unsound anyway. But nobody should believe the engine plays better today than
it did on 2026-07-27.

---

## 5. Ledger health — debts that will bite

Live `bin/weizigo-claimlint` (2026-07-30): calibration PASS, C6 = 0, but:

- **10 C1a orphans and 11 dangling evidence paths — currently FAILING.**
- **76 PROVEN rows without committed evidence** (C3, debt-only for now). At
  256 rows that is ~30% of the ledger claiming the top status without a
  committed artifact behind it. The ladder's rule — "losing the evidence
  drops you a rung" — is not yet enforced by the linter.
- **T13 is the load-bearing falsification of the whole strategy and its
  probe source is deleted** (knowledge-ladder §2). PROVEN-but-unreproducible.
  **Recommendation R4:** re-implement the T13 probe (independent seat, per
  the standing rule) or explicitly downgrade every claim that leans on it.
  This is the cheapest way the current edifice could be embarrassed later.

---

## 6. Summary verdict

| dimension | verdict |
|---|---|
| Epistemic progress | **Real and unusually well-audited.** Foreclosures monotone; falsifications independently verified; defective falsifications caught and withdrawn; first rule-distinguishing anchor passed (EXP-4). |
| Circling | **No closed loops found.** Every QA-023 revisit retired a named instrument defect. The one repeated *pattern* is Axis-B confusion, and it is about to recur (§2). |
| Wild-goose-chase risk | **One, live, cheap to defuse:** the EXP ladder builds loopy-game-semantics tables while ADR-0019 declares truncation the rule. Adjudicate before EXP-6 (R1), pin the divergence as a fixture (R2). |
| Go-playing progress | **~None since 2026-07-27**, by design; routed through EXP-6, two gates away. Say so plainly when reporting. |
| Overhead | Meta-work ≈ half of recent commits; earned, but at ceiling (R3). |
| Ledger | Linter failing on orphans/dangling paths; 76 evidence-free PROVENs; T13 unreproducible (R4). |

The project is not chasing a goose. It is chasing a well-posed K2 deliverable
— *provably optimal 4×4 play under basic ko + fixed-value tie, with a
measured PSK divergence* — and the negative results accumulated on the way
are themselves a publishable constraint map. The single action that most
protects the next week of compute is a one-paragraph ruling on which
semantics the tables are the value of, made before EXP-6 starts.

— Fable 5 / Auditor, 2026-07-30
