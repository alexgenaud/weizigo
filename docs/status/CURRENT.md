# CURRENT — in-flight task status (ephemeral; updated often)

**Purpose:** the single file a fresh session reads to resume *without loss*
after a context clear / compact / handover. Not durable — milestones live in git +
`../epistemic/PROGRESS.md` + `../decisions/` + `../research/`. If this file is stale, read
`../epistemic/PROGRESS.md` → `leak-crisis.md` and rebuild it.

Last refreshed **2026-08-02 (Orchestrator/Opus 5 — Grand Audit reconciliation)**.

## T278 (2026-08-02, deepseek-v4-flash) — shared-index fleet hazard: mechanized

**Ownership declared:** mutation of `src/managent/main.zig` (the `done`
deliverable check now asks git, not the filesystem), `tools/git-commit-mine`
(new), `tools/regression-git-commit-mine.sh` (new), `tools/regression-managent-done-git.sh` (new),
`bin/subagent` (sets `MANAGENT_TASK_ID` for dispatched workers). Owned paths
cleared when the T278 commit lands. Recommendation + edge-case rulings:
`docs/infra/fleet-git-isolation.md`. Controls: `tools/regression-git-commit-mine.sh`
(incident-1 fixture, null + seeded) and `tools/regression-managent-done-git.sh`
(null, seeded, retention, deletion) — both PASS on the rebuilt
`bin/managent` (05dae9b). The wrapper is recommended, pending Orchestrator
adoption. **T280 installed the T272 pre-commit hook during this session**
(`core.hooksPath tools/hooks` is now set — the T278 commit itself passed
through it at floor); the staged-path-subset backstop remains a follow-up.
Do not `git add -A` — commit via
`tools/git-commit-mine <paths> -m <msg>` with `MANAGENT_TASK_ID` set.

# STATE AS OF 2026-08-02 — the Grand Audit landed; DIRECTION.md governs

**Read `docs/audits/grand-audit-2026-08-02/DIRECTION.md` first** (ratified by the
human 2026-08-02, committed `2432d71`), then `docs/epic-01-markovian/PHASES.md`
for where each task sits. `GRAND-AUDIT.md` beside it is what the direction fixes;
the four `arm-*.md` files are reference depth. Nothing in flight; clean tree.

- **The 4×4 artifact is `0c3366f0…`, playable and NOT verified** — this
  supersedes the "INVALID / `a892d689`" headline in the 2026-08-01 block below,
  which describes the pre-rebuild artifact. `untracked/oracle-v2/oracle-4x4-v2.wzo2`
  passes M4a 4/4 **and is not a solved 4×4**: `CODE.WZO2-INCOMPLETE` —
  ~6.77M of ~48.6M side-entries missing, and oracle self-play ends `W+2` against a
  builder-logged root of `L=+1 H=+16`. **Blocks oracle-v2 G3** (T266). None of
  M4a's four checks tests completeness; T212's "artifact is valid" proposal is
  recorded and refuted as `WZO2-4X4-VALID`.
- **All 282 register rows are presumed unverified**, falsifications included,
  until re-derived inside the reconstructed chain (DIRECTION §1). No re-audit
  until Phase 0/1 deliverables exist.
- **Epic-01 is completed in place, strictly k=1.** No migration of
  claims/decisions/docs — which retired **T203** (`abandoned`, reopenable).
- **Phase 0 gates decomposition**: `T271` (AXIOMS.md — theorem, ruleset axioms
  with claim IDs, requirement tree from Z, MIGOS tie adjudication) must land
  before any Phase 1–4 task is registered.
- **Dispatchable**: T271 (Phase 0) · T266, T267, T270 (Phase 1) · T272, T268
  (infra). **Blocked**: T269 (needs T272), T273 (needs T271, T267).
- **Gates are red and audited, not broken-by-surprise**: `bin/weizigo-claimlint`
  exits 1 — C1a=10, C2=14 (the recorded Argus floor still says 12), C6=0, C7=4,
  calibration PASS, 282/0 parsed. `T272` is the task that turns the floor into an
  enforced pre-commit gate; do not chase these to zero ad hoc.
- **The G3 blocker is under challenge, not cleared.** T266 (`dff5bba`) measures the
  4×4 `passes=1` shortfall at **131,068 genuinely-unreachable** side-entries, not
  ~6.77M (T261's figure came from the first 5,000 groups in colex file order). If it
  holds, `CODE.WZO2-INCOMPLETE` is PROVEN-and-wrong-as-stated and oracle-v2 G3 is not
  blocked. **T277 must try to break it first**; T279 absorbs whatever T277 rules.
  Do not quote either number as settled.
- **The MIGOS +2 anchor was the wrong anchor.** T274 (`5f87b5b`): MIGOS's basic-ko 4×4
  is **+1** (thesis Table 5.1) and its long-cycle-tie value is **0** — both ours. The
  +2 is a different cycle-resolution rule. `GLOBAL.TIE-MIGOS` is contradicted on its
  stated mechanism; absorption is T279.
- **I2 is clean on WZO2** (T270: 0/99,133,036 at 4×4, 0/49,428 at 3×3, independently
  re-implemented) **and blind to the completeness question** — the missingness is
  colour-symmetric.
- **The claimlint gate is still not installed.** T272 closed `pass` with its
  deliverable outside git; landed at `f9469d1` as preserved-not-accepted, with its
  seeded-defect control exercising claimlint instead of the hook. **T280** installs it
  after fixing the controls. `core.hooksPath` is unset — there is no gate today.
- **T267 verified pass, with one residue.** `src/differential.zig` is in the test
  graph (`build.zig:165-176`), the tautological T265 test is gone —
  `engineKoNewGeneric` (`differential.zig:276`) is an independent re-implementation
  over the engine's `rules.Rules(w,h).neighbors`, not an alias — and the pre-fix
  reproduction is real (`engineKoOldGeneric` finds disagreements at 2×2 and 3×2, so
  the test can fail on a known bug). **Residue:** it still cannot exercise
  `gtp.zig:717-744` itself (gtp is an exe root, so `build.zig:173` clears the import
  table), so a regression in the shipped GTP rule would leave the test green. Closing
  it is now part of T273's definition of done. `zig build test` exit 0 at HEAD, and it
  runs T272's hook controls in-suite (`build.zig:160-163`).
- **Deploy correctness is closed** (T268): remove-copy-sign, smoke 7/7
  deployed==built, `./managent` and `./gtp` root hazards retired. Phase 1 gate
  readings are now quotable.
- **Phase 0 delivered, verified with findings.** `DSPro/T271` wrote
  `docs/epic-01-markovian/AXIOMS.md` (`52f16a4`, closed `pass`); Orcha
  verification found three defects — A5 contradicts B2/B3 on pass-clears-ko,
  B1's repetition clause is off by one ply, and "not a bug" rests on the CLAIMED
  `GLOBAL.TIE-MIGOS` while the defect hypothesis is not eliminated (`f8c9df0`).
  **T275** carries the amendment and **holds `docs/epistemic/CLAIMS.md`** when
  claimed; **T274** is the tie-constant falsification test and needs T275.
  Nothing in flight.
- Channel state, seats and operating rules:
  `untracked/msg/milestone-01-ko-reframe/STATE.md`.

---

> # STATE AS OF 2026-08-01 (T205 refresh) — **superseded by the block above**
> (kept as history; its artifact headline `a892d689`/INVALID is the pre-rebuild
> artifact, and T203 has since been retired by DIRECTION §2)
>
> The coherence audit (`docs/audits/coherence-audit-2026-08-01.md`, `653f157`)
> found every read-first surface stale (CA-2) and the stand-down handover
> missing (CA-3). Remediation **Phases 1+2 complete** (T204–T208, exit checks
> verified at `c820f23`); **Phase 3 open — Opus seated as Orcha 2026-08-01**
> under the D-C ruling.
>
> - **The 4×4 WZO2 artifact is INVALID.** T193 ran M4a acceptance against
>   `untracked/oracle-v2/oracle-4x4-v2.wzo2` (518.1 MB, SHA-256
>   `a892d689…`, built by T192 at `f851102`) and it **FAILED**: A3 colour
>   inversion 16,314,978 violations / 99,133,036 (16.5%), A9 reproducibility
>   24,252,631 entry-order violations; A5 and A6 PASS. Root cause is a
>   builder bug — `src/oracle_v2_build.zig:387` encoded passes=1 entries with
>   `passes=0` in the key_byte, colliding both classes at one sort key. Fixed
>   (one character) at `5deec6b`. **The artifact must be rebuilt and M4a
>   re-run before any oracle-v2 G3** — registered as T212. The 3×3 artifact
>   passes all four checks, confining the bug to the 4×4 path. Evidence:
>   `docs/evidence/ORACLE-V2/m4a-accept-T193-2026-08-01.md`.
> - **`docs/evidence/ORACLE-V2/` EXISTS** (7 files): consumer-load-T178,
>   build-T184 (report + `.stdout`), m2a-reverify-T183, accept-wire-T182,
>   m4a-accept-T193 (report + `.stdout`).
> - **Open on the kanban**: T212 (rebuild + re-run M4a — gates oracle-v2 G3),
>   T210 (managent hygiene) and T211 (Argus baselines) in progress, T203
>   (pass1 relocation — dispatchable, imposes a task freeze so it runs
>   alone), G3 ×2 (oracle-v2 accept, verify-battery accept), verify-battery
>   V-13 fleet run / V-14 absorption.
> - **D-E open** — closure of dogfoods #1/#2 awaits the human's word; both
>   the audit §6 and msg 074 §6 recommend closing them.

---

> # STATE AS OF 2026-08-01 — Fable/T177 — **superseded by the top block**
> (kept as history; the P2→P3 follow-ups it lists were executed T180–T192)

## P2 absorbed: both sprints are CODE-COMPLETE, RUN-PENDING

G2 cleared; the post-G2 build lanes (T165–T172) ran 2026-07-31 and delivered
~5,000 lines of committed code — **unexecuted at that point**; the build
lanes ran 2026-08-01 via T178–T192 (see top block). Absorbed into the
register 2026-08-01 (Fable/T177, 6 new rows; see `PROGRESS.md` §7.4a):

- **oracle-v2**: at the time, no `.wzo2` artifact existed and
  `docs/evidence/ORACLE-V2/` was not yet created — **both are now in place**
  (artifact `untracked/oracle-v2/oracle-4x4-v2.wzo2`, SHA-256 `a892d689…`,
  recorded `f851102`; evidence dir has 5 files); the G-bracket, F2
  byte-budget and DTT-clamp predictions are all still untested
  `[CODE.WZO2-UNRUN:PROVEN]`. Inspection defects: the WZO2 GTP path
  short-circuits chainability to `true` (refusal rate = 0 by fiat,
  spec A1 unfalsifiable) `[CODE.WZO2-CHAINSHORT:PROVEN]`; the M4a
  acceptance harness is orphaned from the build graph and its A6 positive
  control tests uncorrupted data `[CODE.M4A-HARNESS:PROVEN]`.
- **verify-battery**: harness not wired to any invariant module (all 12
  checks are stubs, zero real runs, 36 module-local tests unreachable from
  `zig build test`) `[CODE.VB-STUBS:PROVEN]`; I5 calibration PARTIAL — node
  counts exact, edge counts +30–34% off, 3×2 gate self-calibrated against
  an uncommitted reference `[3x2.I5-CAL:MEASUREMENT]`; five blind spec gaps,
  **GAP-5 CRITICAL: the I11 solver-dump format is specified nowhere** and
  V-8 stubbed I11 instead of resolving it `[CODE.VB-BLINDGAPS:PROVEN]`.
- P2 run logs + the T172 blind analysis rescued from git-ignored
  `untracked/` into the verify-battery sprint archive (`fb3166e`).

**Follow-up work to register (P3, in dependency order):** (1) amend
spec/design for GAP-5 (define the I11 dump format — also unblocks the
WZO1-brackets decision's dump option) and dispose GAP-1..4; (2) fix
`CODE.WZO2-CHAINSHORT` — replace the short-circuit with a real Bellman
check or an honest "unverified" flag, and count/log lookup-miss fallbacks;
(3) wire `oracle_v2_accept.zig` into the build graph, fix the A6 fixture
(c), re-verify M2a byte-identity; (4) **run the WZO2 builder under the
runner** (RSS cap 4096; the untested memory plan is the suspected blocker)
and commit `docs/evidence/ORACLE-V2/` — **DONE** (T184 built under the
runner; T192 fixed the OOM; artifact + SHA recorded `f851102`); (5) run M4a
against the artifact — **open as T193**;
(6) wire the battery harness to the invariant modules, reconcile the I5
edge-count discrepancy against a committed reference, implement RSS
high-water-mark measurement.

## Sprint docs (both M1 designs G2-ratified; state above supersedes)

**Doc convention** (`docs/infra/sprint.md` RATIFIED rev 4 `d53c2a8`;
rewritten `200b974` — substance = DECISIONS.md D-16…D-20):
canonical unsuffixed docs live in
`docs/epic-NN-<slug>/sprints/<sprint>/passN/` (this epic:
`docs/epic-01-markovian/sprints/`); audit/revision ephemera in the sprint's
sibling `archive/`; ephemera deleted or archived at gate commits. The
strategy phase doc is renamed `plan.md` (imperative). Older documents may
cite pre-reorg paths — the moves were all `git mv` (`e6c6bf9`, `45deb10`,
and the epic move of 2026-07-31).

- **oracle-v2** (ko-aware rebuild, WZO2 bracket-carrying format):
  `docs/epic-01-markovian/sprints/oracle-v2/pass0/{spec,plan,design-M1}.md`. design-M1 at
  **rev 3** after three audit rounds (T142/T146/T150); G2 = diff review, no
  fourth round. Spec A6 amended in place, amendment rides the same G2.
  **M2a is done**: `src/exp6_solve.zig` now exposes a public fixpoint
  interface (T140, 79 `pub` decorations; verified byte-identical by fresh
  seat T155 — gate chain 2×2=0, 3×2=0, 3×3=+9 reproduced, 4×4 census
  identical). M2b dispatchable the moment G2 clears.
- **verify-battery** (fleet re-verification instrument):
  `docs/epic-01-markovian/sprints/verify-battery/pass0/{spec,plan,design-M1}.md`
  (i5-feasibility lives in the sprint `archive/`; `strategy.md` was renamed
  `plan.md`).
  design-M1 at **rev 2 + rev-3 patch** (T156 schema-field closures), audit
  T151 **PASS**; the JSON-Lines result schema freezes at G2. Acceptance
  criteria AC-S1 / AC-S3 / AC-S4 are still open and tracked only in the
  archived audit — carry them into the G2 review.

## Decisions the human owes

1. **WZO1 cannot answer bracket invariants**: every committed WZO1 artifact
   stores the TIE-resolved pin (single V), not `[L,H]` — so `L ≤ H`,
   median-pin and L/H-residual checks are uncomputable from committed WZO1
   evidence. **WZO2 now exists** (`untracked/oracle-v2/oracle-4x4-v2.wzo2`,
   `f851102`), so the wait option is executable once the M4a acceptance run
   (T193) passes; the ~250–350-line solver-side L/H dump remains an option —
   GAP-5's missing format spec was resolved by the T180 spec surgery. Still
   a human decision.
2. ~~**sprint.md rev 5** (epic tree, plan.md rename) — PROPOSED, awaiting
   ratification~~ — **closed by supersession**: `200b974` rewrote sprint.md;
   the rev-5 substance survives as DECISIONS.md D-16…D-20.

Resolved since the last refresh: G2 ×2 (cleared; P2 built on it) and the
ADR-0020 amendment (ratified, committed `0c3c3ac`).

## PROPOSED specs awaiting their spec gate

- **orcha-tools** — `docs/epic-01-markovian/sprints/orcha-tools/pass0/spec.md`. **Implemented**
  (T159, absorbed `082433e`): `managent suggest`, done-deliverable check,
  audit cross-citation flag; reviewed T160. Its A3 acceptance fixture was the
  QA-027-not-absorbed defect, which is now fixed (`622275f`) — the tools
  exist to catch the next one.
- **argus** — `docs/epic-01-markovian/sprints/argus/pass0/spec.md` (read-only watchdog, 14
  requirements, cheap-tier). Spec audited T161.
- **project-restructure** — `docs/epic-01-markovian/sprints/project-restructure/pass0/spec.md`
  (3 items, "do nothing" explicitly acceptable). Spec audited T162 (PASS).
  Item 2 touches ~890 references to the epistemic tree — see spec §risks
  before any ratification.

## Absorption catch-up (per the 2026-07-31 Fable audit of all 39 DONE tasks)

The audit found everything after T129 was commit-only (deliverables committed,
findings never pushed into CLAIMS/PROGRESS/CURRENT). Recovery in flight:

- **Done (Fable, `622275f`)**: `QA-027` → **FALSE-AS-SCOPED (at 4×4)** —
  T129 measured certified fraction 10.71%, the median-pinned V is not
  Bellman-chainable at bracket-valued states; `QA-020` gained the new-rule
  re-test datum; PROGRESS.md §6/§7.4 updated and cite-tagged.
- **T163 DONE** (`7868108`, Orcha): T138 census annotations, H1-CENSUS
  caveat, QA-027/census-reconciliation citations. **T164 DONE** (`f597c3d`):
  model-perf backfilled T142–T158 incl. T152 model-allocation findings.
- **Catch-up remainder DONE (Fable, `9fde18d`)**: 3 new rows —
  `GLOBAL.PASS-NOKO` (passes ≥ 1 ⇒ ko = none, PROVEN), `4x4.G-CENSUS`
  (G bracketed 23,802,969–24,318,165, three witnesses), `4x4.I5-FEAS`
  (Tarjan fits the 4 GB cap; carries the 1,678/1,676 I5 reference
  denominators). Plus: `4x3.S3a` A094777-square-only caveat, `GLOBAL.B15`
  action/premise decoupling, T128 triage dispositions applied (T13 probe
  banner superseded — RECOVERED by T110), SHA-256 recorded for both 4×4
  checkpoints (same 258,280,358 bytes, **different** content), epic-move
  link rot fixed in census-reconciliation.md / i5-feasibility.md.
  **Standing trap:** `untracked/c2pilot_3x2.zig`'s citation is claimlint's
  known-bad C2 calibration fixture — never "fix" it.
- **Claimlint state**: 268 rows, C6 = 0, calibration PASS. C2 = 12 and
  C1a = 10 are **accepted honest debt** per the T128 triage (LOST records,
  the fixture, frozen /tmp mentions; orphans structurally correct-as-is) —
  do not chase them to zero. Citing archive ephemera or PROPOSED designs
  from register rows drags their internal paths into C2 scope — cite
  canonical pass0 docs and evidence files instead.
- **Open follow-up (unregistered)**: regenerate the B1 least-fixpoint
  outputs (T128 triage §3: RECOVERABLE, < 1 h — driver for `RETRO_B1_LOFIX`
  at 2×2/3×2/3×3, target `docs/evidence/B1/`, verification target = zero
  violations per the leak-crisis prose). Register in the kanban when it
  reopens for real tasks.

## Concurrency — live file owners

- `docs/epistemic/CLAIMS.md` — T163 hold released (`7868108`); Fable's
  catch-up landed at `9fde18d`. No live owner.
- `docs/infra/model-perf.md` — T164 hold released (`f597c3d`). No live owner.
- `docs/status/CURRENT.md` — T205 (this refresh).
- `src/managent/main.zig` — T159 hold cleared at `082433e`; T204 landed `a98bf04`.
- `docs/decisions/ADR-0020-...md` — amendment **ratified and committed
  `0c3c3ac`** (G1); no longer uncommitted.
- Kanban caution: T140/T141/T144/T145/T146 in the *current* queue are
  orcha-tools **test fixtures** with reused IDs, not the historical tasks of
  the same numbers.

---

## T129 (DSPro/T129) — EXP-7 4×4 re-run — DONE 2026-07-31

Result: certified fraction = 10.71% (3,000/28,000 fresh-start nodes) under oracle.
QA-027 is FALSE at 4×4 `[QA-027:FALSE-AS-SCOPED]` — absorbed into the register
at `622275f`. V-domain Bellman identity fails at bracket-valued states.
Deliverables: docs/evidence/QA-027/4x4/, docs/research/newrule-certified-fraction-4x4-2026-07-31.md.
Ownership of src/t129_exp7_4x4.zig cleared.

---

> # STATE AS OF 2026-07-31 — DSPro/T127 refresh
>
> **All previously-superseded blocks below the 2026-07-29 "Opus/Orcha" top block
> have been deleted.** The T100–T126 wave is now fully absorbed into
> `PROGRESS.md` and `CLAIMS.md`; the superseded dated sections (2026-07-29
> Orchestrator succession, EXP-10, EXP-8, host-panic-recovery, EXP-2A, EXP-3,
> EXP-2 dispatch records, and the 2026-07-27 evening session) described states
> that either concluded or were superseded by later findings. Historical
> context lives in `model-perf.md:2163–2470` (per-task ledger of all 60 purged
> tasks). The kanban was purged by T120; new tasks registered T121–T129.
>
> ## The keystone: ADR-0020 (loopy-game fixpoint semantics)
>
> ADR-0019 (first-revisit truncation) is superseded. Under ADR-0020, cycles
> do not terminate the game; the value is the limit of the iterative Bellman
> operator on `(board, side, ko_point, passes)`. This representation **is**
> Markovian, convergent by Knaster–Tarski, and tractable through 4×4.
>
> ## T100–T126 wave summary
>
> **32 tasks across 7 models** (2026-07-30), plus the T120 absorption audit
> that registered T121–T129. Key findings now in `PROGRESS.md`:
>
> | finding | source |
> |---|---|
> | 4×4 root V=+1 (bracket [+1,+16]), H=+16 verified genuine | EXP-6, T104 |
> | T13 reproduced; 154/508 (30.3%) history-sensitive, not 12 | T110 |
> | ADR-0006 not falsified; 3 corrections; new PRUNE-ALL hazard class | T114 |
> | 4×4 ko-sensitive region 99.997% single-ko | T117 |
> | brute-force corroboration withdrawn across EXP-4→EXP-7 | T102 |
> | all five T101A evidence-free PROVEN rows closed | T105/106/107/111/112 |
> | `.wzo` artifact written, 258 MB, SHA-256 verified | T113 |
> | ADR-0020 loopy-fixpoint semantics accepted | DSPro/Orcha |
>
> ## The EXP-4→7 gate chain — complete
>
> | goban | root | status |
> |---|---|---|
> | 2×2 | 0 (TIE) | `2x2.BASICKO-TIE` MEASUREMENT |
> | 3×2 | 0 (TIE) | `3x2.BASICKO-TIE` MEASUREMENT |
> | 3×3 | +9 (matches MIGOS II) | `3x3.BASICKO-TIE` MEASUREMENT |
> | 4×4 | +1 (NOT +2 — ruleset difference) | `4x4.BASICKO-TIE` MEASUREMENT |
>
> **⚠ Brute-force cross-check withdrawn across the entire chain.** See
> `GLOBAL.BRUTE-ALIASING` in `CLAIMS.md`. Fixpoint results are independently
> verified and stand.
>
> ## Artifact
>
> `data/oracle-4x4-basicko-tie-area.wzo` — 258,280,358 bytes, SHA-256
> `edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc`.
> Rules ID 2 (basic-ko + TIE=0). 48.5M fresh-start states, 31 sweeps.
> PROVENANCE: `docs/evidence/QA-026/4x4/ARTIFACT-PROVENANCE.md`.
>
> ## Open items (post-T126) — **superseded 2026-07-31 (late)**
>
> T128 and T129 are DONE (see above). The surviving open items, restated:
> **4×4 writes-off regen** (D3) `[4x4.D3:UNTESTED]` · **FP1 acceptance
> checks 1–2** (post-hoc from T104 output) · **PSK-divergence measurement**
> (EXP-8: harness built, new-rule tables now exist) · **4×4 S2-impl / S3b**
> untested · **ADR-0006 residual** (ko-sensitive region and 5×5 — note the
> WZO2 u32-colex format caps at 20 cells, so 5×5 needs a format change) ·
> plus the sprint/gate items in the top block.
>
> ## Read next
>
> `docs/epistemic/PROGRESS.md` (just refreshed) ·
> `docs/decisions/ADR-0020-loopy-game-fixpoint-semantics.md` ·
> `docs/audits/eye-prune-validation-2026-07-30.md` ·
> `docs/evidence/T13/probe-reimplementation-2026-07-30.md` ·
> `docs/research/ko-composition-census-2026-07-30.md` ·
> `docs/audits/audit-2x2-mismatch-2026-07-30.md` ·
> `docs/infra/model-perf.md` (T100–T126 per-task ledger)
>
> ## Concurrency — **superseded 2026-07-31 (late)**
>
> See "Concurrency — live file owners" in the top block. Check
> `bin/managent status` before touching any held file.
>
> ## Claimlint
>
> Run `bin/weizigo-claimlint` after any CLAIMS.md edit. C6 must be clean
> (every cite-tagged sentence in this file cross-referenced against the
> register). New rows must not add C1a orphans or C2 dangling paths.
>
> ## The queue is a *kanban*; the playing surface is a *goban*
>
> `bin/managent` is the **kanban** — tasks, sets, holds, needs, claims.
> The Go playing surface is the **goban** (2×2, 3×2, 4×4, etc).

---

## Historical — 2026-07-29 and earlier (superseded)

All dated sections that were below the 2026-07-29 top block have been
deleted by T127. They described states that were either completed
(T100–T126, purged by T120), superseded (ADR-0019 → ADR-0020, the
Orchestrator succession handover), or absorbed into PROGRESS.md. The
per-task ledger survives in `docs/infra/model-perf.md:2163–2470`.
The handover file `docs/status/handover-minimax-m3-2026-07-29.md`
remains on disk for procedural context.

### Completed 2026-07-28

- EXP-2A (Fable 5) — Part A proof, REPAIRABLE-GAPS→repaired
- EXP-3 (Minimax-m3) — kostate census, GO on dense addressing at 4×4

### Completed 2026-07-29 (host-panic-recovery)

- EXP-9 (Opus 5) — H5a Session.choose mitigation
- EXP-12 (Kimi-k3) — denominator sweep
- B-2 RSS runner (`tools/runner`)
- managent schema + dispatch command
- Host incident record

### Completed 2026-07-30 (T100–T126 wave)

All 32 tasks. Per-task details in `docs/infra/model-perf.md` and `PROGRESS.md`.
Key deliverables: T13 reproducible (T110), ADR-0006 validated (T114),
ko-composition census (T117), EXP-4→7 gate chain complete, .wzo artifact
written (T113), T101A punchlist closed, brute-force aliasing withdrawn
(T102), ADR-0020 accepted.
