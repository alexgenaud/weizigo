# G3b value-correctness — pass0 PLAN

```
Task: T333 · Role: worker · Model: glm-5.2 · Date: 2026-08-04
Revision: 5 · Status: **RATIFIED 2026-08-04** (sprint owner, on T334 round-2
        PASS-WITH-EDITS with both required edits applied — round 2 of 2, no
        further audit round owed)
        (Rev 2 is the builder's — T333/glm-5.2, all six findings; Rev 3 is a
        gate-holder path repoint; Rev 4 applies T334's N1 + N2 edits; Rev 5
        replaces N2's hedge with the measured `holdsConflict` semantics)
Sprint: g3b-value-correctness · Pass: 0
Parent: pass0/spec.md (Revision 4, RATIFIED 2026-08-04 — spec audit T329 Rev 2;
        T332 F1 amended Rev 3, re-rooting the artifact identity to WZO2;
        Rev 4 repoints that artifact to its deployed path)
Sprint owner: Orchestrator
```

**This is the plan bookend** — the builder's strategy for the pass: the six
feasibility decisions the spec left open, the 4×4 sampling denominator, the
phase sequence and gates, the file-ownership row table that mechanizes spec
§3's dependency edges as `needs`, the R8 authorship-independence structure,
parallelism, effort, and the third-language ruling. Prose only, no code. It
will be audited (document review, fresh session) and ratified by the sprint
owner before any build row is registered.

**Inputs read.** `AGENTS.md` · `DELEGATEE.md` · `sprint.md` ·
`pass0/spec.md` (Rev 3 as read by the builder; Rev 4's path repoint applied by
the gate-holder afterwards) · `archive/spec-audit-r1.md` (T329, all ten findings
dispositioned) · `archive/plan-audit-r1.md` (T332, five findings F1–F5 +
gate-holder F6, all six dispositioned; the mandate for this revision) ·
`sprints/oracle-v2/pass0/design-M1.md` (rev 3, RATIFIED G2 — the WZO2 schema
authority) · `DIRECTION.md` + Amendments 1 & 2 · `WAYPOINTS.md` §The G3
gate is split · `sprints/verify-battery/pass1/spec.md` (check inventory) ·
`sprints/verify-battery/pass1/mutants.md` (seven known-unkilled mutants) ·
`sprints/verify-battery/pass0/design-M1.md` §4.6 (SMD1 format, already
specified) · `sprints/verify-battery/pass1/i5-feasibility.md` +
`archive/i5-feasibility.md` (T134, the 4×4 memory precedent) ·
`findings/T273-kernel-ko.json` (kernel already has `koAfterCapture`/
`stateKey`) · `AXIOMS.md` (requirement tree + ruleset R) · `src/rules.zig`,
`src/exp6_solve.zig`, `src/differential.zig` (current kernel/solver state).
The WZO2 artifact header was parsed directly (T333, 2026-08-04); the numbers
in §2.1 are measured, not assumed.

**No contradiction with spec Rev 4 is intended.** Where this plan needs the
spec to change, that is a plan-amendment halt (`sprint.md` §Bookends), not a
silent divergence. No such halt is triggered here; every §6 question is
answered within the spec's framed options.

---

## 1. The goal, restated as a plan constraint

The plan serves exactly the spec's goal sentence (§1): the L/H values in the
4×4 table are the fixpoint values of R, closed under Φ, with no fabricated or
fallback rows. The plan's job is to make that *checkable* — to decide the
open feasibility questions, name the rows and their `needs` edges, and
declare the order and gates so that the verdict is earned, not asserted. The
verdict set is fixed by spec §2.3 (six checks + seven mutants killed); this
plan does not reopen any pass condition.

---

## 2. Feasibility decisions — spec §6, each answered

### 2.1 §6.1 — Memory plan for closure over the WZO2 table (F1 re-root)

**Decision: in-core, snapshot-sweep BFS over the loaded WZO2 table, ~531 MB
peak — well under the 4 GB runner cap. Membership by group-index binary
search + in-group linear scan, zero extra memory.**

**Artifact identity (F1 re-root, spec Rev 3; path per spec Rev 4).** The sprint
artifact is **`data/oracle-4x4-v2.wzo2`** — the deployed copy of the oracle-v2
build this task parsed at `untracked/oracle-v2/oracle-4x4-v2.wzo2`, byte-identical
and both listed in `artifacts/SHA256SUMS`; the header figures below were read from
the build and re-verified against the deployed copy — **WZO2**, 518,123,097 bytes,
full-file SHA-256 `0c3366f0…` (the header-embedded slot digest at offset 40,
computed with bytes 40–71 zeroed per design-M1 §4.2, is `57009d93…`; both
are reproducible). Header parsed directly 2026-08-04 (T333):
`magic="WZO2", version=1, w=4, h=4, rules_id=3, entry_size=4,
group_header_size=5, ko_bits=5, hdr_flags=1 (PASSES_2_OMITTED),
n_groups=24,318,165, n_entries=99,133,036, data_offset=128`. File size
validates the layout: `128 + 24,318,165×5 + 99,133,036×4 = 518,123,097` ✓.
**Not** `data/oracle-4x4.checkpoint.wzo` (WZO1, 2026-07-21 PSK-era residue,
header `total=3^16`, no ko/passes dimension — it cannot represent the k=1
state this epic is about, and is ruled untrustworthy at the pivot). The
authority for the schema is `sprints/oracle-v2/pass0/design-M1.md` (rev 3,
RATIFIED G2), **not** `AGENTS.md`'s 258 MB figure — that is the WZO1 file
size, which Rev 1 of this plan leaned on by mistake.

**Schema relevant to closure** (design-M1 §§1–4). Three contiguous regions:
Header (128 B) | Group index (`n_groups × 5` B) | Entry data
(`n_entries × 4` B). Group header = `colex (u32 LE) + entry_count (u8)`;
groups are sorted by colex (binary-searchable). Entry =
`key_byte (u8) + L (i8) + H (i8) + DTT (u8)`. `key_byte` packs
`[passes:1][ko_point:KO_BITS][side:1][terminal:1]`, MSB→LSB, `KO_BITS=5` at
4×4 (ko values 0…16, 16 = none). Entries within a group are sorted by
`(colex, passes, ko_point, side)` — equivalently `key_byte & 0xFE`. Three
format invariants closure must honour:

- **`PASSES_2_OMITTED` (hdr_flags bit 0):** passes=2 states are NOT stored —
  they are the absorbing terminal. A passes=2 child is *expected-absent*, not
  a missing entry; C-A1 must not count it as `children_not_in_table`.
- **`passes ≥ 1 ⇒ ko = none` (§2.5):** every stored passes=1 entry has
  `ko = none`. A ko-active state exists only at passes=0.
- **KO_SENSITIVE is not stored** — computed by the reader as `L != H`. The
  I4 KO_SENSITIVE-clear/-set split reads `L,H` per entry.
- **`terminal` (key_byte LSB):** a passes∈{0,1} entry with `terminal=1` has
  no legal placement; its only move is pass. The kernel move generator
  yields only the pass child from such a state.

**Membership predicate (F1 reconciliation).** The full Markov state key is
`(colex, side, ko_point, passes)`, passes∈{0,1}. To look up a child key:

1. Binary-search the in-memory group index (a sorted `n_groups` array of
   u32 colex values, packed 5 B each) for `colex` → O(log n_groups) ≈ O(25).
2. Within the located group (≤ `2×(w·h+2) = 36` entries at 4×4), linear-scan
   the entry data for an entry whose `key_byte & 0xFE == target_kb`, where
   `target_kb` packs `(passes, ko_point, side)` — the `terminal` LSB is
   masked off (a terminal-flagged entry and its non-terminal twin share the
   same masked key; both are valid lookups depending on what the caller
   asks). O(≤36).
3. The group's byte range in the entry data is found via a sparse prefix sum
   (cumulative entry index every 256th group, `n_groups/256 × 4 ≈ 380 KB`)
   plus summing ≤255 `entry_count` bytes from the group index already in
   cache.

This is O(log G + ≤36) per lookup, **zero extra memory** beyond the group
index already loaded for lookups and the mmap'd entry data. No rank-support
bitset, no dense remap, no hash set — those were T134's solution for
*Tarjan* (dense vertex ids); closure does not need them. (If, contrary to
the parsed header and the format doc, the group index were not sorted by
colex, binary search would be unsound and CLOSURE would need a hash set
keyed on `colex` — ~1.2 GB, still feasible; that is the spec-amendment halt
trigger in §13. The parsed header and design-M1 §2.4 both guarantee the
sort, so the trigger is not pulled.)

**The reachable set is the table.** G3a established structural
completeness: the stored `n_entries = 99,133,036` entries are exactly the
root-reachable non-terminal (passes∈{0,1}) states. C-A2 (backward closure)
therefore BFS-expands only states that are *in the table*; the table is the
bound on the work, not the spec's ~146 M estimate. Spec §6.1's
`24.3 M groups × 3 pass × 2 sides ≈ 146 M` double-counts: it includes the
passes=2 terminal (not stored) and passes=1 ko≠none states (excluded by the
§2.5 invariant). The measured table is **99,133,036** entries, not 146 M.

**Memory budget.**

| component | size | resident? |
|---|---|---|
| Group index (`n_groups × 5`) | 121.59 MB | in memory (kept for lookups) |
| Sparse prefix sum | ~380 KB | in memory |
| Entry data (`n_entries × 4`) | 396.53 MB virtual | mmap'd; closure touches every entry → ~396.5 MB resident |
| Visited bitset over table index (C-A2 only) | `n_entries` bits = 12.39 MB | in memory |
| Move-gen scratch (a handful of `[16]i8` boards, reused) | <1 KB | — |

- **C-A1 (forward, single linear scan, no visited):** peak RSS ≈ 121.59 +
  396.53 + scratch ≈ **~518 MB** (the file's own working set).
- **C-A2 (backward BFS, snapshot-sweep):** peak RSS ≈ 121.59 + 396.53 +
  12.39 + scratch ≈ **~531 MB**. Headroom under the 4 GB runner cap is
  ~3.47 GB.

This is more comfortable than T134's Tarjan plan (~1.2 GB) because closure
is BFS over the table, not DFS-with-stacks over a dense vertex space, and
because the 4-byte WZO2 entry (vs the WZO1 6-byte row) plus the
index/mmap split keeps the resident working set at the file's own ~518 MB.

- **Snapshot-sweep, not a queue.** Following the *shape* of T134 §4.2 /
  EXP-3 — **analogy only (F5): T134's precedent is the I5 SCC/Tarjan memory
  plan, not a closure sweep.** Each sweep scans the visited bitset linearly,
  expands all newly-marked entries, marks their in-table non-terminal
  children. This eliminates the BFS queue (which at 99.13 M × 8 B would be
  ~793 MB) at the cost of O(sweeps) passes over the bitset. Sweeps at 4×4
  are bounded by the longest acyclic path in the reachable graph (stone
  placements + ≤2 passes, since passes=2 is the absorbing terminal); the
  budget is **≤40 sweeps as a planning estimate, not a carried-over
  measurement.** The actual closure sweep count is an **accept.md
  measurement** (F5), recorded with its denominator; it is not leaned on as
  a carried-over precedent.
- **Fallback (stated trigger, not expected).** If peak RSS exceeds 3.5 GB
  during closure (it will not, by the budget above — headroom is ~3.47 GB),
  fall back to stream-from-disk: the entry data stays on disk, closure
  streams groups in fixed-size blocks, membership checks go to the
  already-in-memory group index plus on-disk entry reads. A memory-plan
  breach is a `battery-bad` exit (code 2), not an artifact-bad finding (spec
  §6.1). The trigger is the runner's RSS report; the fallback is a build-row
  scope expansion, which is a plan amendment, not a silent switch.

**Denominators C-A1 will report:** `n_entries = 99,133,036` table entries
scanned, total non-terminal children generated, `children_not_in_table`
(verdict: 0 — passes=2 children are expected-absent terminals, not counted
as missing), average branching factor. **C-A2:** reachable non-terminal
count (must equal `n_entries`), reachable terminal (passes=2) count (not
stored, reported separately), `reachable_not_in_table` (verdict: 0), % of
colex space reachable = `n_groups / 24,318,165` (legal positions, A094777).

### 2.2 §6.2 — C-A2: re-run reachability or certify T266?

**Decision: re-run from scratch with the kernel move generator. T266's
census is the expected value (cross-check), never the input.**

Rationale: the spec's own recommendation, adopted. Certifying T266's output
by replaying its computation is the QA-023 pattern — five audit links, four
passed the artefact through — because T266 used the *solver's* move
generator, the same code that built the artifact. The independent path is
the freshly-extracted, invariant-licensed **kernel** move generator (a
sprint deliverable, edge 1). C-A2 recomputes the reachable set from the
fresh-start root with the kernel move generator and asserts every reached
state is in the table. T266's census count is recorded as the expected
value; a disagreement is `reference-bad` (exit 3) if within a known spread,
else an escalation. The kernel move generator is licensed by edge 2's
defect-reproducing invariant before C-A2 runs, so "re-run with the kernel"
is not "re-run with a copy of the builder."

### 2.3 §6.3 — Parallel fixpoint

**Decision: confirmed OUT OF SCOPE for pass0.** Verify the artifact that
exists, with the serial Bellman operator. T312/T314's parallel fixpoint is a
separate sprint with its own value-correctness pass. No `needs` edge to any
parallel-fixpoint row is created. (Spec §6.3 already rules this; the plan
records the confirmation so no build row revives it.)

### 2.4 §6.4 — Reuse T267's `differential.zig` pattern?

**Decision: yes — reuse and extend `differential.zig`. Do not write a
move-generator-specific invariant in a new file.**

Rationale: `differential.zig` already (a) compares kernel vs solver, (b)
carries the null control (same impl registered twice → perfect agreement)
and the seeded-defect control (deliberately mutated copy → caught), and (c)
is wired into `zig build test` (T267). The move-generator extraction adds
one *operation* to this harness — `legalMoves(state) → move bitmap` —
registered as two implementations (kernel, solver), compared exhaustively
at 2×2 / 3×2 / 3×3, with a seeded known-incorrect mutant (allow suicide, or
allow a ko recapture) that the invariant must catch. This is the T273
pattern applied to the move relation. A new file would duplicate the
control machinery that already exists and that the QA-023 standing rules
were written against. File ownership: the movegen-invariant row holds
`src/differential.zig` (set `g3b-movegen`), serialized with the kernel
extraction row (§6).

### 2.5 §6.5 — SMD1 format and scope

**Decision: adopt the SMD1 format already specified in
`sprints/verify-battery/pass0/design-M1.md` §4.6, unchanged. Do not
re-invent. Scope: exhaustive at 2×2, 3×2, 3×3; sampled at 4×4 (sample in §3).**

Rationale: the format is a finished contract — 28-byte header, sorted
records, CRC-32, bit-per-cell move bitmap + pass bit, slice `ko=NONE,
passes=0`. It already names the solver-side generation responsibility and
the battery-side reading responsibility. Re-specifying it would fork the
contract between the two batteries (verify-battery and g3b) that both read
it. The g3b sprint's only SMD1 deliverable is the *solver-side dump
utility* (`tools/smd1.zig` or a solver invocation mode) that emits this
format; the battery's I11 reader consumes it. Exhaustive scope at
2×2–3×3 covers every legal position at the artifact slice for both sides;
4×4 is sampled per §3.

### 2.6 §6.6 — G1/G3 key-agreement at 4×4: full scale or sampled?

**Decision: exhaustive over the table's entries at 4×4 (the reachable
set, `n_entries = 99,133,036`), not sampled. Not over the full
legal-position space.**

Rationale: state-key computation is O(1) per state — no move generation, no
graph traversal — so exhaustive over the reachable set is cheap. The
key-agreement invariant (T267) checks producer key == consumer key for
states reachable by real play; the table holds exactly those states.
Iterating the loaded WZO2 table (group index in memory + mmap'd entry data)
and comparing `rules.stateKey` (producer, T273) against the battery's R8
encoder (consumer) for every entry — reconstructing the full
`(colex, side, ko, passes)` key from the group header + `key_byte` per entry —
is a single linear pass: ~99.1 M comparisons, peak RSS ≈ group index
(121.6 MB) + entry data resident after the scan (396.5 MB) + scratch ≈
**~518 MB**, wall time minutes. This is strictly stronger than sampling and
is feasible, so sampling would be a needless weakening. The denominator is
`n_entries = 99,133,036` (table entry count), reported as
`key_mismatches / n_entries` with verdict 0.

---

## 3. I11 / R8 sampling at 4×4 — size, distribution, denominator

**Decision: stratified random sample, N = 50 000 states, drawn from the
table's reachable entries at the artifact slice (`ko=NONE, passes=0`).**

Distribution (deterministic, seed recorded in the dump sidecar):

- **By side:** 25 000 Black-to-move, 25 000 White-to-move.
- **By colex decile:** 10 strata over the colex-index range of the slice,
  5 000 states per stratum, so coverage spans early-game (sparse boards)
  and late-game (full boards) rather than clustering wherever the
  reachable set is dense.
- **Seed:** fixed (e.g. 31337), recorded in the `.smd1.json` sidecar and in
  the I11 header record, so the sample is reproducible and auditable.

Denominator the accept.md will report:

> `mismatches == 0` over **50 000 sampled states** (stratified: 25 K Black /
> 25 K White, 10 colex-decile strata × 5 K, seed 31337), drawn from
> `<reachable-count-at-slice>` reachable table entries at the artifact
> slice (`ko=NONE, passes=0`) out of 24 318 165 legal 4×4 positions
> (A094777). Exhaustive at 2×2, 3×2, 3×3.

Why 50 000 and not exhaustive: exhaustive I11 at 4×4 is ~48.6 M move-set
computations per side (24.3 M positions × 2 sides), each generating up to 17
moves — the compute bottleneck T134 §4.7 identifies. It is *borderline*
feasible (minutes-to-tens-of-minutes) but the spec explicitly defers 4×4 to
a plan-decided sample. A 50 K stratified sample catches any systematic
disagreement affecting >~0.01 % of states with high confidence while running
in seconds; exhaustive is a documented **stretch goal** gated on wall-time
budget — if the 50 K run is clean and wall-time remains under budget, the
row may take the exhaustive reading and report both denominators. The
stretch goal is not a commitment; the sampled reading is the verdict of
record.

---

## 4. Phase sequence and gates

Per `sprint.md` §Phases and §Audit gates. This pass runs **Plan, Scope
(merged into Plan), Design, Test, Build, Accept**. Spec is done (Rev 4,
RATIFIED 2026-08-04). The phase number is not a dependency (DIRECTION Amendment 2);
the real serializer is file ownership (§6). TDD is non-negotiable: tests are
written and reviewed before the implementation they test (the 2B-5 scar).

| phase | file | runs this pass? | gate instrument | gate holder |
|---|---|---|---|---|
| Spec | `spec.md` | done (Rev 4, RATIFIED 2026-08-04) | document review (T329 PASS-WITH-EDITS ratified Rev 2; T332 F1 → Rev 3 amendment, re-rooting artifact to WZO2; Rev 4 repoints it to the deployed path) | spec auditor |
| **Plan** | `plan.md` (this) | yes | **document review, fresh session** | plan auditor |
| Scope | — | **merged into Plan** (§12 MoSCoW; spec §8 already bounds scope) | (none — folded) | — |
| **Design** | `design.md` | yes | **adversarial review** — attempt refutation, state a verdict | design auditor |
| **Test** | `test.md` | yes, **before Build** | review tests **without reading the implementation** | test auditor |
| **Build** | `build.md` | yes | **independent re-implementation of the core check** (R8 vs kernel, different author) + the differential invariant kills its own mutant | build auditor |
| **Accept** | `accept.md` | yes | **numbers audit**: denominators, calibration, standing epistemic rules | accept auditor |

Gates are mechanized the day they are declared (DIRECTION §5): the
differential invariant and the mutant kill-matrix are wired into
`zig build test`; the battery's null/seeded-defect controls are assertions,
not prose. A gate that stays prose is a defect in this plan.

**Test-before-build, concretely.** The `test.md` row writes, for each check,
(a) the acceptance test against a known-good fixture and (b) the known-bad
synthetic mutant the check must fail (spec §7.2 calibration rule), and
wires both into `zig build test` *before* the check's implementation row
starts. The build row then makes the known-good test pass and the
known-bad test fail. A check whose known-bad mutant survives is blind
(QA-023); its 4×4 reading is not reported as a pass.

---

## 5. File ownership and the row table — spec §3 edges as `needs`

One writer per engine file (`AGENTS.md`). Rows in the same `set` serialize;
rows in different sets may run concurrently. `build.zig` is the single-writer
choke point: every row that adds a build step declares it in §6 and the
Orchestrator serializes those touches. Exact managent task IDs are assigned
at dispatch; the labels below are the plan-local names the Orchestrator
registers, each with the `needs` shown.

| label | row (one-line) | holds (file) | set | needs (plan labels) | spec edge |
|---|---|---|---|---|---|
| **MG-INV** | move-generator differential invariant: extend `differential.zig` with a `legalMoves` operation + null control + seeded-defect control; **exhaustive over the full `(pos, side, ko, passes)` space at 2×2 / 3×2 / 3×3, including `ko≠NONE` states** (F6 — SMD1's slice is `ko=NONE, passes=0`, so I11 never compares at a ko-active state; ko-dimension coverage of the move relation lives here); prove the invariant catches a known-incorrect move mutant — **including a ko-recapture mutant caught at a ko-active state** (the T265 defect family; spec §7.2 amendment 2026-08-04) — *before* the kernel is plugged in | `src/differential.zig` | g3b-movegen | — | edge 2 (the invariant) |
| **MG-KERN** | extract the kernel move generator (`legalMoves`/`applyMove`/`applyPass`, assembling `rules.pos_from_move` + `rules.koAfterCapture` + pass/ko logic) into `src/rules.zig`, headed by the A1–A6/B1–B3 prose spec sentence + claim ID, TDD | `src/rules.zig` | g3b-movegen | MG-INV | edge 1, edge 2 (the move) |
| **R8** | battery's independent move generator + independent state-key encoder, in `src/vb_movegen.zig`; different author than MG-KERN, blind to kernel/solver source (§7) | `src/vb_movegen.zig` | g3b-battery | — (input: AXIOMS.md only) | edge 3, 4 (the R8 side) |
| **SMD1** | solver-side move-set dump utility emitting the §4.6 SMD1 format (`tools/smd1.zig` or a solver mode), using the kernel move generator | `tools/smd1.zig` | g3b-tools | MG-KERN | edge 3 (SMD1 side) |
| **CLOSURE** | C-A1 forward + C-A2 backward closure (§2.1 memory plan), binary-search membership over the sorted table | `src/vb_closure.zig` | g3b-battery | MG-KERN | edge 1 |
| **I4-4x4** | I4 Bellman residual at 4×4, Φ from R8; report KO_SENSITIVE-clear and KO_SENSITIVE-set violation counts separately (spec §2.4) | `src/vb_bellman_4x4.zig` | g3b-battery | R8 | edge 4 |
| **I5-4x4** | I5 SCC containment at 4×4, move graph from R8; iterative Tarjan per T134's memory plan (~1.2 GB peak). **First seeded-defect control at 3×2** (F2 — the 2×2 all-legal graph is entirely cycle-reachable, spec §7.2): set `KO_SENSITIVE` spuriously on a non-cycle-reachable 3×2 slot → `ko_not_cr > 0`, shown red-then-green **before** the 4×4 reading; this is a row bar, not effort-table prose | `src/vb_scc_4x4.zig` | g3b-battery | R8 | (supports Z-CONVERGE-FIX) |
| **KEY-4x4** | G1/G3 key-agreement at 4×4, exhaustive over the table (§2.6); extends `differential.zig` with the 4×4-scale run | `src/differential.zig` — **sequential ownership after MG-INV**, never concurrent (T334 N2; `spec.md:278`'s "one owner" reads as one *at a time*). Both rows declare the hold on purpose: `managent`'s `holdsConflict` refuses a claim only against an **in-progress** holder (`src/managent/main.zig:981`), so declaring it is what mechanizes the rule, and *not* declaring it would enforce nothing | g3b-movegen | MG-INV, R8 | (closes G1/G3; kills M1–M4) |
| **I11** | I11 move-set consistency: read SMD1 dump, compare against R8; null control (§4.1) + seeded-defect control (§4.2) before first reading counts | `src/vb_i11.zig` | g3b-battery | SMD1, R8 | edge 3 |
| **BATT-HEALTH** | M9 meta-check: every invariant returns a real verdict, not `.skipped`; enumerate declared invariants, run each, assert status | `src/vb_health.zig` | g3b-battery | R8 | edge 5 (M9) |
| **DISCHARGE** | G3b discharge / accept row: collect all check readings; **the bar is the seven mutant-kill assertions inverted in `vb_mutants.zig`** (F3 — M1–M4 by KEY-4x4, M8 by CLOSURE, M9 by BATT-HEALTH, M10 by I11's null control), a mechanized checkable assertion not merely the six check rows closed; the `needs` edges stay row-level because managent edges are rows; write `accept.md` | `accept.md` (+ findings) | A | KEY-4x4, CLOSURE, I4-4x4, I5-4x4, I11, BATT-HEALTH | edge 5 |

**Mutant → killer mapping** (spec §2.3 item 6, edge 5 currency):

| mutant | killed by | row |
|---|---|---|
| M1 (colex vs rank) | key-agreement | KEY-4x4 |
| M2 (passes bit) | key-agreement | KEY-4x4 |
| M3 (ko too broad) | key-agreement (the proper killer; I5 does not kill it at 2×2) | KEY-4x4 |
| M4 (ACCEPT-KOKEY) | key-agreement | KEY-4x4 |
| M8 (deleted entry) | C-A1/C-A2 closure | CLOSURE |
| M9 (battery-stubbed) | battery-health meta-check | BATT-HEALTH |
| M10 (alias-control) | I11 null control (R8 replaced by alias of solver → must report 0 vacuously; the real R8 reading is the non-alias one) | I11 |

**M10 note.** The null control (spec §4.1) *is* the M10 kill: it proves the
I11 harness is sensitive to independence by showing it sees nothing when
the two sides are the same function. The M10 assertion inverts in
`vb_mutants.zig` when I11's null control is wired in. The independent-
reimplementation *check* (that R8 is genuinely not an alias of the kernel)
is enforced structurally by §7 (different author, denied kernel source) and
asserted by the null-control run.

**`build.zig` touches.** Rows that add build steps: MG-INV, MG-KERN, R8,
SMD1, CLOSURE, I4-4x4, I5-4x4, KEY-4x4, I11, BATT-HEALTH. Each declares its
step in its build-log entry; the Orchestrator serializes all `build.zig`
edits (single writer). No two rows edit `build.zig` in the same wave.

---

## 6. R8 authorship independence — assigned structurally (spec §4.3)

The plan assigns the independence discipline **structurally**; exact models
are assigned at dispatch, never in the plan (human's standing rule).

**The R8 row (battery move generator + state-key encoder) is authored by a
different agent/model than the MG-KERN row (kernel move generator).**

| | MG-KERN (kernel) | R8 (battery) |
|---|---|---|
| **author** | agent A (dispatch-assigned) | agent B ≠ A (dispatch-assigned) |
| **given** | AXIOMS.md §2 (A1–A6, B1–B3 prose + claim IDs); the existing `rules.zig` building blocks (`pos_from_move`, `koAfterCapture`, `stateKey`); the solver's `exp6_solve.zig` move logic as the extraction source | AXIOMS.md §2 (A1–A6, B1–B3 prose + claim IDs) **only**; the SMD1 output contract (`design-M1.md` §4.6); the `StateKey` struct *interface* (field names + types), not the implementation |
| **denied** | nothing (it is the extraction) | `src/rules.zig`, `src/exp6_solve.zig`, `src/differential.zig` — the kernel/solver source and the invariant harness |
| **representation** | as extracted | free to choose; same output required |
| **output contract** | `legalMoves(state) → move bitmap`; `stateKey(state) → StateKey` | identical bitmap and key per state |

**Blindness is enforced by scheduling, not by trust.** R8 is in set
`g3b-battery`; MG-KERN is in set `g3b-movegen`. R8 starts in **Wave 1**
(§8), *before* MG-KERN's kernel function exists — R8's author literally
cannot read code that has not been written. The differential invariant
(MG-INV) and the key-agreement run (KEY-4x4) are the comparison harness;
they are written by a third author **C, distinct from both MG-KERN's
author (A) and R8's author (B)**, and compare the two implementations after
both exist (F4 — allowing the kernel author to also write the comparison
harness would weaken the independent-comparison guard the QA-023 rules were
written for). The null control (I11, §4.1) and the
seeded-defect control (§4.2) are the calibration that proves the comparison
is sensitive — a check that passes both the clean artifact and the seeded
mutant is blind, and its reading is not reported (QA-023).

**Independence is the only defect-finding mechanism this project has
evidence for** (DIRECTION §4; the ko bug was found by an independent Python
rewrite). The plan makes it permanent: two authors, blind separation by
scheduling, calibrated comparison.

---

## 7. Third-language ruling — decision: NOT required for pass0

The binding ruling (human, 2026-08-03) asks the plan to decide **only
whether** a third re-implementation language is needed (beyond Zig for the
kernel and the battery, and Python available for ad-hoc probes); if one is
ever adopted, it is Kotlin by standing ruling, escalated to the sprint
owner, never self-approved.

**Decision: no third language is required for pass0.**

Rationale:

- The independence that has found defects in this project is **authorship**
  independence, not language independence per se (DIRECTION §4: "the audit
  that found the ko bug rewrote the algorithm in Python" — the mechanism was
  independent re-implementation; the language was incidental). Spec §4.3
  makes the bar explicit: *different author*, blind to the kernel source,
  same output required — and explicitly **allows** the same language with a
  different representation.
- pass0's core check is the move generator, re-implemented twice in Zig by
  different authors (MG-KERN and R8), compared by the `differential.zig`
  invariant with null and seeded-defect controls. That is two independent
  implementations of the same function — the bar verify-battery pass1 A5
  raised to ("two re-implementations, at least one exercising the move
  relation"). A5 says "ideally different language"; "ideally" is not
  "required," and the g3b spec §4.3 does not raise it.
- The residual risk a same-language pair shares is a **Zig-idiom blind
  spot** (e.g. both mis-handle `@intCast` overflow identically). The guard
  is the calibrated seeded-defect control (QA-023: a positive control must
  exercise the instrument under test, not a parallel one) — the M10
  alias-control and the M2/M3 move-set mutants exercise the *same* code
  paths the real reading uses. With those controls passing, two-author Zig
  is sufficient for pass0.
- Python remains available for ad-hoc differential probes (it is how the ko
  bug was caught) but is not a pass0 deliverable and gets no `needs` edge.

**Escalation trigger (stated, not self-approved):** if a pass0 reading
reveals a defect that both Zig implementations miss but a Python probe
catches — i.e. evidence of a shared Zig blind spot the seeded-defect
controls did not cover — that is the feasibility answer that *requires* a
third implementation. The plan then halts (plan amendment) and escalates to
the sprint owner, who decides whether to invoke Kotlin. The plan does not
pre-commit to Kotlin; it commits only to the halt-and-escalate on that
trigger.

---

## 8. Parallelism

`ROLES.md` §Concurrency is the authority: **max two concurrent DeepSeek
pi-subagents; mutation serial.** Sets serialize within; across sets,
concurrency. The critical path and the waves:

**Critical paths:**
- `MG-INV → MG-KERN → SMD1 → I11` (the I11 chain; SMD1 and I11 are the
  long tail).
- `MG-INV → MG-KERN → CLOSURE` (the closure chain).
- `R8 → {I4-4x4, I5-4x4, KEY-4x4, I11, BATT-HEALTH}` (everything that
  consumes the battery's move generator/encoder).

**Waves** (each wave respects the two-subagent cap and set serialization):

| wave | rows (concurrent within the cap) | gate |
|---|---|---|
| **1** | **MG-INV** (g3b-movegen) ∥ **R8** (g3b-battery) | R8 starts before MG-KERN exists — this *is* the blindness enforcement (§6). Two subagents, two sets. |
| **2** | **MG-KERN** (g3b-movegen, after MG-INV) ∥ **BATT-HEALTH** (g3b-battery, after R8) | one from each of two sets. |
| **3** | **SMD1** (g3b-tools, after MG-KERN) ∥ **CLOSURE** (g3b-battery, after MG-KERN) | CLOSURE and the g3b-battery chain serialize, so at most one g3b-battery row per wave. |
| **4** | **KEY-4x4** (g3b-movegen, after MG-INV + R8) ∥ **I4-4x4** (g3b-battery, after R8) | |
| **5** | **I5-4x4** (g3b-battery, after R8) ∥ **I11** (g3b-battery, after SMD1 + R8) — *serialize within g3b-battery*: I5-4x4 then I11, or across waves | I11 is the long tail; it may occupy the g3b-battery slot for two waves. |
| **6** | **DISCHARGE** (after all check rows) | accept gate. |

**Mutation serial.** Every run that seeds or kills a synthetic mutant (the
differential invariant's seeded-defect control, the I11 null/seeded-defect
controls, the closure/I4/I5/key-agreement calibration mutants) is a
`zig build test` invocation and runs serially — no two mutation runs in the
same wave. This is the `ROLES.md` rule and the precedent that mutation
races corrupt the kill matrix.

**Non-DeepSeek analysis** (document review, design/test/accept audits,
ad-hoc Python probes) is unlimited and may run alongside any wave.

---

## 9. Effort — rough, honest

| phase / row | rough effort | notes |
|---|---|---|
| Plan (this) | 1 session | T331 |
| Scope | 0 (merged) | §12 |
| Design | 1–2 sessions | data structures (closure bitset, SMD1 adoption, R8 representation, KO_SENSITIVE-clear/-set separation), alternatives rejected |
| Test (TDD) | 2 sessions | acceptance tests + known-bad mutants for all six checks, wired into `zig build test` before build |
| MG-INV | 1 session | extend `differential.zig`, null + seeded-defect controls |
| MG-KERN | 1–2 sessions | extract + TDD + differential agreement at 2×2/3×2/3×3 |
| R8 | 2–3 sessions | independent re-implementation; the bulk of the independence work |
| SMD1 | 1 session | dump utility, ~50–100 lines per design-M1 §4.6.5 |
| CLOSURE | 2 sessions | C-A1 + C-A2, 4×4 BFS, calibration at 2×2/3×2 |
| I4-4x4 | 2 sessions | Φ recomputation, KO_SENSITIVE split, 4×4 run |
| I5-4x4 | 2–3 sessions | iterative Tarjan at 4×4 (T134 plan), calibration at 3×2 (max SCC = 1 676) |
| KEY-4x4 | 1 session | exhaustive 4×4 pass; the invariant exists (T267) |
| I11 | 2 sessions | SMD1 reader, null + seeded-defect controls, 4×4 sample |
| BATT-HEALTH | 1 session | M9 meta-check |
| DISCHARGE / Accept | 1–2 sessions | numbers audit, denominators, calibration, accept.md |

**Total: ~12–16 sessions.** The long pole is the g3b-battery chain (R8 →
I4/I5/I11), serialized within the set. The 4×4 I5 Tarjan run (T134's ~1.2 GB
plan) is the single longest wall-clock item and the one most likely to need
the runner's RSS guard.

---

## 10. claimlint invariant

The plan proposes **no claim status changes** (those are the accept row's
job, via its findings file) and registers **no new claim rows** (the
findings dump for this task carries `claims: []`, `new_rows: []` per
`DELEGATEE.md` — a dump is a narrative record, not a proposal; populating
the arrays would double-count in C7). The plan therefore does not move the
claimlint floors: **C1a = 10, C1b = 0, C2 = 14, C6 = 0** (and C9 = 0). The
build rows will propose claim promotions in *their* findings files at
accept time, routed through the standard absorption gate — not here.

---

## 11. Risks and fallbacks

| risk | mitigation | trigger |
|---|---|---|
| 4×4 closure OOM | §2.1 budget is ~531 MB peak (group index 121.6 MB + entry data 396.5 MB resident + visited bitset 12.4 MB); fallback is stream-from-disk (plan amendment) | runner RSS > 3.5 GB |
| 4×4 I5 Tarjan OOM | T134 plan is ~1.2 GB with ~2.8 GB headroom; fallbacks F1 (pack onstack) → F2 (drop dense_to_linear) → F3 (sample) → F4 (≤3×3 only) | runner RSS > 3.5 GB |
| R8 ≡ alias of kernel (shared blind spot) | §6 blindness-by-scheduling + §4.1/§4.2 null & seeded-defect controls; if a Python probe catches what both miss → §7 escalation | a defect both Zig implementations miss |
| I11 4×4 sample misses a systematic disagreement | 50 K stratified sample; exhaustive stretch goal if wall-time permits | a clean 50 K run with budget remaining |
| KO_SENSITIVE-set I4 false positives | spec §2.4: report KO_SENSITIVE-clear and -set counts separately; only the clear count is the verdict | KO_SENSITIVE-set violations > 0 |
| `build.zig` write race | single-writer choke point through the Orchestrator; no two `build.zig` edits in one wave | two rows adding build steps simultaneously |
| A check passes its clean fixture AND its seeded mutant (blind) | QA-023: do not report its 4×4 reading; the check is the defect | any check blind at its calibration rung |

---

## 12. Scope (MoSCoW) — merged from the Scope phase

Spec §8 already bounds scope; this section adds the per-pass MoSCoW the
`sprint.md` Scope phase asks for, so a separate `scope.md` is not needed.

**Must (pass0 delivers):** the six checks (C-A1, C-A2, I4, I11, I5, G1/G3
key-agreement) at the ladder rungs in spec §7; R8; SMD1; the kernel move
generator extraction with its invariant; the seven mutants killed (M1–M4,
M8, M9, M10); null + seeded-defect controls for I11; the accept.md with
denominators.

**Should:** exhaustive I11 at 4×4 (the §3 stretch goal); I5 on both the
reachable-from-empty and all-legal graphs (T134 §3.3's two-run
recommendation — default to all-legal if only one fits).

**Could:** a Python differential probe of the kernel move generator as
defense-in-depth (not a deliverable; available if a shared-blind-spot
suspect arises).

**Won't (this pass — explicit, per spec §8 out-of-scope):** parallel
fixpoint; repairing the KO_SENSITIVE column; the #2 auditor; PSK / k≥2;
real-game PSK values; `CODE.GTP-LHSIDE` repair (T283, separate row); the v1
DTT column; cross-size inheritance; dihedral symmetry beyond I2; a third
implementation language (§7 — only on the stated escalation trigger, and
then Kotlin by owner ruling, not self-approved).

---

## 13. Open items and escalation triggers

- **No §6 question is left open.** Every one has a decision above; none is
  "deferred to build." The two fallbacks that *could* change the build
  (closure stream-from-disk; I5 sample-only) have stated triggers and are
  plan amendments, not silent switches.
- **Spec-amendment halt triggers** (the plan halts, not diverges): (a) the
  §7 third-language escalation; (b) a §2.1/§2.6 memory or feasibility
  finding that contradicts the budget (e.g. the WZO2 group index is not
  sorted by colex as design-M1 §2.4 guarantees, breaking binary-search
  membership — then CLOSURE needs a hash set keyed on `colex`, ~1.2 GB,
  still feasible but a design change); (c) a check
  whose pass condition the build finds unsatisfiable on the input (T287
  precedent — a wrong pass condition is itself a defect).
- **What this plan could not establish:** the exact 4×4 wall time for I5's
  Tarjan (T134 estimated ~minutes for BFS, Tarjan is heavier); the exact
  reachable-from-empty vs all-legal graph sizes at 4×4 (T134 §3.3 flags the
  5:1 ratio at 3×2 as a hint, not a measurement). Both are build-row
  measurements, recorded with denominators in `accept.md`.

---

## 14. Amendment log

| date | amendment | by |
|---|---|---|
| 2026-08-03 | Initial plan — T331 | glm-5.2:cloud/T331 |
| 2026-08-04 | Rev 2 (T333): fix the six dispositioned plan-audit findings (T332 F1–F5 + gate-holder F6). **F1** — §2.1/§2.6 re-rooted to the real WZO2 artifact (`untracked/oracle-v2/oracle-4x4-v2.wzo2`, 518,123,097 B, SHA-256 `0c3366f0…`); membership predicate rebuilt as group-index binary search + in-group linear scan over the parsed schema (`n_groups=24,318,165`, `n_entries=99,133,036`, entry_size=4, ko_bits=5, PASSES_2_OMITTED, passes≥1⇒ko=none, KO_SENSITIVE=L≠H); memory budget re-derived (~531 MB peak, ~3.47 GB headroom); passes=2 children are expected-absent terminals, not missing. **F2** — I5 first seeded-defect control mechanized as an I5-4x4 row bar at 3×2, red-then-green before the 4×4 reading. **F3** — DISCHARGE bar restated as the seven mutant-kill assertions inverted in `vb_mutants.zig`; `needs` edges stay row-level. **F4** — comparison-harness author required distinct from both MG-KERN (A) and R8 (B); “(or A)” dropped. **F5** — T134 EXP-3 sweep citation relabelled an analogy; actual closure sweep count deferred to an accept.md measurement. **F6** — MG-INV commits to exhaustive `(pos, side, ko, passes)` comparison including `ko≠NONE`, with a ko-recapture mutant caught at a ko-active state. Header and §4 updated to spec Rev 3. | glm-5.2:cloud/T333 |
| 2026-08-04 | Rev 3 (gate-holder, not the builder): **path repoint only.** §2.1's artifact becomes `data/oracle-4x4-v2.wzo2` — the deployed copy of the same build T333 parsed, byte-identical, SHA `0c3366f0…`, both paths listed in `artifacts/SHA256SUMS` — per spec Rev 4 (human ruling: a ratified spec must not make `untracked/` load-bearing). Header figures re-verified against the deployed copy before the edit (`shasum -c` 12/12 OK; engine load reports 24,318,165 groups / 99,133,036 entries, 0 misses, 0 fallbacks). Spec references bumped Rev 3 → Rev 4 in the header, §1, and the §7 gate table. **No number, decision, check, wave, row, edge or F1–F6 fix was touched** — the round-2 audit judges the builder's Rev 2 content. | claude-opus-5 (Orcha) |
| 2026-08-04 | Rev 4 (gate-holder, on T334 round-2 audit — PASS-WITH-EDITS): **N1 (must)** — §4's "Spec is done (Rev 3, RATIFIED)" corrected to Rev 4. This was a regression the Rev 3 repoint introduced: the §7 gate table was bumped and this prose was missed, so the auditor caught the gate-holder's own error. **N2 (should, substance confirmed, citation corrected)** — `KEY-4x4` no longer co-declares `holds=src/differential.zig`; MG-INV stays the sole declared holder per `spec.md:278`, and KEY-4x4 writes the file under that ownership, serialized by `needs MG-INV` inside set `g3b-movegen`. The auditor cited `spec.md:248`, which is a blank line; the file-ownership assignment is at `:278`. The suggested alternative — a separate `src/vb_keyagree_4x4.zig` — is **rejected**: spec §6.4's decision was to reuse `differential.zig`, and splitting one harness across two files to satisfy bookkeeping is a worse outcome than declaring ownership correctly. **Status → RATIFIED**; build-row decomposition follows. | claude-opus-5 (Orcha) |
| 2026-08-04 | Rev 5 (gate-holder): **the N2 open question, measured instead of assumed.** Rev 4 removed KEY-4x4's `holds` and left "whether `managent`'s hold conflict fires against any row or only a live one" to be tested at registration. Tested: `holdsConflict` (`src/managent/main.zig:976-991`) skips every row whose `status != .in_progress`, and it is called from `claim` (`:1268`, `:1315`), never from `add`. So two registered rows may both declare a file and the refusal fires only while one is actually in progress — which is precisely the one-writer-at-a-time rule. KEY-4x4's `holds=src/differential.zig` is therefore **restored**: declaring it mechanizes the rule, and Rev 4's no-hold version would have enforced nothing. Rev 4's reading of `spec.md:278` stands ("one owner" = one at a time); no spec amendment needed. | claude-opus-5 (Orcha) |
