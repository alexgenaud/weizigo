# T467 — has `L2 (proven 4×4 values)` been discharged? VERDICT

```
Task:     T467 · Set: A · Date: 2026-08-19 · Auditor: claude-fable-5/T467 (Fable seat)
Mandate:  untracked/T467-l2-discharge-audit.md — bounded to the three questions below
Landmark: rules on L2 (proven 4×4 values) itself
Bars:     read-only on source/instruments/artifacts; re-derivation by independent route or UNKNOWN;
          every reading as <violations> / <full denominator> with file:line and command
```

## Ruling: L2 is NOT DISCHARGED — and the map was wrong about *why*

**The short form.** The sprint that `LANDMARKS.md` points at (G3b value-correctness) **was
discharged on 2026-08-05** — signed ruling, two amendments, all verdicts standing
(`docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/accept.md:188,258,288`). The four
gaps the landmark's status line calls "in flight" (closure, cycle containment, the 4×3 rung, two
mutation assertions) closed the same day (accept.md:137–184). `LANDMARKS.md` has described a
state fourteen days dead ever since. But **L2 itself was never ruled, and is not dischargeable
today**, because by the landmark's own text — *"every value verified to be the answer … with the
full table as the denominator, never a sample"* (`docs/audits/2026-08-05-handover/LANDMARKS.md:141-142`)
— four things still stand, three of them named by the discharge ruling itself (accept.md:252–256):

1. **I11 (move-set consistency) is a 0.05% sample at 4×4** — 0 / 50,000 of 99,133,036
   (accept.md:218, scope limit 1 at :228–230). The landmark says "never a sample". Exhaustive at
   every lower rung (0/114, 0/978, 0/25,350, 0/643,378 — `src/vb_i11.zig:275`).
2. **The KO_SENSITIVE column remains distrusted pending Track A** (scope limit 3, accept.md:234–235)
   — 3,455,412 entries (3.49%) whose checks pass *around* the column, not *on* it. T380's F-8 is
   material evidence that Track A may be dischargeable **by ruling** rather than by regeneration:
   the current WZO2 table was built by the ADR-0020 pure fixpoint, not the historically unsound
   finisher (`docs/evidence/KO-REVIEW/retrograde-ko-2026-08-05.md`, finding F-8; commit 6b13c1d).
   Nobody has ruled.
3. **The #2 auditor gate has not run** (accept.md:249–250: "Not discharged by this ruling: the #2
   auditor gate, Track A, …").
4. **The discharge's corrected numbers were never absorbed.** Amendment 1 ordered "quote the
   corrected figures" (accept.md:275) and T383 re-issued them — but every status surface still
   quotes the wrong-decode denominators (§2 below). The T467 brief itself quoted the stale table.

**And none of the four is a registered row.** The kanban has no task for I11-exhaustive, no task
for the Track A ruling, no task for the #2 auditor, no task for the denominator absorption — not
in do-now, not in background, not even in `untracked/ideas.md` (`docs/status/backlog-2026-08-19.md`,
verified against `bin/managent status`, 2026-08-19). The critical path is not merely paused; it is
absent from the map. That absence, plus the stale `LANDMARKS.md`, is the real L1 failure this
audit was chartered to find.

**Dispatchable tomorrow — the exact remainder:**

- **T-a (ruling, ~zero cost):** operator/Orchestrator rules on Track A in light of T380 F-8 —
  either "discharged by provenance" (pure-fixpoint build) with the ruling recorded in accept.md,
  or a regeneration row (`memo_writes=false` + comparison) is registered.
- **T-b (instrument run, scale-expensive):** exhaustive I11 at 4×4 — extend
  `src/vb_i11.zig:174` `compareSmd1` from 50k stratified to all 99,133,036 entries (the SMD1 dump
  machinery exists; the only missing denominator, per `docs/epistemic/SOLUTION-TREE.md:232`).
- **T-c (audit row):** the #2 auditor pass over the G3b evidence chain.
- **T-d (doc absorption, one commit):** propagate T383's corrected closure denominators into
  accept.md Amendment 1, `docs/epistemic/CLAIMS.md` (4x4.C1 row), and
  `docs/infra/instrument-coverage.md:75`; reconcile
  `sprints/verify-battery/pass1/mutants.md:48-57` with the T363 kill assertions (§3, finding F3).

---

## 1. Every property, as `<violations> / <full denominator>` — corrected where the record is stale

Artifact under audit: `data/oracle-4x4-v2.wzo2`, SHA-256 `0c3366f0…e15a` — verified today
(`shasum -a 256 data/oracle-4x4-v2.wzo2`, 2026-08-19) identical to the baseline record
(`docs/evidence/BATTERY/baselines.json:1084`), the T310 deterministic-rebuild reference
(`docs/research/parallel-fixpoint-measurement-2026-08-03.md:87-94`, 8/8 builds byte-identical)
and T341's sidecar. File mtime 2026-08-04 00:39, size 518,123,097. **The table has not drifted
since any reading below was taken.**

| property | reading (violations / full denominator) | instrument · run | independent second route? |
|---|---|---|---|
| I4 Bellman residual | **0 / 95,677,624** KO_SENSITIVE-clear + **0 / 3,455,412** KO_SENSITIVE-set (measurement — column distrusted) | `src/vb_bellman_4x4.zig:1014` (R8 engine), T343 | **YES** — `oracle_v2_accept.checkA2` exhaustive, kernel engine, **0 / 99,133,036**, same artifact SHA (`baselines.json:1183`, T309). Two Φ implementations, different move engines, both zero. Caveat: bucket shapes differ (clear/set/cycle-boundary vs L/H/missing-child), so this is verdict-plus-zero-counts agreement, not count-for-count comparison |
| C-A1 forward closure | **0 / 616,030,190** non-terminal children over all 99,133,036 entries — **the widely quoted 0 / 600,763,414 is the wrong-decode figure** (F-7: `kb>>1` for `kb>>2`) | `src/vb_closure.zig:438` post-T383 fix; run: `WEIZIGO_CLOSURE_4X4_FULL=1 tools/runner -- zig test --dep engine -Mroot=src/vb_closure.zig -Mengine=src/smd1_engine.zig --test-filter '4x4 full closure'` (`findings/T383-context.json:20`) | **YES** — T383's disposable independent probe agrees (0 missing, reachable 99,133,034); structural reconciliation: 616,030,190 = 565,402,416 I5 placement edges + 50,627,774 pass edges, exact (`docs/research/force-life-classifier-2026-08-06.md:91`) |
| C-A2 backward closure | **0 / 99,133,034** reachable non-terminals (2 non-root-reachable: the two White-on-empty shapes) — **the quoted 0 / 99,020,312 is wrong-decode; T380's 98,999,934 is a different measure** (settled-skip convention) | same run as C-A1 | **YES** — "two genuinely independent correct decoders of the kernel closure AGREE on 99,133,034" (`findings/T383-ko-decode.json:55`); `t380_ko_slot` reach mode independently confirms 0 missing under its own convention (commit 6b13c1d) |
| Key agreement | **0 / 99,133,036** at 4×4 (T345) · **0 / 643,378** at 4×3 retroactive rung (T363) | `src/differential.zig:1244` | **PARTIAL** — dual-implementation by construction (kernel producer vs R8 consumer), plus T380 Q2 kernel==production successor sets 0/266,779 sampled at 4×4. But kernel and R8 are the same pair I11 compares: a *shared* move-semantics defect would pass all three. No from-the-rules third route exists at 4×4 |
| I5 cycle containment | **0 / 3,455,412** KO_SENSITIVE at 4×4 — the coverage table's `ko_not_cr = 0` line **lacks this denominator** (`docs/infra/instrument-coverage.md:72`); 0 / 170,181 at 4×3 | `src/vb_scc_4x4.zig` `checkI5Wzo2` (:810), T363; re-run unchanged post-T391 (`adjudication-2026-08-06.md:178-181`) | **NO at 4×4 — UNKNOWN by the strict bar.** The T391 third route (from-the-rules Python) verified this instrument to the digit at 3×2 and 4×3 and found+fixed a defect in its 4×3 all-legal path (the fabricated "24 natural violations" — true reading 0), but explicitly did **not** re-derive the 4×4 reading ("— (scale)", `adjudication-2026-08-06.md:126`). What licenses the 4×4 number: an adjudicated-correct instrument, an order-independent sweep at that rung, and a red-then-green seeded control at 4×4 (0→1→0). That is instrument trust, not independent re-derivation |
| I11 move-set consistency | **0 / 50,000 sampled** of 99,133,036 (0.05%) at 4×4; exhaustive 0/114 · 0/978 · 0/25,350 · 0/643,378 below | `src/vb_i11.zig:174,275`, T346 | R8 vs kernel is itself the two-implementation check; the missing item is the **denominator**, not the independence |
| Mutation adequacy | 7 / 7 asserted killed (T363: M8 red-then-green via C-A1 0→2 / C-A2 0→1; M10 via I11 null 0/114 + seeded 1/114) | `src/vb_mutants.zig:269,319` | **RECORD SELF-CONTRADICTORY** — the catalogue still lists M1–M4, M8, M10 as SURVIVED (`sprints/verify-battery/pass1/mutants.md:48-57`); D8 flagged this on 2026-08-06 (`instrument-coverage.md:183-193`) and it is still unreconciled. The discharge line cannot be read off the record without trusting one source over the other |

**Resolution of the brief's dichotomy (question 1):** *both halves are true.* The landmark is
past its named gaps and nobody ruled on it — G3b's discharge was ruled but L2's never was — **and**
the readings do not mean what the table says: `instrument-coverage.md` line 75's closure figures
(0/600,763,414 · 0/99,020,312) are wrong-decode denominators superseded by T383 on 2026-08-05,
and its line 72 cycle-containment cell carries no denominator at all.

## 2. Question 2 — does the evidence survive re-derivation by a different route?

Summary of the table above, against the twice-earned lesson ("compare the counts, not the
verdicts"):

- **Closure: YES, and it is the best-verified property on the table.** Two independent correct
  decoders agree on the C-A2 count to the entry; the C-A1 denominator reconciles exactly against
  the independently computed I5 edge census. The *published* numbers are stale, the *evidence* is
  strong.
- **Bellman: YES at verdict level** — two engines (R8, kernel), same artifact, both zero. The two
  routes bucket differently, so count-for-count comparison is not possible as recorded; a
  same-bucketing differential (instrument-coverage §3, I4 row) remains the open hardening.
- **Key agreement: PARTIAL** — genuinely two implementations, but the same pair everywhere;
  no third route at 4×4.
- **Cycle containment: UNKNOWN by the strict bar at 4×4** — the one property whose full-scale
  reading rests on a single (adjudicated, seeded-control-verified) instrument. I do not inherit
  its verdict; I record it as instrument-trusted, not re-derived. A third-route 4×4 run is the
  closing move if the operator wants it (the T391 Python route exists; scale was the only reason
  it stopped at 4×3).
- **Mutation adequacy: cannot be re-derived from the record** while mutants.md contradicts the
  findings notes (F3).

## 3. Findings register (all outside-mandate items registered, not repaired)

- **F1 — stale denominators quoted as current.** `docs/infra/instrument-coverage.md:75` (C-A1
  0/600,763,414 · C-A2 0/99,020,312), `docs/epistemic/CLAIMS.md` 4x4.C1 row (:328, same figures),
  accept.md Amendment 1 table (:266, corrects C-A2 to the settled-skip 98,999,934 and leaves
  C-A1's wrong-decode figure standing). Correct figures live only in `findings/T383-ko-decode.json:48`.
  Amendment 1's own rule — "a pass with the wrong denominator must be corrected in the same place
  it was signed" — has been violated by its own amendment chain for 14 days. → remainder T-d.
- **F2 — a discharge condition with no denominator on the status surface.**
  `instrument-coverage.md:72` records I5 as "ko_not_cr = 0" bare; the full form is 0 / 3,455,412.
  → T-d.
- **F3 — mutation kill matrix self-contradictory** (mutants.md SURVIVED ×6 vs T363/accept.md
  7-of-7). Known since D8 (2026-08-06), unreconciled. → T-d.
- **F4 — the L2 remainder is unregistered** (no rows for T-a/T-b/T-c). → register.
- **F5 — LANDMARKS.md fourteen days stale on L2, L4, L1, L0.** Corrected by this audit (in-scope
  per the brief): dated status paragraphs added, summary table and story updated —
  `docs/audits/2026-08-05-handover/LANDMARKS.md`, this commit.
- **F6 — evidence durability (registered elsewhere, weighed here):** the artifact every reading
  depends on is gitignored, single-disk, with no off-disk archive (T443 findings, commit e00d279);
  regeneration is deterministic but costs ~83 min. The evidence base of L2 currently has no
  durability policy — T443's policy draft awaits the operator.

## 4. Question 3 — the sequencing judgement

**Measured today (not inherited from the brief):** the do-now five
(`docs/status/backlog-2026-08-19.md:9-17`) are T378, T455, T448, T454, T442. By landmark: T455,
T448, T454, T442 are `L1 (the dashboard tells the truth)` / process safety; T442 also serves
`L4 (the ledger is clean)`. T378 — the QA-023 probe's inverted White guards, fixed today at
fc9f35d — is *not* pure L1: the probe is an independent small-rung Bellman route whose C1
readings were suspect until fixed, so it repairs the **L2 evidence chain**, though it advances no
L2 remainder item. Three of the five closed today (T378 fc9f35d, T455 12e4e55, T442 c9602a2);
T448 is in progress, T454 dispatchable. The queue snapshot in the brief was accurate when taken
and is already half-consumed.

**Judgement: the sequencing is defensible; the invisibility is not.** The case for
instruments-first is genuinely strong here — it is the L1-class work that kept the discharge
honest: T380 (an audit row) found F-7; T388 (a coverage-mapping row) found the I5 disagreement;
T391 found the fabricated "24". Every amendment to the discharge came out of exactly the kind of
work the queue is full of. The operator's stated position — finish L1 and L4 and put them behind
us before turning to L2 — is consistent with that record, and the do-now list is small and
nearly done.

What is *not* defensible is that for fourteen days the critical path had no live row, no
registered remainder, and a landmark doc claiming T363 was still in flight. Sequencing means "L2
next, after this"; what the map showed was "L2 in progress" (false) with nothing queued behind it
(invisible). Had the operator asked the dashboard "what is left for L2?", it had no row to answer
with.

**Recommendation.** Finish the do-now list (nearly done already). Then, before any new L1 polish
is registered: (1) register T-a through T-d — T-a (Track A ruling) and T-d (denominator
absorption) are each under an hour and unblock the honest sentence; (2) put T-b
(I11-exhaustive) and T-c (#2 auditor) on the queue with the operator's priority, since they are
the only expensive items between here and an L2 discharge ruling; (3) optionally, a third-route
I5 run at 4×4 if the strict re-derivation bar of §2 is wanted closed. No stop or change of
course is recommended: the evidence under L2 is in better shape than its paperwork, and the
remainder is short, enumerable, and mostly cheap.

## 5. Corrected LANDMARKS.md

Applied in this commit to `docs/audits/2026-08-05-handover/LANDMARKS.md` — dated status
paragraphs (2026-08-19, this audit) for L0, L1, L2 and L4; summary table and one-paragraph story
updated; L3, L5, L6, L7 verified unchanged against today's evidence (L3: nothing since 2026-08-05
contradicts the committed kifu record; L5 correctly waits on L2 and on the mutation-adequacy
promotion gate).

---

*Fable-seat note: this audit consumed well under the 90%-of-200k handover bar.*
