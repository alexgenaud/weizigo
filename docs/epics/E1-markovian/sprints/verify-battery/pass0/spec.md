# verify-battery — SPEC

```
Status:   RATIFIED (G1, 2026-07-31) — executed through P3-H (T168–T187);
          G3 open (V-13 fleet run, V-14 absorption)
Author:   Opus/Navigator (claude-opus-5[1m]) · 2026-07-31
Revised:  Fable/T136 · 2026-07-31 — live copy; the pass-0 original is
          frozen at docs/epics/E1-markovian/sprints/verify-battery/archive/spec.md. Resolves
          spec-audit B1–B2, C1–C3, M1–M7, S1–S4, O1–O4 and the
          strategy-audit's inherited-fact corrections SB1, SB2, SC1, SC2,
          SM4, SM5, SO2. Each resolution is tagged [Xn].
Process:  docs/infra/sprint.md · audit grading: blocker/critical/must/should/could,
          PASS/NEEDS-FIX/REDO [SM1]
Tier:     A — one instrument, run ~60 times; a defect in it is invisible
Inputs:   docs/epics/E1-markovian/sprints/verify-battery/archive/{spec,spec-audit,strategy,
          strategy-audit}.md · docs/epics/E1-markovian/sprints/verify-battery/archive/
          i5-feasibility.md (DSPro/T134)
Audit:    this revision, before any design task is dispatched
```

## 1. The problem

Epic-01 closes when the epistemic tree is complete at every solved goban —
2×2, 3×2, 3×3, 4×3, 4×4. That is a dozen verification questions across five
gobans: **sixty cells** — enumerated in §6a, no longer a gesture [SM4] —
most of which have never been evaluated.

**The obvious way to fill sixty cells is sixty agents. That is the way this
project has already failed.**

`Opus/T102` found buffer aliasing in the brute-force cross-checks of **EXP-4
through EXP-7** — every independent implementation, agreeing with every other,
every one unsound. Many instances of one bug, all reading as corroboration.
Sixty unreviewed checkers would reproduce that at fleet scale, and sixty
agreeing runs would feel like proof.

So: **one instrument, adversarially reviewed once, invoked sixty times.** The
review of the instrument is the load-bearing work of this sprint; the runs are
cheap.

A corollary the pass-0 audits added: an instrument calibrated against
unverified numbers is the same failure in a different place. **Every
calibration target in this spec is now cited to the tracked register by
`file:line`**, and where the register holds two values for one quantity, both
are named. [SB2]

## 2. What to build

A single tool that, given a goban size and an artifact, evaluates a fixed set
of invariants and emits a machine-readable result plus proposed claim rows.

**This spec does not choose the implementation, the output format, or the
invariant algorithms.** Those are `design.md` (V-4). The I5 memory plan is
already costed in `docs/epics/E1-markovian/sprints/verify-battery/archive/i5-feasibility.md` [B2].

## 3. Requirements

| id | requirement | rationale |
|---|---|---|
| **R1** | One binary, parameterised by goban size and artifact path. Not one tool per goban, not one per invariant. | §1 |
| **R2** | Every invariant ships with a **known-bad fixture** that it must fail. A check that has never failed has not been shown to work. | standing rule 2; `2B-5`'s positive control passed while covering none of the defective call site |
| **R3** | Every reported number states its **denominator**, including the within-budget denominator when anything is sampled. | standing rules 3 and 6; `budget-exhausted: 0` on an exponential harness is a red flag |
| **R4** | The tool **never writes** `CLAIMS.md`, `PROGRESS.md` or `STATE.md` — nor any file of the resume surface (`bin/managent resume` composes it at read time; `CURRENT.md` is retired 2026-08-03). It emits *proposed* rows into its own evidence directory. | sixty concurrent writers to the register is a corrupted register, silently |
| **R5** | Exhaustive by default; sampling only where exhaustive is infeasible, and then the sample size, seed and denominator are reported. **The per-invariant, per-goban evaluation mode is fixed by the §6a matrix** [M1]. | per-goban independence means a 4×4 sample proves nothing at 4×4 either, unless it says so |
| **R6** | A failing invariant is a **non-zero exit and a named failure**, never a warning buried in output. Exits fall into **three classes** [M3]: **artifact-bad** (the invariant computed cleanly and the artifact violates it), **reference-bad** (the invariant computed cleanly and disagrees with a *committed register figure* — the register entry goes to audit, not the artifact), and **battery-bad** (the harness could not complete: OOM, stack bound, load error). One exit code per class, distinguishable by machine. | `stdout` = data, `stderr` = diagnostics (`AGENTS.md`); the 3×2 census spread (§5 A3) shows reference-bad is a real case, not a hypothetical |
| **R7** | Runs within the `tools/runner` budget: ≤ 4 GB peak RSS per invocation. Concurrency is limited by **RSS, not agent count**: at most two 4×4-scale invocations in flight project-wide (this sprint and oracle-v2 combined). **Enforcement is Orcha's dispatch pacing, with the human as backstop; the battery does not self-throttle** [O4]. A seat wanting a heavy run and unable to see the global count asks before dispatching. | EXP-6 peaked at 3,137 MB; the host kernel-panicked at 12.5 GB on 2026-07-29 |
| **R8** | **Shared-code policy** [M7]: the battery imports **nothing from `src/`**. It re-implements the artifact loader, the colex/rank addressing (`rank_from_pos` / `pos_from_rank`), and the basic-ko rules engine. Rationale: every module shared with the solver is a blind spot every invariant inherits; the only instrument that has found a defect in this project is independent re-implementation (QA-023 — kernel audit "reproduced all three evidence lines from scratch in Python, no Zig imported", `docs/epistemic/CLAIMS.md:557`; T103's fixture is "a standalone implementation sharing no code with the Zig solver", `docs/evidence/QA-026/calibration-2x2-mismatch.py:20-21`; the retired sprint doc's standalone-tool rule, `docs/infra/sprint.md:22`, is the adjacent precedent). **This is the costliest decision in the spec and is flagged for the human at G1**: the alternative (import `src/` and rely on A5's one re-implemented invariant) is cheaper and weaker. |

**Out of scope:** deciding any claim's status; editing the register; solving
anything. The SCC *census* as a register deliverable remains separate work;
the battery computes SCCs only to evaluate I5.

## 4. The invariants

Twelve invariants: the original nine (I8 restated, see below) plus three the
pass-0 audit found missing [B1, C1, M6].

| id | invariant | what it catches | precedent |
|---|---|---|---|
| **I1** | `pin_L == pin_H` | inverted-branch guards | the tell that exposed the `fixpoint_kernel` bug (`pin_L=142, pin_H=0`) |
| **I2** | colour inversion, exhaustive: `V(−pos,−side) == −V(pos,side)`; on bracket tables `L(−pos,−side) == −H(pos,side)` | sign defects | EXP-9 had one, now pinned by a test |
| **I3** | `L ≤ H` everywhere | fixpoint corruption | — |
| **I4** | Bellman residual: `L = Φ(L)`, `H = Φ(H)`, count of violations with denominator. On WZO1: restricted to KO_SENSITIVE-clear slots; KO_SENSITIVE-set children may contaminate Φ — full check deferred to WZO2 (T172/T180 GAP-1). | solver and serialisation error | T104: 0 / 99,133,036 at 4×4 — make it standing, not one-off |
| **I5** | `KO_SENSITIVE ⊆ cycle-reachable` | value table vs. graph structure, reading **no** stored values | the structural theorem; feasibility, fixture and calibration in `pass1/i5-feasibility.md` [B2, C2] |
| **I6** | UNDEF census: illegal / legal-both-sides / legal-one-side-only, union against the OEIS legal count | serialisation holes | 4×4 v1: 24,187,097 / 65,534 / 65,534, union 24,318,165 = A094777 |
| **I7** | DTT sanity: (a) terminals at 0, (b) non-terminals satisfy `DTT(state) == 1 + min(DTT(children))` (recurrence check, T172/T180 GAP-3), distribution reported. **Denominator: the compact slot count (99,133,036 at 4×4), not the dense 3¹⁶ = 43,046,721 position count** [SO2]. The defect signature is **uniformity including terminals** — 255 alone is the defined `DTT_FAR` sentinel and is legitimate on far states. | a schema-present, data-empty column | v1's DTT column is uniformly 255 across all slots |
| **I8** | **truncation-gap regression fixture** [SB1]: the 24 formerly-mismatched 2×2 states must **agree** between the loopy-game fixpoint and exact first-revisit truncation — expected gap **0 mismatches / 172 reachable non-terminals**. The states and both evaluators are committed in `docs/evidence/QA-026/calibration-2x2-mismatch.py` [M4]. A non-zero gap means semantic drift *or* a reintroduced aliasing defect. | semantic drift between builds; buffer aliasing regression | `Opus/T102`: all 24 "mismatches" were checker artifacts (`docs/audits/2026-07-30-audit-2x2-mismatch.md`); T103 locked in agreement. **Polarity note:** ADR-0020:47-49 still calls these states a "mismatch" fixture; that clause predates T102's finding and its amendment is a G1 agenda item. Cite T102/T103, not ADR-0020, for this invariant. |
| **I9** | anchor check against committed root values where they exist: 2×2 = 0, 3×2 = 0, 3×3 = +9 | pipeline regression | note 4×4 is **+1 vs MIGOS +2** and is an open discrepancy, not a failure; no 4×3 anchor is committed — that cell reports "no reference" rather than inventing one |
| **I10** | **TIE value correctness** [B1]: `TIE ∈ [L, H]` at every non-terminal. (The formulation `TIE = median(L, TIE, H)` is equivalent when `TIE ∈ [L, H]` — the bracket check is the operational invariant; T172/T180 GAP-4.) | a corrupted TIE column with a plausible distribution — wrong values, sane histogram | QA-023: the median pin gadget exists precisely because TIE can be wrong while L and H look sane |
| **I11** | **move-set consistency** [C1]: the battery's independently implemented legal-move set (R8) equals the solver engine's legal-move set, state by state, via a solver-side dump utility (SMD1 binary format — see design §4.6; T172/T180 GAP-5); exhaustive at 2×2/3×2, stated sample + seed + denominator at 3×3 and above (§6a) | dropped or phantom moves — I4 computes Φ on the *stored* move relation and passes even when that relation is wrong | the ko-detector correction (QA-023) changed the reachable set itself: 2,682 → 2,622 |
| **I12** | **score range** [M6]: `L, H, TIE ∈ [−area, +area]` for all legal slots | sign-extension and overflow defects that no other invariant bounds | none of I1–I9 would catch +127 on a 2×2 goban |

**I5 is the one that reads no stored values.** It derives from the move graph
alone, which makes it the only invariant independent of the artifact under
test. It is **separately invocable** and the fleet runs it **once per goban,
not once per artifact** [S1]. Per the feasibility memo §3.3, I5 distinguishes
the **reachable-from-empty** graph (calibrates against committed 3×2 figures)
from the **all-legal** graph (tests every stored `KO_SENSITIVE` flag); the
all-legal run is the production check, and I5's soundness requires the move
generator to be the same one used for I4's Φ [O1]. Memory plan: iterative
Tarjan, rank-support bitset, on-the-fly adjacency, peak ≈ 1.2–1.5 GB at 4×4 —
3× headroom under the 4 GB cap, with tiered fallbacks (pack onstack → drop
dense map → sample-only → size threshold) if breached [B2].

**I5 calibration [SC1, SC2]** — cited targets, not folklore:

- 2×2: `docs/evidence/QA-023/ko-fix-2026-07-29/scc2x2.py` — true root V=255,
  E=434, max SCC=160; all-seed V=282, E=508, max SCC=160. (There is no "Wave 1
  SCC-2x2" task; this script is QA-023 evidence.)
- 3×2 **cycle-involved** (max SCC): **1,676** under both seed conventions
  (`docs/evidence/QA-023/ko-fix-rerun-2026-07-29.stdout:107`; 2B-2 corrected).
  The `index`/`lowlink` slip precedent (first run reported 7) makes this the
  single most important gate before 4×4.
- 3×2 **cycle-reachable** — the set I5 actually tests — has a committed
  three-way spread: **1,724** (`docs/evidence/QA-023/PROVENANCE-census-3x2-2026-07-29.md:70`),
  **1,704** (`ko-fix-rerun-2026-07-29.stdout:133`), **1,678** (true game root,
  `docs/infra/dispatch/F1-SEEDROOTS.md:10`). Documented cause: 36
  empty-goban-with-ko-point phantom seed states. **Convention for I5: the true
  game root, phantoms excluded → 1,678.** The spread's reconciliation is a
  registered task (see strategy); until it lands, an I5 disagreement at 3×2
  that matches the spread is **reference-bad**, not a sprint-breaking finding.

## 5. Acceptance criteria

| id | criterion | what a wrong answer scores |
|---|---|---|
| **A1** | Every invariant fails its known-bad fixture (R2), and the failure names the invariant. I5's fixture: corrupt a known-good 3×2 artifact at exactly one non-cycle-reachable slot (`KO_SENSITIVE` flipped ON), verify all other invariants still pass and I5 alone fails with count and denominator (`i5-feasibility.md` §6) [C2]. | an instrument that never fails is indistinguishable from one that always passes |
| **A2** | Runs to completion on all five gobans against **every in-scope artifact, enumerated here** [M2, SM5]: `artifacts/oracle-2x2.wzo`, `artifacts/oracle-3x2.wzo`, `artifacts/oracle-3x3.wzo`, `artifacts/oracle-4x3.wzo` (all four hashed in `artifacts/SHA256SUMS`), `data/oracle-4x4-basicko-tie-area.wzo` (hashed, ibid.), `data/oracle-4x4.checkpoint.wzo` and `data/oracle-4x4-parallel.checkpoint.wzo` (**unhashed, in scope** — PSK-lineage checkpoints whose ko-sensitive columns the register already distrusts). `untracked/` is out of scope. Exit codes and denominators recorded per invocation. | — |
| **A3** | **Reproduces known results, each re-verified against the register** [SB2]: (a) **3×2** pin census — *mislabeled 2×2 in pass 0* — as **two labelled targets over distinct state sets**: EXP-4 solver `L==H=2220, pin_T=298, pin_L=34, pin_H=34` over **2,586** reachable states (`docs/evidence/QA-026/exp4-solve-2026-07-29.stdout:96`, sums 2,586), and QA-023 corrected kernel `2232/322/34/34` over **2,622** states (`docs/epistemic/CLAIMS.md:557`, sums 2,622). The difference is exactly 36 states — the documented phantom count — distributed 12 → `L==H`, 24 → `pin_T`; confirming that identity is part of the registered reconciliation task, and until then the battery reports whichever its denominator matches and flags the other as reference-noted. (b) 3×3 `L==H=68,350, pin_T=1,248, pin_L=2,080, pin_H=2,080` (`docs/research/newrule-3x3-2026-07-28.md:74`). (c) 4×4 v1 UNDEF census in I6 above. No 2×2 pin census is committed; there is no 2×2 target. | a tool that cannot reproduce a committed number is not measuring the same thing — and a tool calibrated to a mislabeled number fails for reasons that have nothing to do with the instrument |
| **A4** | **Detects the v1 defects it should.** **v1 is `data/oracle-4x4-basicko-tie-area.wzo`, SHA-256 `edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc`** (`artifacts/SHA256SUMS:5`) [C3]. It must **fail I7** (DTT column uniformly 255 including terminals). Said out loud [SM5]: this is the project's current best 4×4 artifact — the T113/ADR-0020 build whose L/H core the register trusts — and A4 still requires it to fail, because its DTT column is committed as empty. An A4 pass on I7 with this artifact means the battery is not sensitive. | if the battery passes the artifact we already know is broken, it is not sensitive |
| **A5** | Independent re-implementation of **one** invariant — chosen by the acceptance auditor, not the author, **from {I4, I5, I7}: it must exercise the move relation** [S2] — agrees. Comparing two integers from the same table (I1) would pass while covering nothing, the `2B-3-AUDIT` failure shape. | the only instrument that has found a defect in this project |
| **A6** | Peak RSS reported per invocation; no invocation exceeds 4 GB. | R7 |

**A4 is the sharpest criterion.** The v1 4×4 artifact is a known-bad fixture we
did not have to construct. Any battery that passes it is wrong.

## 6. Modules — the delegable units

```
   M1 HARNESS  (blocks the rest)
    /    |    \
  M2    M3     M4      (invariant groups, concurrent)
    \    |    /
      M5 FIXTURES + FLEET RUN
```

| id | module | owns | depends on |
|---|---|---|---|
| **M1** | **Harness.** CLI, artifact loading (per R8: own loader), goban-size parameterisation, result schema — which **must carry exit-code class, denominators, and the §6a cell coordinates** [M5] — proposed-row format, exit-code discipline. **No invariants.** | `src/verify_battery.zig` (new) | — |
| **M2** | **Table invariants** I1, I2, I3, I6, I10, I12 — read the artifact only. | `src/vb_table.zig` (new) | M1 schema ratified |
| **M3** | **Fixpoint invariants** I4, I7, I8, I9, I11 — need the move relation. | `src/vb_fixpoint.zig` (new) | M1 schema ratified |
| **M4** | **Graph invariant** I5 — iterative Tarjan per `pass1/i5-feasibility.md`, reads no stored values. Calibration targets and citations in §4 [SC1]. | `src/vb_graph.zig` (new) | M1 schema ratified |
| **M5** | **Known-bad fixtures + the fleet run.** Construct the A1 fixtures; run the §6a matrix; emit proposed rows. | `docs/evidence/BATTERY/`, fixture files | M2, M3, M4 |

M2, M3 and M4 are concurrent once M1's result schema is ratified. M4 is the
long pole and its design seed already exists (the feasibility memo) [S4]. The
dispatch preference for M4 is **whoever ran the QA-023 SCC evidence**
(`2B-2`/`2B-FIX-KO` lineage — the corrected Tarjan and the `index`/`lowlink`
slip both live there) [SC1].

## 6a. The sixty cells [SM4, M1, O2]

Twelve invariants × five gobans. This is the fleet-run matrix V-13 executes
and the exhaustiveness declaration R5 points at; the pass-0 "dozen questions"
are exactly these twelve invariants. **E** = exhaustive; **S** = sampled
(size, seed, denominator reported); **G** = once per goban, not per artifact;
**n/a** = cell reports "no reference" or "not applicable" rather than a green
tick.

| invariant | 2×2 | 3×2 | 3×3 | 4×3 | 4×4 |
|---|---|---|---|---|---|
| I1 pin census | E | E | E | E | E |
| I2 colour inversion | E | E | E | E | E |
| I3 `L ≤ H` | E | E | E | E | E |
| I4 Bellman residual | E | E | E | E | E (0/99,133,036 precedent) |
| I5 SCC containment | E·G | E·G | E·G | E·G | E·G (all-legal; reachable run optional) |
| I6 UNDEF census | E | E | E | E | E |
| I7 DTT sanity | E | E | E | E | E |
| I8 truncation-gap regression | E | n/a | n/a | n/a | n/a (the 24 states are 2×2) |
| I9 anchors | E | E | E | n/a (no committed anchor) | E (+1 vs MIGOS +2, open) |
| I10 TIE median | E | E | E | E | E |
| I11 move-set consistency | E | E | S | S | S |
| I12 score range | E | E | E | E | E |

A cell is **settled** when its invariant ran in its declared mode against
every in-scope artifact for that goban (I5: once per goban) and the result is
absorbed through V-14. Sixty green cells is a claim about this table, nothing
else.

## 7. What would falsify success

- **A4 fails** — the battery passes the v1 4×4 artifact. The instrument is not
  sensitive and nothing it reports can be believed.
- **A5 disagrees** — the independent re-implementation of an invariant differs.
  Then §1's premise (one reviewed instrument beats sixty) is not yet earned.
- **A3 disagrees with the register after a clean run** — **reference-bad**
  [SS2]: the register entry is audited before the battery is. The 3×2 census
  spread is the standing example; the battery being right and the committed
  number wrong is a live case, not a hypothetical.
- **I5 contradicts stored `KO_SENSITIVE` at 3×2 beyond the known 1,724/1,704/
  1,678 spread** [SC2] — then either the fixpoint kernel or the cycle census
  is wrong, and that is a finding larger than this sprint. A disagreement
  *within* the known spread is reference-bad and feeds the reconciliation
  task, not an escalation.
- **The invariant set is found to be missing something the fleet then trips
  over.** Sixty green cells followed by a defect found another way means the
  battery measured the wrong things — a completeness failure, not a bug.

## 8. For the pass-1 auditor

Grade **blocker / critical / must / should / could**; return **PASS /
NEEDS-FIX / REDO**. Write to `docs/epics/E1-markovian/sprints/verify-battery/archive/spec-audit.md`.

Questions worth asking:

1. R8 is the maximal shared-code policy (import nothing). Is the cost honest,
   and is the weaker alternative (import `src/`, lean on A5) actually weaker
   in a way that matters at this project's defect history?
2. Does the §6a matrix really exhaust the epistemic-tree questions for
   epic-01, or are there cells (per-artifact provenance? cross-goban scaling
   laws?) that no invariant covers?
3. Is the three-exit-class scheme (artifact-bad / reference-bad / battery-bad)
   complete, and is reference-bad's handling (register entry goes to audit)
   the right escalation?
4. A3 now carries two 3×2 census targets over two denominators with a
   36-phantom reconciliation hypothesis. Is that carried honestly, or should
   the battery block on the reconciliation task landing first?
5. I8's polarity is now agreement (gap = 0). Is the fixture still worth its
   cell if ADR-0020's amendment stalls — i.e., does the invariant depend on
   the ADR text, or only on T102/T103's evidence?
