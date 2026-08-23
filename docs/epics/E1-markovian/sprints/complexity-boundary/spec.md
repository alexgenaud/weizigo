# complexity-boundary — sprint SPEC

```
Task: T777 · Role: sprint-spec console (leaf) · Model: deepseek-v4-pro · Date: 2026-08-23
Revision: 1 · Status: PROPOSED (pre-audit; ratification follows per docs/infra/sprint.md §Bookends)
Sprint owner: Orchestrator
Sprint: complexity-boundary · Pass: 0
```

**This is the spec bookend for the complexity-boundary sprint** — prose only, no
code. It states the goal, the epistemic-tree walk, the complexity push and the
boundary it finds, the smaller-goban floor, the decomposition into worker rows
(including where T531 and T535 slot), the control discipline, and the explicit
position on engine-unification pass1. The plan (`plan.md`) is a later row,
written after this spec is audited and ratified.

**Inputs read (all committed paths).**
`docs/status/landmark-waypoints-seed-2026-08-23.md` (the operator's L2/L3 intent) ·
`docs/epics/E1-markovian/AXIOMS.md` (the requirement tree + ruleset R) ·
`docs/epistemic/CLAIMS.md` (the register, edges, inheritance audit) ·
`docs/epics/E1-markovian/register-tree-map.md` (row→tree-node mapping, new-work gaps) ·
`docs/audits/2026-08-02-grand-audit/DIRECTION.md` + Amendments 1–2 ·
`docs/epics/E1-markovian/WAYPOINTS.md` (waypoint map + carry-forward) ·
`docs/epics/E1-markovian/LANDMARKS.md` (L2/L7 definitions) ·
`sprints/g3b-value-correctness/pass0/spec.md` (format precedent + ladder discipline) ·
`sprints/engine-unification/pass0/spec.md` (pass1 scope) ·
`docs/epics/E1-markovian/sprints/README.md` (layout).

---

## 1. The goal — the sentence it changes

**From** (LANDMARKS.md L2 status + seed §2, honest summary):

> The 4×4 table exists and is structurally complete; its values are verified for
> Bellman residual and key agreement at full scale, and not yet for closure and
> cycle containment — and the project has **no measured complexity boundary**: the
> 5×4 / 5×5 costs are projections, not measurements, and no threshold has a name.

**To:**

> Every claim in the epistemic tree has been challenged with an alternative
> hypothesis and driven to one of **proven / falsified / verified /
> unknown-untested-untestable-difficult**; the last class is enumerated, each
> entry carrying *why* it is hard; and the **complexity boundary** — the measured
> point at which the retrograde pipeline breaks, with its failure mode named — is
> a measured number with a name, not a projection.

This means, testably:

- **The walk (§2)** produces, for every requirement-tree node and every register
  row mapped to it, an alternative hypothesis and a falsification test, and
  drives each to one terminal class with a denominator and an evidence path.
- **The push (§3)** measures nodes, memory, and wall-clock at each goban size up
  to and past 4×4 until a stated resource limit is exceeded, and reports the
  boundary as `{size, resource, limit, failure mode}`.
- **The floor (§4)** confirms or repairs the 2×2 / 3×2 / 3×3 proven/verified
  status before any 4×4-or-larger reading is promoted, under the
  mutation-adequacy promotion rule (DIRECTION Amendment 2 — mutation binds
  *promotion*, not dispatch).
- **The decomposition (§5)** names the worker rows, their file holds, their
  `needs` edges, and where T531 (verify-battery two-surfaces) and T535
  (stage-4 clean-story) slot — coordinating, never duplicating.
- **The controls (§6)** require every instrument to be shown red-then-green
  before its first reading counts.
- **Engine-unification pass1 (§7)** is named explicitly as Waypoint-2 work this
  sprint mints, or the reason it is not.

### 1.1 What this sprint does NOT claim

- **Not a real-game oracle.** The walk and push are about the fresh-start k=1
  table under ruleset R; C2 (history-independence) is FALSE-AS-SCOPED at 3×2
  and this sprint does not re-litigate it (`3x2.T13`).
- **Not a PSK solve.** Positional superko exact-solve is foreclosed
  (`2x2.R1`, `GLOBAL.R2`); the push measures the *basic-ko + TIE=0* pipeline.
- **Not a cross-size claim.** Per-goban epistemic independence binds every
  measurement (`GLOBAL.ADR0016-INHERIT`).
- **Not the clean-story.** Ledger cleanup and history squash are T535's; this
  sprint produces the epistemic content T535's clean story narrates.
- **Not a new reporting surface.** Instrument readings route through T531's
  suite-truth manifest, never a parallel surface (§5.2).

---

## 2. The walk — every claim challenged with an alternative hypothesis

### 2.1 What is walked

The walk is a **three-axis sweep** over the things already committed:

1. **Tree axis** — every node of the requirement tree (`AXIOMS.md` §3): `Z`,
   `Z-R` (`Z-R-MOVE`, `Z-R-SCORE`, `Z-R-TIE`, `Z-R-STATE`, `Z-R-SIGN`),
   `Z-STATE` (`Z-STATE-LEGAL`, `Z-STATE-REACH`, `Z-STATE-KEY`),
   `Z-CONVERGE` (`-MONO`, `-FINITE`, `-SEED`, `-FIX`),
   `Z-TABLE` (`-ROUNDTRIP`, `-FAITHFUL`, `-CONSISTENCY`),
   `Z-COMPLETE` (`-ENUM`, `-PASSES`), and the cross-cutting `Z-SYM`, `Z-AUDIT`,
   `Z-NONCLAIMS`. Each node carries its `[F]` falsification criterion from
   `AXIOMS.md` §3; a node with no row is the new-work gap named in
   `register-tree-map.md` §5 and is walked as such (the gap IS the claim).
2. **Row axis** — every register row mapped to that node, per
   `register-tree-map.md` §1 (row set and per-row node are mechanically
   cross-checked by claimlint C9, so the walk's input is lintable, not prose).
3. **Goban axis** — per-goban independence: each empirical row is challenged at
   its own size, smallest first (§4 the floor), never inherited across sizes
   without a written argument (`GLOBAL.ADR0016-INHERIT`).

### 2.2 The challenge method — per claim

For every claim, the walk records, in a committed walk map (the WALK-INV row's
deliverable, §5):

1. **The claim** — register ID + one-line restatement.
2. **The alternative hypothesis** — the competing mechanism or the negation,
   stated as a claim a falsification test can separate. "The claim is false"
   is not a hypothesis; "the value is bracket-shaped because of static ko
   shape, not in-play cycle structure" is (`4x4.BRACKET-NOT-KO` is the shape
   of a challenge already run and won).
3. **The falsification test** — the `[F]` criterion, as a runnable pass
   condition stated **violation-vs-measurement** (T287: a wrong pass condition
   is itself a defect). A claim whose test cannot be stated is UNTESTED by
   definition, and *saying so is the finding*.
4. **The verdict** — one terminal class, with denominator and evidence path.
5. **The blast radius** — after any falsification, claimlint C1a/C1b
   recomputes the consequence through `d:` / `e:` / `n:` edges; the walk
   records *who falls*, not only *what fell* (`CLAIMS.md` §4.1 is the
   standing example of the consequence a hand sweep misses).

### 2.3 The four terminal classes — mapped to register statuses, testably

The operator's four-way partition maps onto the register's vocabulary without
inventing a fifth status:

| walk class | register status | testable condition |
|---|---|---|
| **proven** | `PROVEN` | covering mutants killed (mutation-adequate) **and** an independent seat agrees **and** evidence committed under `docs/evidence/<id>/` |
| **falsified** | `FALSE` / `FALSE-AS-SCOPED` | a falsification test produced a counterexample: witness + denominator + red-then-green control |
| **verified** | `CLAIMED` *with independent re-implementation recorded* | an independent re-derivation agrees; promotion to PROVEN is held per DIRECTION Amendment 2 edge 5 (the verify-then-promote rule: a load-bearing claim moves to FALSE or PROVEN only after an independent seat agrees) |
| **unknown-untested** | `UNTESTED` | no falsification test exists yet; the claim names its `[F]` and the missing instrument |
| **untestable / difficult** | `INTRACTABLE` (no finite method) or `UNTESTED`/`CLAIMED` *with a stated difficulty* | a measured or argued reason why no finite test settles it, named explicitly |

"Verified" is a terminal class in its own right, not a synonym for proven: it
is the state where an independent re-implementation has confirmed the claim but
mutation-adequacy is still owed. It is exactly the state `4x4.C1` and `4x4.FP1`
already occupy (CLAIMED after the G3b discharge, held below PROVEN), and the
walk must not blur it into PROVEN.

### 2.4 The unknown-untested-untestable-difficult class — the sprint's most interesting output

This class is **enumerated, not shelved** (seed §2). The enumeration is a
committed deliverable (the DIFFICULT row, §5): one entry per claim, each entry
naming **why** it is hard, from a closed vocabulary:

| difficulty | what it names | standing examples (register) |
|---|---|---|
| **state-space size** | the reachable/enumerable set outgrows a stated budget | `GLOBAL.FP2-general` (INTRACTABLE, possibly unprovable by finite methods); the 4×4 C2 probe from empty (folded into the C2 harness because the exact solver is intractable) |
| **memory** | the representation exceeds RAM/runner cap | `4x4.D3` (writes-off 4×4 tractability, 8 h / 32 GB placeholder, UNTESTED); the 5×4 table forecast 41–45 GB (§3) |
| **ko-graph structure** | cycle/ko structure defeats the instrument, not the math | `GLOBAL.H1-MARKOV` / `QA-023` (Markovian sufficiency UNTESTED-for-want-of-contrast — the history generator misses the shortest arrival in 93% of states) |
| **proof-checking cost** | the check exists but costs more than the claim warrants | `4x4.FP1-C1`/`-C2` (seeding provenance, UNTESTED, post-hoc log reads); `4x4.S2-impl` / `4x4.S4` (size-specific Benson / area-scoring, ⬜ᴵᴺᴴ) |
| **contrast-generator defect** | the instrument that would settle it is itself broken | the QA-023 contrast generator (93% miss rate, `2B-3-AUDIT`) — an instrument defect masquerading as an epistemic unknown |

The enumeration's accept bar: every entry names a difficulty from this
vocabulary (or proposes a new vocabulary word with a definition), cites a
committed path, and states the smallest affordable experiment that would move
it out of the class — so "difficult" is never a synonym for "abandoned".

---

## 3. The push — a measured boundary with a named failure mode

### 3.1 The measurement ladder

The push measures, per goban size, the three resource dimensions that the
retrograde pipeline consumes:

| dimension | what is measured | committed datum the reading must reproduce (null control) |
|---|---|---|
| **nodes** | reachable state count (non-terminal `passes∈{0,1}` entries, terminal `passes=2`, total), legal positions, groups | `GLOBAL.REACH-P4-CENSUS`: 2×2 172/86/258 · 3×2 1,732/854/2,586 · 3×3 49,428/24,330/73,758 · 4×3 1,293,848/635,190/1,929,038 · 4×4 99,133,036/48,505,262/147,638,298; legal 57/489/12,675/321,689/24,318,165 |
| **memory** | peak RSS, table bytes, index bytes, census bitset bytes | 4×4 WZO2 table = 518,123,097 B, peak RSS 3,887 MB (`CODE.WZO2-BUILD-REPRO`) |
| **wall-clock** | sweeps, per-sweep time, total | 4×4 31 sweeps / 3,789.4 s (`CODE.WZO2-BUILD-REPRO`); 4×3 25 sweeps |

The ladder rungs are **2×2 → 3×2 → 3×3 → 4×3 → 4×4 → 5×4 → 5×5**. The first
five are re-measured (the existing numbers are the null control, not the
reading); 5×4 and 5×5 are attempted until the pipeline breaks.

### 3.2 The boundary — definition, not adjective

The boundary is the **smallest goban size at which a stated resource limit is
exceeded**, reported as a four-tuple:

```
{ size, resource, limit, failure mode }
```

where `limit` is a named constraint (the runner's 4 GB RSS cap, the host's
disk, a wall-clock budget, a sweep-count budget) and `failure mode` is *how* it
breaks (RSS breach → SIGKILL; table file exceeds disk; wall-clock exceeds the
session; sweep count stops converging in the budget). "The 5×4 boundary" is
meaningless without the tuple; "memory-bound at 5×4" is an adjective until the
tuple is filled.

**Current projection, labelled as such.** `GLOBAL.REACH-P4-CENSUS` carries the
standing scaling model — `n_entries ≈ c·3ⁿ` with `c ≈ 2.4` slowly falling —
projecting **5×4 ≈ 7.6–8.6×10⁹ entries → a 41–45 GB table and a ~110 GB dense
census bitset (RAM-bound)**, and **5×5 ≈ 1.7–2.1×10¹² entries → 9–11 TB**. These
are projections the sprint replaces with measurement. The likely measured
failure mode is **memory first** (the 4 GB runner cap is crossed well below the
5×4 table size), but the sprint does not pre-judge: wall-clock (sweep explosion)
and disk are live alternatives until measured.

### 3.3 The name — assigned once the nature is known

The sprint **names the threshold** (seed §2). The naming discipline:

1. The name is a short compound that **names the measured failure mode**, never
   a decoupled metaphor: `RAM wall` (RSS cap crossed), `disk wall` (table file
   exceeds storage), `sweep cliff` (sweep count explodes), `address ceiling`
   (dense index exceeds addressable space).
2. The name is proposed at **accept.md**, only after §3.2's tuple is measured,
   and is ratified by the operator (the human bookend — the name is one of the
   things the operator judges "did I get what I wanted" against).
3. Until measurement, the spec commits only to the discipline and the candidate
   vocabulary above. A name assigned before the measurement is an adjective, and
   is exactly what this spec forbids.

---

## 4. The smaller-goban floor — confirm or repair 2×2 / 3×2 / 3×3 first

The floor runs the walk's own machinery at the small gobans before any
4×4-or-larger reading is promoted. Its bars:

1. **Re-derive, don't inherit.** DIRECTION §1: every register row is presumed
   unverified until re-derived end-to-end. The floor re-derives the
   small-goban proven/verified claims from the axioms, not from their own
   status: `2x2.C1` / `3x2.C1` (fresh-start vs the history-aware exact solver),
   `2x2.BASICKO-TIE` / `3x2.BASICKO-TIE` / `3x3.BASICKO-TIE` (root values
   under exactly R), `2x2.B1` / `3x2.B1` / `3x3.B1` (least-fixpoint — note these
   are CLAIMED, not PROVEN, their primary evidence having been lost and only
   re-derived later).
2. **Repair what fails to re-derive.** A claim that does not survive the
   re-derivation is a finding, and the repair is a mutation row (FLOOR, §5),
   not a silent status edit. The #2 self-consistency auditor
   (`GLOBAL.AUDITOR`) is the mandatory pre-commit gate for any finisher / memo /
   ko handling touched by the repair: zero minimax-identity violations on 3×2
   exhaustive + the deepest-N 4×4 sample.
3. **Mutation-adequacy binds promotion, not dispatch** (DIRECTION Amendment 2).
   The floor's repair rows may dispatch in parallel with the push's measurement
   rows; no claim at any size promotes past CLAIMED until the mutants covering
   its function are killed. The floor confirms the *small* gobans first because
   they are cheap and exhaustive — the ladder discipline of the g3b spec §7 —
   not because the waypoint number demands it.

The floor's accept sentence: *2×2 and 3×2 fresh-start values are re-derived and
3×3's root (+9) is re-confirmed against the MIGOS basic-ko anchor, each with a
denominator and a red-then-green control, before any 4×4-or-larger reading is
reported as anything but CLAIMED.*

---

## 5. Decomposition into worker rows

Analysis is parallel and unlimited; mutation is serial per file hold
(`docs/infra/delegation/ROLES.md` §Concurrency). Exact managent task IDs are
assigned at dispatch; the labels below are plan-local names the Orchestrator
registers, each with its `needs`.

### 5.1 Row table

| label | row (one-line) | holds (file) | set | needs (plan labels) |
|---|---|---|---|---|
| **WALK-INV** | produce the walk map: every tree node × its rows × its `[F]` × its alternative hypothesis, committed | `sprints/complexity-boundary/pass0/walk-map.md` | cb-walk | — |
| **WALK-\<node\>** (one per tree-node family: `Z-R`, `Z-STATE`, `Z-CONVERGE`, `Z-TABLE`, `Z-COMPLETE`, `Z-SYM/AUDIT/NONCLAIMS`) | challenge every row of the node with its alternative hypothesis; drive each to a terminal class; propose register changes via findings | — (findings only; never edits `CLAIMS.md` directly) | cb-walk | WALK-INV |
| **DIFFICULT** | enumerate the unknown-untested-untestable-difficult class, each entry with its difficulty + smallest affordable exit experiment | `sprints/complexity-boundary/pass0/difficult.md` | cb-walk | WALK-\<node\> |
| **FLOOR** | re-derive and, where needed, repair 2×2 / 3×2 / 3×3 proven/verified status; #2 auditor on any finisher/memo/ko touch | `src/rules.zig` (only if repair touches it; otherwise none) | cb-mutate | WALK-INV |
| **PUSH-MEASURE** | measure nodes/memory/wall-clock at 2×2→5×5 until a stated limit breaks; report the §3.2 tuple | its instrument file (e.g. extending `src/t358_census_*.zig` or a new `src/t777_push.zig`) | cb-mutate | — |
| **NAME** | accept-time: name the boundary per §3.3, ratify with the operator | `accept.md` | cb-mutate | PUSH-MEASURE, FLOOR, DIFFICULT, WALK-\<node\> |
| **UNIF-P1** | engine-unification pass1: delete `genericChainCaptured` / `genericIsLegal` / `genericPosFromMove`, extend to 4×3 / 4×4 (Waypoint-2, §7) | `src/rules.zig` + the generic-* homes | cb-mutate | WALK-INV |

**Serialization.** All `cb-walk` rows run in parallel (no shared file; they
propose via findings and the absorb gate serializes the register write). All
`cb-mutate` rows serialize on their declared holds. `CLAIMS.md` and
`register-tree-map.md` have single owners (the claims-register agent and the
mapping owner): **no walk row edits either directly** — rows propose, the
absorption gate applies, claimlint C7/C9 is the mechanized reconciliation.
`build.zig` is the single-writer choke point through the Orchestrator (g3b
plan §5 precedent).

### 5.2 Where T531 and T535 slot — coordinate, do not duplicate

- **T531 (verify-battery two-surfaces)** is being dispatched alongside this
  sprint and holds many of the files the sprint's mutation rows would touch
  (`src/rules.zig`, `src/colex.zig`, `build.zig`, the `vb_*` battery files,
  `docs/infra/suite-truth-manifest.md`). **Slot:** the sprint's instrument
  readings (PUSH-MEASURE, and the battery cells the walk invokes) report
  *through* T531's suite-truth manifest — console summary stays clean, evidence
  lines live in the manifest artifact. The sprint builds **no new reporting
  surface**. **Coordination:** any `cb-mutate` row that touches a file T531
  holds declares `needs T531` (or sequences after it), so the one-writer-at-a-time
  rule mechanizes the handoff instead of a prose promise. The analysis rows are
  unblocked by T531 (they read committed docs and artifacts) and may start now.
- **T535 (stage-4 clean-story)** is queued, not dispatched, and sequenced after
  L1 and Stage 3.4. **Slot:** it is *downstream* of this sprint. The walk
  produces the epistemic content — claim verdicts — that T535's clean story
  later narrates and squashes; T535's own constraint #3 (evidence chain
  hash-addressed, claimlint C2/C10 not worse before and after) is exactly what
  this sprint's absorb gate preserves. **Coordination:** this sprint drives
  claims to verdicts and keeps the register C7-clean through the standard
  absorption gate; it does **not** do ledger cleanup, retirement rulings, or
  history squash — those are T535's deliverable, and duplicating them would
  race the same files (CLAIMS.md, the register).

---

## 6. Controls — every instrument red-then-green before its first reading counts

The standing rule (`AGENTS.md` §Verification rules; `GLOBAL.CALIB-LESSON`): a
self-consistency check with no passing calibration case cannot distinguish
"bug" from "definition"; a positive control must exercise the instrument under
test, not a parallel one. Applied to every instrument this sprint introduces or
invokes:

| instrument | null control (must pass clean) | seeded-defect control (must fail) |
|---|---|---|
| **complexity census** (PUSH-MEASURE) | reproduces the committed `GLOBAL.REACH-P4-CENSUS` numbers at 4×4 and below exactly | a planted census defect (e.g. drop the ko dimension, or seed both sides) shifts the count and is caught |
| **each falsification test** (WALK-\<node\>) | passes a known-true claim (the committed `[F]`-free case) | a synthetic mutant of the claim's function is caught (mutation-adequacy, DeMillo–Lipton–Sayward) |
| **floor re-derivation** (FLOOR) | reproduces the committed small-goban values | a seeded value/suicide/ko defect is caught before the re-derived reading is recorded |
| **engine-unification differential** (UNIF-P1) | kernel and legacy agree on the standing fixtures | a seeded disagreement (allow suicide, allow ko recapture) is caught — the T265 test pattern |

A check that passes both the clean input and the seeded mutant is **blind**, and
its reading is not reported as a pass (QA-023). A check that cannot fail is not
a check. The controls run at the smallest goban where they are non-vacuous
first (2×2, moving to 3×2 where the all-legal graph is entirely cycle-reachable
and the seeded ko control would otherwise be vacuous — g3b spec §7.2 precedent).

---

## 7. Engine-unification pass1 — minted, explicitly, as Waypoint-2 work

`WAYPOINTS.md` §carry-forward records engine-unification pass1 (delete
`genericChainCaptured`, `genericIsLegal`, `genericPosFromMove`, extend to
4×3/4×4) as Waypoint-2 work waiting on the kernel's shape. **This sprint mints
it** (the UNIF-P1 row), for three stated reasons:

1. **The push needs a size-generic engine.** Extending to 4×3/4×4 — and
   measuring 5×4 — is exactly pass1's scope; the size-specialized `generic*`
   functions are the thing that stops being free at the boundary, so the
   boundary and the unification are the same measurement viewed twice.
2. **The walk needs one production rule under test.** L5 (one rulebook) and the
   walk's per-size challenge both require the single production move generator /
   colex engine to be the thing challenged, not a family of copies.
3. **It is already spec'd.** `sprints/engine-unification/pass0/spec.md` names
   pass1's scope precisely; this sprint does not re-specify it, it dispatches it
   as a `cb-mutate` row.

The pass1 row ships code and promotes **nothing** past CLAIMED until the
covering mutants are killed (DIRECTION Amendment 2 edge 5); it is Waypoint-2
kernel-extraction work, serialized on `src/rules.zig` and sequenced after T531's
hold on the same file via `needs`.

---

## 8. Feasibility questions flagged for plan.md — not answered here

1. **How "past 4×4" is measured without a full 5×4 solve.** The push's honest
   form is a *census* at 5×4 (reachable states, no values) — cheap, exactly the
   `GLOBAL.H1-CENSUS` method that measured 4×4 without building it — plus the
   scaling-model check. Whether the sprint additionally attempts a partial 5×4
   value build to measure the *value* pipeline's breakage (vs the census's) is a
   plan.md decision with a stated budget.
2. **Which resource breaks first.** The plan must pre-register the order in
   which limits are tested (RSS cap → disk → wall-clock → sweep count) so the
   first breach is a measured fact, not a chosen narrative.
3. **The walk's parallelism ceiling.** Analysis is unlimited, but each
   `WALK-<node>` row proposes register changes; the plan must state how many
   node rows run concurrently without racing the absorption gate.
4. **Whether the floor's re-derivation re-runs the exact-solver comparison or
   certifies the committed one.** The g3b C-A2 precedent (§6.2 there) ruled:
   re-run from scratch with the independent kernel, never certify the builder's
   own computation. The plan should adopt the same for the floor.
5. **Whether the push's wall-clock reading includes the measured parallel
   fixpoint** (`CODE.PARALLEL-FIXPOINT-MEASURED`, 2.91× at N=16) or measures the
   serial pipeline only. Default: serial first (the artifact that exists);
   parallel is a measured alternative only if wall-clock — not memory — is what
   breaks.

---

## 9. Scope boundaries

### In scope

- The walk (§2): tree-node × row challenge, the four terminal classes, the
  difficult-class enumeration.
- The push (§3): nodes/memory/wall-clock at 2×2 → 5×5 until a limit breaks; the
  §3.2 boundary tuple; the §3.3 name.
- The smaller-goban floor (§4): 2×2 / 3×2 / 3×3 re-derivation and repair.
- Engine-unification pass1 (§7), as a Waypoint-2 mutation row.
- The controls (§6), red-then-green, wired into `zig build test` where the
  instrument is code.
- Findings proposing register changes, routed through the standard absorption
  gate (never a direct `CLAIMS.md` edit).

### Out of scope

- Positional superko exact-solve and score-on-cycle — foreclosed (`2x2.R1`,
  `GLOBAL.R2`); the push measures the k=1 pipeline only.
- E2 / a new axiom set — relaxed heuristics are epic-02 work (seed §3); this
  sprint stays within E1, where axioms change only on incoherence.
- Real-game PSK values — not claimed (NC1–NC5 of `AXIOMS.md` §1.2).
- Ledger cleanup, retirement rulings, history squash — T535's.
- A new reporting surface — T531's suite-truth manifest is the single surface.
- The #2 auditor as a *verification* deliverable — it is the gate the FLOOR and
  UNIF-P1 rows invoke on finisher/memo/ko touches, not a thing this sprint
  re-derives.
- Parallel fixpoint as a performance deliverable — a plan.md question (§8.5),
  not a committed row.

### Not yet decided — plan.md decisions

All of §8, plus exact managent task IDs, the `WALK-<node>` family boundaries,
and the PUSH-MEASURE instrument's file.

---

## 10. Standing rules

- **Builds go through `tools/runner`** (auto `-O ReleaseFast`, 4 GB RSS guard).
- **stdout = data, stderr = diagnostics** (`util.out` / `util.note` / `util.warn`).
- **Findings propose claims at CLAIMED or below; nobody edits `CLAIMS.md`
  directly.** The absorb gate applies; claimlint C7/C9 reconciles.
- **Evidence under `docs/evidence/<claim-id>/`**, never `untracked/`.
- **Numbers cite their run and state their denominator.** The boundary tuple
  (§3.2) is a number with a denominator or it is not a boundary.
- **One writer per engine file** (`src/rules.zig`, `src/retro.zig`,
  `oracle.zig`, `solve.zig`); `build.zig` serializes through the Orchestrator.
- **No silent writes to `data/` or `artifacts/`.** New rule → new file, tagged
  `(size, ruleset)`.
- **Scores are ALWAYS Black-positive.**
- **Per-goban epistemic independence** — no inheritance without a written
  argument.
- **Commit via `tools/git-commit-mine <paths> -m <msg>`**; stage by name, never
  a wildcard.

---

## 11. Amendment log

| date | amendment | by |
|---|---|---|
| 2026-08-23 | Initial spec — T777 | deepseek-v4-pro/T777 |
