# Waypoint 3 — A–Z reverification: the decomposition

```
Status:  PROPOSAL — awaiting operator ratification. Registers nothing.
Task:    T749 (Race I synthesis) · claude-opus-5 · 2026-08-23 · at HEAD 2ec4f93
Sources: five independent lanes on untracked/race-i-waypoint3-brief.md —
         findings/T740-waypoint3-spec.md (claude-opus-5)   · 17 rows, 4 waves
         findings/T741-waypoint3-spec.md (claude-sonnet-5)  · 12 rows, measure/write split
         findings/T742-waypoint3-spec.md (deepseek-v4-pro)  ·  9 rows, gate-first
         findings/T743-waypoint3-spec.md (deepseek-v4-flash)· 16 rows, family-major
         findings/T744-waypoint3-spec.md (oxalpha)         · 13 rows, size-major
Trunk:   T740 (structure, measured baseline, shard design, gate-with-own-controls).
         Grafts credited per row in §8. Every graft names its lane; the model
         comparison in findings/T749-race-i-synthesis.json depends on it.
```

**Landmark:** advances **L2 (proven 4×4 values)** — Waypoint 3 is L2's critical path. The
five lanes turned "not decomposed" into five candidate row sets; this document is the one
row set, with the lanes' four substantive disagreements presented rather than silently
resolved (§6). What remains before execution: the operator's ratification of §6 and §7.

**Waypoint 3, as ratified** (DIRECTION.md:123, canonical text after T757's rename):

> Ladder 2×2 → 3×2 → 3×3 (anchor reconciled honestly) → 4×4. Kernel vs fixtures
> differentially at every rung; every register row re-derived, demoted, or retired against
> the requirement tree.

**What "re-verified" means, mechanically** (T744's definition, adopted verbatim for every row
below): a register row is re-verified when a *machine check that can fail* — a battery
invariant, a differential, a closure check, a key-agreement invariant, or a census with a
full denominator — is run at HEAD against the kernel-as-oracle (Waypoint-2 `rules.zig`
`koAfterCapture`/`stateKey` as production, every legacy copy a frozen fixture), and the row
carries a disposition citing that run. **A prose re-reading is not a re-verification.**
"Every row" includes the falsifications and the MEASUREMENT rows — the negative half of Z is
as load-bearing as the positive half (AXIOMS §3.7 Z-NONCLAIMS).

---

## 0. The measured starting state

Re-measured at HEAD `2ec4f93` for this synthesis (the lanes ran at `3ce328e`). Every number
is printed by the command beside it; a number without its command is not a measurement
(register-tree-map §3.1).

`bin/weizigo-claimlint`:

| quantity | value | where |
|---|---|---|
| register rows | **231** | C0 `rows parsed: 231` |
| mapped to a tree node / proposed-retired | 228 / 3 | C9 (row-set equality, passes) |
| PROVEN / CLAIMED | 66 / 59 | status census, command below |
| MEASUREMENT / UNTESTED | 51 / 21 | same |
| FALSE-AS-SCOPED / FALSE | 22 / 7 | same |
| SUPERSEDED / INTRACTABLE / definition | 3 / 1 / 1 | same |
| **believed rows (PROVEN + CLAIMED)** | **125** | same — the re-derivation work list |
| **PROVEN with no committed evidence** | **46** | C3 UNBACKED (floor 48, so 2 below floor) |
| dead evidence links | 13 | C2 (= the floor; never rises) |
| claim IDs cited in docs with no row | 49 (+2 unreferenced rows) | C4 |
| shadowed dependency | 1 | C5 |
| kernel-function claims in the kill matrix | 3, **all 3 with an unkilled mutant** | C8 — see §1.1 |
| C8 violations (unkilled **at PROVEN**) | **0 — vacuously** | C8, `src/claimlint.zig:2982` |
| evidence citations outside the tree | 1237 (1030+ into gitignored `untracked/`) | C10 |
| dead / ambiguous glob citations | 5 / 5 | C12 |
| calibration | PASS (15 known-good, 18 known-bad arms) | claimlint self-test |

Status and node census (the 231st row, `CODE.ADR0011-FMT`, carries escaped pipes; a naive
11-cell split silently drops it — which is why the command is printed):

```sh
python3 - <<'EOF'
import collections
rows=[l for l in open('docs/epistemic/CLAIMS.md') if l.startswith('| `')]
def cells(l): return [x.strip() for x in l.replace('\\|','\x00').split('|')[1:-1]]
def norm(s):
    for k in ('FALSE-AS-SCOPED','SUPERSEDED','INTRACTABLE','MEASUREMENT',
              'UNTESTED','CLAIMED','PROVEN','FALSE'):
        if s.startswith(k): return k
    return 'OTHER'
c=[x for x in map(cells,rows) if len(x)==11]
print(len(c), collections.Counter(norm(x[4]) for x in c).most_common())
believed=collections.Counter(x[10] for x in c if norm(x[4]) in ('PROVEN','CLAIMED'))
allrows=collections.Counter(x[10] for x in c)
for k,v in allrows.most_common(): print(f'{k:24s} all={v:3d} believed={believed.get(k,0):3d}')
EOF
```

**Rows per tree node** (independently reproduced; T740's *believed* column and T743's *all*
column both match this census exactly — both lanes counted honestly):

| node | all | believed | node | all | believed |
|---|---|---|---|---|---|
| Z-NONCLAIMS | 43 | 12 | Z-COMPLETE-ENUM | 5 | 2 |
| Z-TABLE-FAITHFUL | 33 | 18 | Z-R-STATE | 4 | 4 |
| Z-AUDIT | 24 | 16 | Z-STATE-KEY | 4 | 3 |
| Z-R-SCORE | 17 | 10 | Z-CONVERGE-MONO | 3 | 2 |
| Z-CONVERGE-FIX | 15 | 10 | Z | 3 | 2 |
| Z-TABLE | 15 | 3 | RETIRED | 3 | 0 |
| Z-R-MOVE | 14 | 13 | Z-CONVERGE | 2 | 2 |
| Z-R-TIE | 12 | 3 | Z-CONVERGE-SEED | 1 | 0 |
| Z-TABLE-CONSISTENCY | 10 | 8 | Z-SYM / Z-R-SIGN | 1 / 1 | 1 / 1 |
| Z-CONVERGE-FINITE | 7 | 2 | Z-COMPLETE-PASSES | 1 | 1 |
| Z-STATE-LEGAL / Z-STATE-REACH | 6 / 6 | 6 / 5 | Z-TABLE-ROUNDTRIP | 1 | 1 |

**Rows per goban scope** (`ls`-free census, same command shape): `all` 96 · 4×4 54 · 3×3 18 ·
`n/a` 15 · **4×3 14** · 2×2 9 · 3×2 9 · 13 multi-size scopes covering 16 more. The 4×3 count
is load-bearing — see §6.4.

**Rung × artifact coverage** (`ls artifacts/ data/`, `git ls-files`, `.gitignore:4`):

| rung | WZO1 | WZO2 | differentially runnable? |
|---|---|---|---|
| 2×2 | `artifacts/oracle-2x2.wzo` (tracked) | **absent** | **no** |
| 3×2 | `artifacts/oracle-3x2.wzo` (tracked) | **absent** | **no** |
| 3×3 | `artifacts/oracle-3x3.wzo` (tracked) | `data/oracle-3x3-v2.wzo2` 261 KB, **gitignored** | yes |
| 4×3 | `artifacts/oracle-4x3.wzo` 3.19 MB (tracked) | **absent** | **no** |
| 4×4 | `data/oracle-4x4-*.wzo` (gitignored) | `data/oracle-4x4-v2.wzo2` 518 MB, gitignored | yes |

`.gitignore:4` ignores `data/`. **Three of five rungs have no WZO2 artifact at all**, so
"kernel vs fixtures differentially at every rung" is presently unrunnable below 3×3. The
hash-in-`artifacts/SHA256SUMS` mechanism is the right answer for 518 MB and is already in
place; it is the wrong answer for a 261 KB file.

**Two rulings fix the object of reverification and must not be re-litigated** (T742's §0 —
the single most valuable correction any lane made, because it deletes two large rows other
lanes proposed):

1. **G3b is discharged** (`accept.md`, signed 2026-08-05): `4x4.C1` and `4x4.FP1` are at
   CLAIMED with scope limits. **Nothing at 4×4 is PROVEN; CLAIMED is the ceiling pending
   Waypoint 3.** `4x4.C1`'s own text says so.
2. **Track A is discharged by provenance** (T472, 2026-08-19): the 3,455,412-entry
   KO_SENSITIVE column of `data/oracle-4x4-v2.wzo2` is the ADR-0020 pure loopy-game fixpoint
   bracket, never the finisher's output — `retro.zig` writes only `.wzo`, never `.wzo2`, so
   "Track A regen" is a **category error against this artifact**. The writes-on checkpoint
   `data/oracle-4x4.checkpoint.wzo` keeps its taint, and the **#2 auditor on the k=1 build is
   still owed** (`PROGRESS.md:446`, `4x4.D3` UNTESTED).

Consequently Waypoint 3's honest target is **not** "promote everything to PROVEN". It is:
every live register row reaches a disposition backed by a controlled instrument at the rungs
its scope names, nothing is left TODO, and the promotions that Amendment-2 edge 5 licenses
are taken while the ones it does not are honestly refused.

---

## 1. Corrections to the lane inputs

The lanes ran at `3ce328e`; sixteen commits landed before this synthesis. Four corrections
change the row set, and are recorded here so no row inherits a stale premise.

### 1.1 The mutation gate is worse than any lane said: C8 is a vacuous gate

Three figures for one quantity, all live at HEAD:

- `kill-matrix.json` — the **only** file C8 reads (`src/claimlint.zig`, `KILL_MATRIX_PATH`) —
  says `"total_mutants": 10, "mutants_killed": 3`.
- `mutants.md:64` says `**Kill rate: 10 / 10**`; its amendment log `:321` credits T530
  (2026-08-20) with per-mutant red-then-green fixtures for M1/M2/M4 and inverting M3.
- The brief's (and T475's) figure is **6/10**.

All ten fixtures do exist in `src/vb_mutants.zig` (M1 `:171`, M2 `:206`, M3 `:254`,
M4 `:303`, M5 `:349`, M6 `:379`, M7 `:407`, M9 `:445`, M8 `:486`, M10 `:536`).

**The new finding — and the reason this row must go first.** T740 read C8's detail lines and
reported "3"; T741 read C8's summary line and reported "0", concluding the gate is satisfied.
Both readings are literally correct, and the gap between them *is the defect*:

```
  kernel-function claims in kill matrix: 3
  with at least one unkilled mutant:    3
  at PROVEN (violation):                0
```

C8 counts a violation **only for claims at PROVEN** (`src/claimlint.zig:2982`, and its own
calibration arm 9b asserts the CLAIMED silence deliberately). Every kernel claim is held at
CLAIMED by edge 5. So **C8 reads 0 today because Waypoint 3 has not run, not because the
mutants are killed** — it is a gate that is vacuous precisely until the moment Waypoint 3
tries to promote something, at which point it will fire on a matrix three lanes already know
is stale. A reader who trusts the summary line concludes the promotion currency is in hand.
It is not. This is the `CODE.BATTERY-STUBBED` shape (a check that passes because it does not
run) reappearing in the meta-layer.

### 1.2 I11 at 4×4 is already exhaustive — and the register contradicts itself about it

T744 proposed **W3-10 "Exhaustive I11 at 4×4" (size L)**, on the reading that I11 is a
50,000-of-99,133,036 sample (0.05%). That work is **already done**: T473 ran it exhaustively —
`0 / 48,636,330` SMD1 slice records and `0 / 99,133,036` stored table entries, 69.5 s wall,
558 MB RSS, evidence at `docs/evidence/I11-4x4-EXHAUSTIVE/PROVENANCE.md`.

T744 did not fabricate: it read a sentence that is still in the register. `4x4.C1`
(`CLAIMS.md:328`) records the rescission — *"I11 at 4×4 is exhaustive (T473) … the 0/50,000
sample scope limit is rescinded"* — but `4x4.FP1` (`:304`) and `GLOBAL.H4` (`:471`) **both
still carry the stale limit verbatim**: *"I11 at 4×4 is a 50,000-state sample of 99,133,036
(0.05%)"*. A rescission absorbed into one row and not its two siblings is exactly the drift
C7 exists to catch, and it cost a lane a whole proposed row. It becomes **W3-05** below.

### 1.3 Two lanes' largest rows are obviated by T472

- **T743's W3-10** ("Writes-off 4×4 regen + #2 auditor", 5–10 worker-days, compute-bound) is
  the largest single row any lane proposed. Its regen half is a category error against the
  WZO2 artifact per §0 ruling 2. Its **#2-auditor half stands** and is folded into W3-15.
- **T744's W3-11** ("KO_SENSITIVE Track A evidence bundle") assembles evidence for a ruling
  T472 already made. Dropped; its residue (which checkpoint values stay untrusted) is a cell
  in W3-15's disposition, not a row.

### 1.4 The naming question is settled by events; the artifact-inventory question is not

- **Settled.** T741, T743 and T744 each flagged "Waypoint vs Phase" as OPEN, and T744
  correctly reported that at `3ce328e` no ratified rename text existed. T757's Race W landed
  between their HEAD and this one (`b0deab1`…`4cc4255`): `docs/epics/E1-markovian/PHASES.md`
  is now `WAYPOINTS.md`, and DIRECTION.md:123 says **Waypoint 3**. Every lane's citation of
  `PHASES.md` was valid when written. This document uses **Waypoint** throughout.
- **Not settled, and a real defect in one lane's row set.** T741's rows 5–9 assert that
  `vb_closure.zig` needs "no new code" to run below 3×3 because it reads `w,h` from the
  artifact header. The *reader* is indeed parametric (`src/vb_closure.zig:81-82` — verified).
  But there is **no WZO2 artifact below 3×3** (§0), and the *writer* is hardcoded:
  `src/oracle_v2_build.zig:543` formats `"…/oracle-4x4-v2.wzo2"`. So the artifact rows are a
  hard predecessor, and they hold `src/oracle_v2_build.zig` — which corrects T742's W3-3,
  which claimed "no `src/` ownership (runs `oracle_v2_build.zig`)". T740's OPEN-5 called this
  exactly right.

### 1.5 The phantom `--bundle` row is a mangled duplicate of T433, not a missing audit

All five lanes found it, and all five read it correctly as a phantom. The stronger reading:
the row's `bundle` field is `untracked/T430-phase2-audit.md` — **byte-identical to T433's own
bundle field**, and T433 is `done`. Only `untracked/T430-doctor-console-permanently-green.md`
and `untracked/T433-phase2-audit.md` exist on disk. So this is not a lost audit; it is a
**duplicate registration whose task id is the literal string `--bundle`** — a flag-parsing
failure at `managent add`, the same defect family as T760 (`--needs` comma split) and the
queued T775 (strict flag parsing). T747 independently flagged it as needing "retire/purge".
It is kanban hygiene, outside Waypoint 3 (§6.5), and it should be closed *by* T775's fix
landing rather than repaired by hand.

### 1.6 T531's hold set collides with four lanes' row sets — only T743 caught it

`T531` is **`in_progress`** (stalled since before 2026-08-20) and declares holds on:

```
src/rules.zig  src/differential.zig  src/vb_closure.zig  src/vb_i11.zig  src/vb_graph.zig
src/vb_fixpoint.zig  src/vb_health.zig  src/verify_battery.zig  src/vb_scc_4x4.zig
src/vb_bellman_4x4.zig  src/i5_differential.zig  src/i4_differential.zig
src/keybyte_differential.zig  src/colex.zig  src/evidence.zig  src/evidence_control.zig
build.zig  tools/regression-suite-surfaces.sh  tools/suite-truth.sh
docs/infra/suite-truth-manifest.md
```

That is most of the battery and **`build.zig`**. "Conflict-free holds" is a claim about the
live hold set, not about the proposal, so it must be checked against T531:

- T741's rows 3–4 hold `differential.zig` — **collide**.
- T742's W3-1 and T744's W3-03 both wire a new step into `build.zig` — **collide**.
- T740's W3-17 holds `build.zig` — **collide**.
- T743 (OPEN 9) anticipated this and routed its new instruments to fresh `src/w3_*.zig` files
  specifically to avoid the set. **That is the right pattern and it is adopted below.**

Every row in §2 that would touch a T531-held file either takes a new file or declares the
collision explicitly. **No W3 row may be dispatched while T531's hold is live on a file it
needs**; W3-00 (new) settles T531 first.

---

## 2. The row set

**Nineteen rows, four waves.** IDs are proposal IDs (`W3-nn`); the seat mints real task IDs at
registration. Titles are ≤ 40 characters. No row needs a human mid-flight: the two rows that
feed operator rulings (W3-05, W3-18) **complete when the evidence bundle is delivered**, and
the ruling is queued behind the bundle, not blocking it.

**Where dispositions live.** Not in `CLAIMS.md`. Waypoint-3's per-row dispositions live in a
**shard directory**, `docs/epics/E1-markovian/wp3/<node>.md`, one shard per tree node
(T740's design; T741's argument for it). Reason: `CLAIMS.md` is the most contended file in the
repo — every absorption writes it — so a 12th column would serialize every Waypoint-3 row
behind every unrelated absorption, and a single ledger file would serialize the batch rows
against each other. Sharding by node makes the batch rows **conflict-free by construction**.
A new claimlint check, **C15**, recovers the anti-subset property T305 got from putting the
`tree` column *inside* the register: the union of shards must equal the register row set
exactly, no duplicates, no extras, no missing. **This diverges from the T305 precedent and is
the one structural choice the operator should rule on before W3-01 is dispatched** (§7,
OPEN-1). `C15` is the next free check ID (`src/claimlint.zig` runs C1–C14 — verified).

**Disposition vocabulary** — one cell per register row, per DIRECTION's "re-derived, demoted,
or retired":

| cell | meaning |
|---|---|
| `RD:<instrument>@<rung>` | re-derived — the assertion re-established at HEAD by a named instrument at a named rung, evidence committed under `docs/evidence/` |
| `DM:<from>-><to>` | demoted — the row cannot carry its status; the new status and the reason |
| `RT?` | retirement **proposed** (retirement is the operator's ruling, DIRECTION §1) |
| `RT` | retired — ruled, row moved to `archives/register/` (T373 precedent: archive, never delete) |
| `NA:<reason>` | live but outside Z's scope, or honestly still untested — **the reason is mandatory and is the content** |
| `TODO` | not yet dispositioned; the finish gate requires zero |

**Register writes.** No W3 row holds `docs/epistemic/CLAIMS.md`. Rows propose status changes
in `findings/<taskid>-<slug>.json` per `findings/README.md`; STANDING-ABSORB is the single
writer. Tier-A changes (→ PROVEN, → FALSE/FALSE-AS-SCOPED, new or retired rows) carry
`audited_by` per the C11 D2 ruling. (T743's convention, adopted; it is what lets Wave 2 run
seven rows concurrently.)

---

### Wave 0 — settle the ground, build the surfaces (no claim's status changes)

#### W3-00 · `wp3-hold-release` · "Settle T531's hold set" · XS

- **Why first.** §1.6. `T531` is `in_progress` and holds most of the battery plus `build.zig`.
  Every later row's "conflict-free holds" claim is false until this is settled.
- **Deliverables.** A hold-status determination for T531 (resume, re-scope to the files it is
  actually mutating, or release), recorded in the store; `bin/managent` reflects it. If T531
  stays live, the deliverable is instead a written hold-avoidance map naming, per W3 row, which
  new file it takes.
- **Holds.** none (store only). **Needs.** — (operator input on T531's fate may be required;
  the row completes by delivering the determination request if so).
- **Acceptance.** No row in this document names a file T531 holds without an explicit,
  recorded collision note. `bin/managent orient` no longer shows T531 as `[stalled]` with an
  unbounded hold set.
- **Provenance.** T743 OPEN-9 (the only lane to see it); scoped into a row here.

#### W3-01 · `wp3-shards-and-c15` · "Waypoint-3 shards + claimlint C15" · M

- **Deliverables.** `docs/epics/E1-markovian/wp3/` (one shard per tree node, every cell
  `TODO`); `src/claimlint.zig` (C15); `findings/<id>-wp3-shards.json`.
- **Holds.** `src/claimlint.zig`, `docs/epics/E1-markovian/wp3/`. **Needs.** W3-00.
- **Acceptance.**
  1. C15 prints, in C9's shape: `register rows: N · shard rows: N · TODO: n · invalid: 0 ·
     duplicate: 0 · missing: 0 · extra: 0`.
  2. **Report-only at birth** (no floor entry) — 231 `TODO` cells must not break the
     pre-commit hook on the day the surface is created.
  3. Cell grammar enforced: `RD:`/`DM:`/`RT?`/`RT`/`NA:`/`TODO`; anything else is `invalid`.
  4. **Null control:** an all-`TODO` shard set → `TODO: 231`, `invalid: 0`, exit 0. *A C15
     that cannot distinguish "nothing done" from "all done" is not a gate.*
  5. **Seeded-defect controls, three, red-then-green, committed beside C9's:** (a) delete one
     shard row → `missing: 1`; (b) add a row for a claim ID with no register row → `extra: 1`;
     (c) blank one cell → `invalid: 1`.
  6. `zig build test` green; floor unchanged (C1a=0 C1b=0 C2=13 C3=48 C6=0 C9=0).
- **Worked example.** *Generate the skeleton, do not type it:*
  `bin/weizigo-claimlint --emit-wp3-skeleton docs/epics/E1-markovian/wp3/` then
  `bin/weizigo-claimlint | grep C15` must print `missing: 0 · extra: 0` on the **first** run.
  A hand-typed 231-row skeleton is a C15 failure shipped as a deliverable.
- **Provenance.** T740 W3-01 (verbatim structure); T741 row 1's inventory folded in as C15's
  own output rather than a separate document.

#### W3-02 · `wp3-killmatrix-recon` · "Reconcile the mutation kill matrix" · S

- **Why early.** §1.1. Amendment-2 edge 5 makes the kill rate the promotion currency, and the
  currency has three values, one of which is read by a gate that is currently vacuous.
- **Deliverables.** (a) Independent re-run at HEAD of the four T530 kill-verification fixtures
  (M1 colex-vs-rank, M2 passes bit, M3 ko-too-broad, M4 ACCEPT-KOKEY), red-then-green observed
  **live, per fixture**, with the run command recorded. (b) `kill-matrix.json` regenerated so
  one file's verdict per mutant matches `mutants.md`; an amendment-log entry (never a rewrite
  of history). (c) **C8 promoted from report-only to failing, and made non-vacuous**: it must
  report the stale-matrix condition whether or not any claim is at PROVEN — a gate that only
  speaks after the promotion it was meant to guard is not a gate. (d) `claimlint-floor.json`
  gains `C8: 0`. (e) findings JSON stating the kill rate as `killed/10` with the fixture run
  as evidence, and the resulting count of closed promotion gates.
- **Holds.** `kill-matrix.json`, `mutants.md`, `src/claimlint.zig` (chain after W3-01 — one
  writer per file), `tools/hooks/claimlint-floor.json`.
- **Needs.** W3-01 (`src/claimlint.zig`).
- **Acceptance.** **Either verdict is a pass; silence is not** (T744's framing).
  1. Per-mutant verdict taken **from the run, not from prose**:
     `zig build test 2>&1 | grep -E '^(ok|FAIL).*M(10|[1-9])-'` — the count of green
     kill-verification tests is what `mutants_killed` may say, and the command goes in the
     findings file.
  2. Each of the ten catalogue mutants carries a per-mutant red-then-green fixture **or** an
     explicit SURVIVES-with-gap record naming the promotion gate it closes. A survivor is a
     recorded closed gate, not a failure of this row.
  3. **Null control:** restore the pre-row `kill-matrix.json` → C8 reports the stale count.
     Proves C8 reads the file.
  4. **Seeded-defect control:** mark one killed mutant `survived` while its claim is at PROVEN
     → C8 reports a violation and exits non-zero; restore.
  5. **Do not write 10/10 because `mutants.md` says 10/10** — that is the exact error T475
     caught in T363's "seven of seven". If a fixture does not go red-then-green on re-run, the
     honest lower number is the deliverable and the verdict is `pass-with-findings`.
- **Consequence to record, not to edit silently.** DIRECTION Amendment 2's "T291's 3/10 kill
  rate … means **seven promotion gates are known-closed**" (`DIRECTION.md:270-271`) is a
  *reading of the 3/10 figure*. At any other rate that sentence is stale. Per DIRECTION §3 an
  amendment change is a **dated event**: this row appends a dated note and registers a row; it
  does not rewrite the sentence.
- **Provenance.** T740 W3-02 (structure, controls, the anti-prose rule); T744 W3-01 (the
  three-way contradiction stated first, and "either verdict is a pass"); T743 W3-01 (the
  named list of CLAIMED rows this unblocks); the C8-vacuity finding is T749's.

#### W3-03 · `wp3-rung-artifacts` · "WZO2 artifacts at 2×2, 3×2, 4×3" · M

- **Why.** §0 / §1.4. Without these, "kernel vs fixtures differentially at every rung" is
  unrunnable at three of five rungs.
- **Deliverables.** `artifacts/oracle-2x2-v2.wzo2`, `artifacts/oracle-3x2-v2.wzo2`,
  `artifacts/oracle-4x3-v2.wzo2` — **tracked**, under `artifacts/`, not gitignored `data/`;
  the writer generalisation in `src/oracle_v2_build.zig` (its output path is hardcoded to
  `oracle-4x4-v2.wzo2` at `:543`); `artifacts/SHA256SUMS` updated;
  `docs/evidence/WP3-RUNGS/build-provenance-2026-08-nn.md`.
- **Holds.** `src/oracle_v2_build.zig`, `artifacts/SHA256SUMS`. **Needs.** W3-00.
- **Acceptance.**
  1. Byte-identical rebuild from a named commit (the `CODE.WZO2-BUILD-REPRO` discipline); both
     hashes printed.
  2. Header `w`/`h` read back correct **at 3×2 and 4×3** — the transposition control the g3b
     spec §7 names ("on a square board width and height are interchangeable"). A run that only
     covers squares has not tested this.
  3. WZO1 ↔ WZO2 value agreement per rung reported as `agreed/total` with `total` stated.
     "Matches" is not a reading.
  4. **Null control:** run the builder twice → identical bytes.
  5. **Seeded-defect control:** flip one value in a scratch copy → the WZO1↔WZO2 differential
     reports ≥ 1 disagreement; discard the copy. *A differential that passes a corrupted copy
     is blind.*
  6. `shasum -a 256 -c artifacts/SHA256SUMS` verifies clean for every line whose path exists.
- **Worked example.** At 3×3 the mechanism already works and is the model:
  `shasum -a 256 data/oracle-3x3-v2.wzo2` reproduces its `SHA256SUMS` line (`d79c17cd…`)
  exactly. Do that for the three new rungs, **with the files tracked**.
- **OPEN.** Whether `oracle-4x3-v2.wzo2` is small enough to track (the WZO1 4×3 is 3.19 MB and
  is tracked, so probably; unmeasured). Whether the 4×3 fixpoint build fits the runner's 4 GB
  RSS cap — if not, 4×3 reverification stays on the WZO1 oracle with its documented format
  boundary, **recorded, not silent** (T742's OPEN-3).
- **Provenance.** T740 W3-03 (+ its OPEN-2/OPEN-5, both now folded in as scope); T742 W3-3
  (the anchor-value and no-silent-overwrite acceptance conditions).

#### W3-04 · `wp3-coverage-matrix` · "Generated instrument × rung matrix" · M

- **Why.** Coverage is uneven and `docs/infra/instrument-coverage.md` (T388) is
  hand-maintained. One cell is known wrong by scope and a hand map cannot carry it: T474's N1
  records the 4×4 I5 instrument as **placement-only** — `checkI5Wzo2`'s pass-edge path is dead
  (SMD1 sentinel), E = 565,402,416 placement-only against ~616M with pass edges — so its E is
  not cross-comparable with 3×2/4×3, though the `0 / 3,455,412` containment reading stands
  (placement-only CR is a subset of full-graph CR, so a false PASS is impossible).
- **Deliverables.** `tools/wp3-coverage` (generator); `docs/epics/E1-markovian/wp3-coverage.md`
  (**generated, never hand-edited**); findings JSON.
- **Holds.** `tools/wp3-coverage`, `docs/epics/E1-markovian/wp3-coverage.md`. **Needs.** W3-03.
- **Acceptance.**
  1. Every cell is exactly one of `exhaustive(<denominator>)`, `sampled(<n>/<N>)`, `not-run`,
     `blind(<reason>)`. **A cell claiming `exhaustive` with no denominator fails the generator.**
  2. Generated from run records; regenerating at HEAD twice is byte-identical.
  3. **Null control:** an empty run-record set → every cell `not-run`. No cell may default to
     `exhaustive`.
  4. **Seeded-defect control:** hand-edit one cell to a bare `exhaustive` → the generator exits
     non-zero, naming the cell.
  5. The I5 4×4 cell reads `blind(pass-edge path dead, T474 N1)` for E and
     `exhaustive(3,455,412)` for containment — **two metrics, two cells, because they have
     different validity.**
- **Worked example.** `tools/wp3-coverage --check` exits 0 on HEAD's generated file and
  non-zero after `sed -i '' 's/exhaustive(3,455,412)/exhaustive/' docs/…/wp3-coverage.md`.
- **Provenance.** T740 W3-04 verbatim.

#### W3-05 · `wp3-stale-scope-sweep` · "Sweep stale scope limits + prose drift" · S

- **Why.** §1.2. A rescission absorbed into one row and not its siblings cost a lane an entire
  proposed row. This is cheap and it de-risks every Wave-2 batch that would otherwise inherit
  the same stale sentence.
- **Deliverables.** (a) `4x4.FP1` (`CLAIMS.md:304`) and `GLOBAL.H4` (`:471`) lose the
  rescinded "I11 at 4×4 is a 50,000-state sample" limit, cited to T473
  (`docs/evidence/I11-4x4-EXHAUSTIVE/PROVENANCE.md`) — via a findings file, absorbed, never a
  direct edit. (b) `register-tree-map.md:483-484` — "register rows **228**" and "mapping rows
  **228**" — repointed to the live C0/C9 print (231), or better, made a *reference to the
  command* rather than a transcribed constant. (c) A census of every other rescinded scope
  limit still quoted in a sibling row: grep the four G3b limits and the T472/T473 rescissions
  across the register and report the count. (d) findings JSON.
- **Holds.** none (`register-tree-map.md` prose lines only; register via absorption).
- **Needs.** W3-01. **Needed by.** every Wave-2 row (they must not re-inherit these).
- **Acceptance.** Zero occurrences of a rescinded limit in a live row; the tree-map's row
  count and claimlint C0 agree or the doc cites the command instead of a number; the census's
  denominator is stated (how many rows were checked, not just how many were wrong).
- **Control.** **Seeded:** re-insert one rescinded limit into a scratch copy of the register →
  the row's own grep must find it. A sweep that cannot find a planted instance did not sweep.
- **Provenance.** T749 (found while adjudicating T744's W3-10); T743 item 6 and T744 OPEN-4
  both independently found the 228-vs-231 prose drift.

---

### Wave 1 — the cheap and the negative (parallel; each holds only its own shards)

#### W3-06 · `wp3-nonclaims` · "Re-verify the 29 negative rows" · L

- **Covers.** 22 FALSE-AS-SCOPED + 7 FALSE. DIRECTION §1: "all 282 rows, **proofs and
  falsifications alike**". The Z-NONCLAIMS node holds 43 rows of which 12 are believed; the
  negative rows spread across seven shards. Row IDs, per T743's enumeration: `GLOBAL.C2`,
  `GLOBAL.C3`, `GLOBAL.C4`, `GLOBAL.FP2`/`-bounded`/`-general`, `3x2.T13`, `2x2.T12`,
  `3x3.C2`, `4x3.C2`, `4x4.C2`, `3x3.C3`, `4x3.C3`, `4x4.C3`, `3x3.E2-RUN1`/`-RUN2`,
  `3x3.E3`, `GLOBAL.E1`, `GLOBAL.E2-SANITY`/`-POLICY`/`-VERDICT`, `GLOBAL.LEAK`, `GLOBAL.P3`,
  `4x4.P3`, `GLOBAL.T06`, `4x4.B39`, `4x4.B43`/`-DIV`, `4x4.B16-GAME`, `2x2.C3`, `3x2.C3`,
  `GLOBAL.LONGCYCLE`, `QA-003`/`-009`/`-012`/`-013`/`-015`/`-022`/`-026`.
- **Deliverables.** `docs/epics/E1-markovian/wp3/Z-NONCLAIMS.md` plus the negative cells in
  `Z-R-TIE.md`, `Z-TABLE-FAITHFUL.md`, `Z-CONVERGE-FIX.md`, `Z-COMPLETE-ENUM.md`,
  `Z-AUDIT.md`, `Z-TABLE.md`; `docs/evidence/WP3-NONCLAIMS/`; findings JSON.
- **Holds.** those seven shard files. **Needs.** W3-01, W3-05.
- **Acceptance.** Per row, the falsifying witness reproduced at HEAD **by an instrument that
  is not the one that first produced it** (duplication-as-oracle: re-running the same
  instrument tests determinism, not correctness — Amendment 1). Both readings printed. Where
  no second instrument exists the cell is `NA:single-instrument` and says which — **it must
  not read as re-derived.** **Control per witness:** the same check on a state where the claim
  is *not* falsified must pass. *A falsification instrument that fires everywhere has found
  nothing.* Null: the E2-SANITY pattern — with `lo=−N, hi=+N` the policy is leak-free, proving
  the harness is wired.
- **Worked example.** `GLOBAL.LONGCYCLE` / `QA-013` / `QA-026` share the 3×2 witness
  `(178,0,6,0)`, goban `[B,W,B,_,W,_]`, Black to move, truncation values −3 and −6 against
  fixpoint L=H=−6 — already hand-verified by two independent implementations
  (`docs/evidence/QA-023/c1-witness-handcheck-2026-07-29.md`). Re-run both, print both, and
  print the passing control on a neighbouring non-witness state.
- **Known debt to carry, not to hide.** `3x3.E2-RUN2`'s 8,000-game run log is **not
  committed** (T743's D-1). This row either re-runs the replication or records
  `DM:` with the debt named. It may not re-affirm from prose.
- **Provenance.** T740 W3-05 (structure, the not-the-same-instrument rule, the worked
  witness); T743 W3-14 (the row-ID enumeration, the E2-RUN2 debt); T742 W3-8 (the
  independent-re-implementation requirement, the E2-SANITY null).

#### W3-07 · `wp3-measurements` · "Re-read the 51 MEASUREMENT rows" · L

- **Why the different verb.** A MEASUREMENT row is a datum, not a truth-claim, so it is not
  "re-derived" — it is **re-read**.
- **Deliverables.** the MEASUREMENT cells across 13 shards; `docs/evidence/WP3-MEASUREMENTS/`;
  findings JSON. **Holds.** those shards. **Needs.** W3-01, W3-05, W3-06 (shared shards).
- **Acceptance.** Every MEASUREMENT row's number reproduced from a **named command at a named
  commit**, or dispositioned `DM:stale` with the reason. Denominators mandatory. A row whose
  instrument no longer exists is `DM:stale`, not silently carried.
- **Worked example.** `GLOBAL.REACH-P4-CENSUS` states 258 / 2,586 / 73,758 / 1,929,038 /
  147,638,298 — re-run `bin/weizigo-reachcensus`, print all five with the command, or write
  `DM:stale` and say which one moved.
- **Provenance.** T740 W3-06 verbatim.

#### W3-08 · `wp3-untested-honest` · "Disposition the 21 UNTESTED rows" · S

- **No new science.** Each UNTESTED row gets `NA:<the specific blocker>` — the blocker is the
  content. Also disposition the 3 SUPERSEDED, 1 INTRACTABLE and 1 definition row (`NA:` with
  the kind). **Holds.** those shards. **Needs.** W3-01.
- **Acceptance.** No cell says "untested" without naming what would change it.
- **Worked example.** `QA-023` / `GLOBAL.H1-MARKOV` →
  `NA:contrast-generator misses shortest arrival in 93% of states (3x3) / 84.3% budget
  exhaustion (3x2); 0 failures in 404+80 pairs is a lower bound at denominators 24 and 6
  eligible states (T372, docs/evidence/QA-023/c1-contrast-2026-08-05.md)`. **That** is a
  disposition. "UNTESTED" alone is not.
- **Provenance.** T740 W3-07 verbatim. Note the §6.3 disagreement: T742's finish gate would
  forbid this row's entire output.

#### W3-09 · `wp3-evidence-commit` · "Commit or demote 46 unbacked PROVENs" · L

- **Why this is a hard predecessor of Wave 2, not a cleanup.** C3: **46 of 66 PROVEN rows have
  no committed evidence.** DIRECTION §7: "evidence committed under `docs/evidence/` or the
  claim is not proven." C10 shows where it went instead: 1237 citations outside the tree,
  1030+ into gitignored `untracked/`. **A row with no committed evidence has nothing to
  re-derive *against*** — deciding, per row, whether to recover or demote *before* the node
  batches start is what keeps Wave 2 from silently converting "no evidence" into "re-derived".
- **Deliverables.** `docs/evidence/WP3-BACKFILL/` (recovered evidence); the affected shard
  cells (`RD:` where recovered, `DM:PROVEN->CLAIMED` where not); findings JSON.
- **Holds.** `docs/evidence/WP3-BACKFILL/` and the shard cells for the 46 rows only.
- **Needs.** W3-01, W3-05.
- **Acceptance.**
  1. Each of the 46 ends `RD:` with a path under `docs/evidence/` **or**
     `DM:PROVEN->CLAIMED` with the reason. **No third outcome.**
  2. C3 recomputed and printed before and after; the delta equals the number of `RD:` cells.
  3. **Control:** for every recovered evidence file, the number in the register is reproduced
     *from that file* by a printed command. *A file that is committed but does not contain the
     number is not evidence.*
  4. **Demotion is the default, not the failure mode:** an unrecoverable PROVEN row is demoted
     the same day, not carried as a TODO.
- **Worked example.** The 13 C2 dead links are the worst cluster (`untracked/B05-glm.md`
  reachable from many rows, `untracked/T07-audit-hypotheses.md`, `untracked/T02-minimax.md`).
  `CLAIMS.md`'s own "evidence recovery" section already records four as **RECOVERED by
  re-implementation** and three as **LOST**. Re-implementation is the affirmative move:
  recover by re-deriving, then commit the re-derivation.
- **Scope, stated.** Scoped to the 46 unbacked **PROVEN** rows only. Whether Waypoint 3 owes
  the same treatment to CLAIMED and MEASUREMENT rows citing `untracked/` is §7 OPEN-7.
- **Provenance.** T740 W3-08 verbatim. *This row is where Waypoint 3's honesty is won or lost.*

---

### Wave 2 — the believed set, batched by tree node (125 rows)

Every Wave-2 row has the same shape: `RD:`/`DM:`/`RT?` for each believed row in its nodes,
against the kernel plus the battery, at every rung the claim's scope names, with the tree-gap
work its nodes own (`register-tree-map.md` §5) folded in. **Each holds only its own shards, so
all seven run concurrently.** All seven need W3-01, W3-02, W3-03, W3-04, W3-05, W3-09.
New instruments take fresh `src/w3_*.zig` files (§1.6).

#### W3-10 · `wp3-state-nodes` · "Re-derive state + sign nodes (20)" · M
Nodes: Z-STATE-LEGAL (6), Z-STATE-REACH (5), Z-R-STATE (4), Z-STATE-KEY (3), Z-SYM (1),
Z-R-SIGN (1). Reused as-is: colex bijection, `bin/weizigo-reachcensus`, key agreement
(`rules.stateKey` vs `vb_movegen.stateKey`), I2 colour inversion, I6 legal-position census
against the OEIS anchors (57 / 489 / 12,675 / 321,689 / 24,318,165 — A094777).
**Owns tree gap §5.2 — Z-STATE-KEY under *adversarial* move selection.**
`CODE.KEY-AGREEMENT`'s own caveat: first-legal-move self-play under-covers cycle-intensive ko
positions. New instrument in `src/w3_keyadv.zig` (not `differential.zig` — T531).
**Acceptance:** key agreement re-run at all five rungs with denominators (4×4's
`0 / 99,133,036` is on record, T345) **plus** an adversarial selector that maximises
ko-recapture depth, driven through ko fights, pass fights, approach-move loops and the 3×2 T13
witness family. Its **null control**: the selector on a ko-free slice must find 0. Its
**seeded-defect controls**, three, each a historical defect re-introduced behind a default-off
knob: ko-too-broad (pre-T265), passes-bit dropped (T193), colex-vs-rank (T178) — each must
fire ≥ 1 disagreement with its historical fingerprint, then go green.
*Provenance: T740 W3-09 (nodes, structure); T743 W3-03 (the three-defect seeded set, the
cycle-intensive region list, the new-file routing); T743 W3-06 (the OEIS anchors).*

#### W3-11 · `wp3-ruleset-nodes` · "Re-derive ruleset nodes (26)" · L
Nodes: Z-R-MOVE (13), Z-R-SCORE (10), Z-R-TIE (3).
**Owns tree gap §5.1 — Z-R joint well-definedness**, the largest genuinely open node: no row
asserts the axioms *collectively* define a self-consistent computable ruleset, and its [F]
("a position where two interpretations of the axioms disagree on legality") is mechanized
nowhere. `register-tree-map.md` §5.1 is explicit that T273's differential is **not** the
seventeen-copy comparison AXIOMS §2 promises. **Also owns §5.4** (Z-R-TIE's
Markovian-sufficiency test) and the Z-R-SCORE gap the pass1 spec §2 names (I12 bounds values
in [−area, +area] but never verifies terminal scores are *correct* per C2).
New instruments: `src/w3_rjoint.zig` (two independent readings of the AXIOMS text — the kernel
and a from-the-text re-implementation, R8 style, no `src/` imports — compared over legality,
capture, suicide, ko-after-capture, pass/forced-pass) and `src/w3_scorer.zig` (an independent
Tromp-Taylor as-stands terminal scorer per AXIOMS §2 Amendment 4).
**Acceptance:** the seventeen demoted ko copies run as frozen differential fixtures against
the one production `rules.koAfterCapture` at every rung; every disagreement enumerated and
adjudicated one by one (epic-01 bug → catalogue; kernel bug → the oracle earned its keep).
Exhaustive ≤ 3×2, sampled at 3×3+ with stated denominators. Also re-mechanizes
`GLOBAL.Z-R-MOVE-B1-EQUIV` (T380 F-3: old predicate 152/784 at 3×3 and 36,446/344,996 at 4×4;
corrected 0/784, 0/344,996) — **in a new test file, not `src/rules.zig`** (T531): the old
predicate *is* the mutant, and the new test must fail on it.
**The tautology check is mandatory and is the point:** `differential.zig:269-272` once defined
`engineKoNewGeneric` as `return solverKoGeneric(...)` and compared the solver's ko rule against
**an alias of itself** (GRAND-AUDIT §1a). Before any run counts, assert each fixture's
implementation is not the production one — **by symbol identity, not by name**.
*Provenance: T740 W3-10 (structure, the tautology assertion); T743 W3-04/W3-05 (the two new
instruments as separate deliverables with their own controls, the B1 re-mechanization and its
hold hazard); T742 W3-2 (the joint-well-definedness framing).*

#### W3-12 · `wp3-converge-nodes` · "Re-derive convergence nodes (16)" · M
Nodes: Z-CONVERGE (2), Z-CONVERGE-MONO (2), Z-CONVERGE-FINITE (2), Z-CONVERGE-FIX (10),
Z-CONVERGE-SEED (1, UNTESTED).
**Owns tree gap §5.3 — Z-CONVERGE-SEED at 2×2/3×2/3×3:** the only seeding row is `4x4.FP1-C1`
and it is UNTESTED; the other sizes have no seeding-provenance evidence at all. This is the
**cheapest gap in the tree** — it is a post-hoc read of build logs showing the L-sweep seeded
from −N and the H-sweep from +N (T743's observation).
**Acceptance:** L = Φ(L) and H = Φ(H) exhaustively at 2×2/3×2/3×3/4×3 (all fit) and at the
recorded 4×4 denominator (`0 / 95,677,624` KO_SENSITIVE-clear, I4 — re-run or cite with its
command); finite-sweep records (4 / 10 / 16 / 17 / 31) re-derived from build logs plus the
final zero-change sweeps; seeding provenance recorded per rung, or `NA:` naming what is
missing; monotonicity accepted as **mathematical** via the committed FP1/FP3 proof with the
proof path cited (no new compute, and the acceptance is stated as a reading, not a run).
**Controls:** a seeded off-by-one in one slot must raise the Bellman violation count; a
dry-run log claiming the build seeded from 0 instead of −N must be flagged by the provenance
check; two independent readers of the same stdout for the sweep counts. I4's null is the
ADR-0020 independent Python re-run at 2×2; the v1 basic-ko artifact's I2 failure (T260, ≈48%)
is the regression-input pair.
*Provenance: T740 W3-11 (nodes, structure); T743 W3-08 (the seeding row as the cheap gap, the
wrong-provenance seeded control, the MONO-is-a-proof-not-a-probe honesty).*

#### W3-13 · `wp3-table-nodes` · "Re-derive table nodes (30)" · L
Nodes: Z-TABLE (3), Z-TABLE-ROUNDTRIP (1), Z-TABLE-FAITHFUL (18), Z-TABLE-CONSISTENCY (8).
The largest batch, and it holds the falsified-finisher family: `GLOBAL.F1` FALSE,
`GLOBAL.F2` orphaned via `GLOBAL.C3` and confirmed orphaned by ADR-0015/0017/0018.
**Acceptance:** for each of the 18 Z-TABLE-FAITHFUL rows, **either** the k=1 fixpoint build
satisfies it by construction (ADR-0020: the table *is* the fixpoint, no finisher) — in which
case the cell says so **and cites the build** — **or** it is a statement about a
finisher-built table and is `RT?`/`DM:`. **Do not let "satisfied by construction" pass
unexamined:** it is a claim about the builder, and its control is the round-trip plus
consistency battery on the actual committed artifact at each rung. Plus: A5 round-trip
(exhaustive at 4×4, closing the stride-97 sampling gap `SPRINT-M4a-ACCEPT` self-reports), A8
DTT consistency, A9 reproducibility, I2 colour inversion exhaustive on both WZO2 artifacts,
build-repro byte-identity, parallel-fixpoint byte-identity. The 3×3 anchor is **reconciled
honestly**: the MIGOS basic-ko agreement (`GLOBAL.MIGOS-RULE`, MIGOS's own 4×4 basic-ko result
is +1 = ours) is re-attested as **external attestation only, never a `d:` parent**, and the
refuted tie-semantics explanation (`GLOBAL.TIE-MIGOS` FALSE-AS-SCOPED) is not silently reused
as proof.
**Controls:** A6's three calibration fixtures (value→SHA, dropped ko state, zeroed DTT) as the
seeded set; the T292 golden-master baselines as regression inputs (pass condition is
**unchanged from baseline**, never "fails" — Amendment 1); T260's independent Python inversion
re-implementation as the I2 null; T395's four seeded-defect knobs red-then-green.
Also decides the I7 DTT format split (SOLUTION-TREE §8b.4 / T395 proposal 3) — **decided, not
left ambiguous.**
*Provenance: T740 W3-12 (nodes, the by-construction discipline); T743 W3-09/W3-11 (the
anchor-reconciliation treatment, the A5/A8/A9 and I7 deliverables, the control set); T742 W3-5
(the I7 decision as a deliverable).*

#### W3-14 · `wp3-complete-nodes` · "Re-derive completeness nodes (3)" · S
Nodes: Z-COMPLETE-ENUM (2 believed + 2 FALSE-AS-SCOPED + 1 MEASUREMENT), Z-COMPLETE-PASSES (1).
**Owns tree gap §5.5** — closure under the kernel move generator at 4×4 — which is **largely
already run**: T363/T383 measured C-A1 `0 / 616,030,190` and C-A2 `0 / 99,133,034` under the
**corrected** kernel-successor ko-decode, and T474's #2 auditor re-ran both at HEAD with exact
reproduction. So this row is mostly citation and absorption, plus running the same closure at
the three new rungs from W3-03. **The pre-T383 `kb>>1` figures (0/600,763,414, 0/99,020,312)
are superseded and must not be re-published.**
**Acceptance:** closure at all five rungs with denominators; M8's deleted-entry fixture
(`src/vb_mutants.zig:486` — forward 0→2, backward 0→1, restore 0/0) re-run as the
seeded-defect control **at each new rung** (T741's OPEN: an equivalent seeded fixture is
confirmed only at 3×3; rows must mint one at 2×2/3×2/4×3 or say they did not).
Also updates the "closure untested" language in `WZO2-4X4-VALID` and
`register-tree-map.md` §5 item 5, both of which predate this evidence (T305, 2026-08-03).
*Provenance: T740 W3-13 (the cite-don't-recompute ruling); T741 §0 items 1 and 3 (the two
stale-doc findings, and the OPEN on 2×2/3×2 seeded closure fixtures); T743 W3-06.*

#### W3-15 · `wp3-audit-nodes` · "Re-derive audit nodes (16)" · M
Node: Z-AUDIT (16 believed of 24). These are **instrument-validity** claims — the rows that
say whether the other rows' instruments can be trusted, so they are the ones a green reading
most easily launders.
**Owns tree gap §5.6 — the #2 auditor on a completed k=1 4×4 build** (`4x4.F3`, `4x4.D3`
UNTESTED; T274's residue, `PROGRESS.md:225,446`, "our own +1 still awaits the #2 auditor").
This is the surviving half of T743's W3-10 after §1.3: **the auditor is owed; the regen is
not.** The auditor traces complete evaluations end-to-end (the QA-023 rule: reviewing inputs
and outputs is not tracing a datum).
**Acceptance:** each Z-AUDIT row's instrument re-run with **both** its controls; **any
instrument whose controls do not both fire is `DM:` regardless of its verdict.** The #2
auditor run on 3×2 exhaustive plus the deepest-N 4×4 sample (N and the depth distribution
stated), 0 minimax-identity violations — with its **known-bad `3x2.F1` (writes-on, 45/378)
and known-good `3x2.F3` (writes-off, 0/378)** as the calibrating pair, and the `ko_ref >= d`
defect shape (ADR-0013) as a second seeded control. **This is zero violations, not "sound by
construction."** The writes-on checkpoint's untrusted ko-sensitive values get an explicit
`NA:` cell recording that they stay untrusted (the T472 residue).
`CODE.I5-INSTRUMENT-ADJUDICATION` is the precedent **to honour, not to trust**: `vb_graph` was
wrong on every graph metric while both instruments' verdicts passed, and defect C
**fabricated** the "24 natural violations" at 4×3 that two rows then repeated. Any counter
that is impossibly clean is itself a finding (T744's rule).
*Provenance: T740 W3-14 (the launder warning, the fabrication precedent); T742 W3-6 and T743
W3-10 (the auditor row, its calibrating pair, the ADR-0013 seeded shape); T744 W3-12 (the
end-to-end tracing requirement and the impossibly-clean rule).*

#### W3-16 · `wp3-root-nodes` · "Re-derive Z and the non-claims (14)" · S
Nodes: Z (2 believed), Z-NONCLAIMS believed (12). **Last, because Z is exactly the conjunction
of its children.**
**Acceptance:** `GLOBAL.Z` gets `RD:` only if every child node's shard is free of `TODO` and
free of `DM:` on a row Z depends on; otherwise `GLOBAL.Z` stays CLAIMED and the cell **names
the blocking children**. **`GLOBAL.Z` must not be promoted by this row** — Waypoint 3 produces
dispositions; promotion past CLAIMED is Amendment-2-gated per claim and is Waypoint 4 business
at the earliest.
*Provenance: T740 W3-15 verbatim.*

---

### Wave 3 — close

#### W3-17 · `wp3-4x3-size-ruling` · "4×3 in the theorem? ruling brief" · S

- **The wrinkle** (T744's find, verified). Z's size set is **{2×2, 3×2, 3×3, 4×4}**
  (`AXIOMS.md:20`) — **4×3 is not in the theorem** — yet the register holds **14 4×3-scoped
  rows** plus six multi-size scopes that include it, and substantial 4×3 evidence (closure
  0/643,378, cycle containment 0/170,181, `4x3.H1-CENSUS`). The rows are real knowledge
  feeding `all`-scoped claims; the theorem is silent about them.
- **Deliverables.** A one-page ruling brief: amend Z's size set to include 4×3 (the evidence
  already exists; the cost of inclusion ≈ what W3-03 and Wave 2 already deliver) **or** mark
  the 14 rows out-of-theorem supporting evidence (a tree-map disposition, **not** RETIRED).
  Each 4×3 row carries the question as a rider on its Wave-2 disposition.
- **Needs.** W3-10…W3-16 (the 4×3 legs must be dispositioned before the ruling has a
  denominator). **The row completes with the bundle; the ruling is queued, not blocking.**
- **Acceptance.** Both candidate rulings stated with their row-level consequences; the 14 rows
  enumerated; no 4×3 row left without a Wave-2 disposition regardless of the ruling.
- *Provenance: T744 W3-08 — the only lane to notice, and a genuine gap in the other four.*

#### W3-18 · `wp3-ratification-sheet` · "One sheet, all operator rulings" · M

- **The only operator-facing row.** Every `RT?` and every contested `DM:` from Waves 1–2 is
  collected into one sheet with a RECOMMEND column filled and a RULING column empty. **This is
  why no Wave-1/2 row blocks: they propose, they do not wait.**
- **Deliverables.** `docs/epics/E1-markovian/wp3-ruling-sheet.md`; findings JSON.
- **Holds.** that file. **Needs.** W3-06…W3-17.
- **Acceptance.** One line per proposal carrying (a) current status, (b) family reason,
  (c) what is lost if ruled, (d) live in-register dependents parsed from the `dependents`
  column filtered to non-retired rows, (e) external `docs/` citation count with three example
  paths, (f) a **sole-`e:`-evidence flag** where the row is the only evidence for a
  still-believed row.
  **Batch the asks by family, not by row** (T741): the retirement question is ~8 family-level
  asks (ruleset-choice, old-artifact, player, process, design, crisis-diagnostic, absorption,
  falsified-foundation), not 116+ individual ones. The 4×3 size-set question from W3-17 rides
  on this sheet as one more ask.
- **Worked example.** `retirement-ruling-sheet.md` (T324) is the exact precedent — 116
  proposals, 27 with live dependents, 8 flagged sole-evidence, ruled once, executed by T373
  (339 → 207 rows, "archive, never delete"). **Copy its shape verbatim.**
- *Provenance: T740 W3-16 (structure, the six columns, the T324 precedent); T741 row 2 (family
  batching, and the conservative default: any family unruled by gate time stays **live**, so
  nothing stalls).*

#### W3-19 · `wp3-finish-gate` · "Mechanize the Waypoint-3 gate" · M

- **Deliverables.** `zig build wp3-gate`; `src/claimlint.zig` (C15 report-only → failing);
  `tools/hooks/claimlint-floor.json` (`C15: 0`);
  `docs/epics/E1-markovian/wp3-controls-manifest.json`; `WAYPOINTS.md` (the Waypoint-3 row);
  findings JSON.
- **Holds.** `build.zig` (**T531 collision — W3-00 must have cleared it**),
  `src/claimlint.zig` (chain after W3-02), `tools/hooks/claimlint-floor.json`,
  `docs/epics/E1-markovian/WAYPOINTS.md`.
- **Needs.** W3-02 (`src/claimlint.zig`), W3-18, and by construction all of W3-00…W3-18.
- **Acceptance.** §5, including its own four controls.
- *Provenance: T740 W3-17; the controls manifest is T743's W3-16 item 3.*

---

## 3. Sequencing rationale

**Only five real edges exist; everything else is file ownership.**

1. **W3-00 gates dispatch of anything touching a T531-held file.** §1.6. This is a
   *mechanism* gate, not a science one, and it is the reason it is row zero.
2. **W3-01 gates everything else** — there is nowhere to record a disposition until the shards
   and C15 exist. This is the edge DIRECTION Amendment 2 §3 already names: *"Phase 3 row
   re-derivation ← the battery exists AND the register-to-tree mapping exists."* The mapping
   exists (C9 green, 231 == 231); **the disposition surface does not.**
3. **W3-02 is the promotion currency, and it must go early even though it gates no
   dispatch.** Amendment-2 edge 5 binds *promotion, not dispatch*: Wave-1 and Wave-2 rows run
   and even reach their dispositions without it. But every `RD:` that would move a row past
   CLAIMED is paid in this currency, and today the currency has three values and a vacuous
   gate (§1.1). Four of five lanes put it first or near-first; T741 alone put it late and
   argued (correctly) that it gates promotion rather than dispatch. **Both are right: it is
   early because it is cheap and it is the thing most likely to invalidate a Wave-2 promotion
   after the fact, not because anything waits on it.**
4. **W3-09 gates all of Wave 2** — 46 of 66 PROVEN rows have no committed evidence. You cannot
   re-derive a claim whose original derivation is not on disk; you can only re-prove it from
   scratch or demote it. Deciding which, per row, before the node batches start is what keeps
   Wave 2 from silently converting "no evidence" into "re-derived".
5. **W3-03 gates W3-04 and every rung-scoped acceptance in Wave 2** — three of five rungs have
   no WZO2 artifact, so "differentially at every rung" is unrunnable at 2×2, 3×2 and 4×3.
6. **W3-16 comes last by construction** — Z is the conjunction of its children.

**`src/claimlint.zig` is the serializer, not the wave number:** W3-01 → W3-02 → W3-19 is a
hard chain on one file. Everything else in Waves 1–2 is concurrent because the shard design
gives each row disjoint holds. Amendment 2 applies unchanged — **the wave number is not a
dependency.**

**The ladder order is evidentiary, not a dispatch gate.** All five lanes converged on this
independently, and it is worth recording as settled: `GLOBAL.ADR0016-INHERIT` / NC3 per-goban
independence means a verdict at one rung is *never* evidence at another, so 2×2 → 3×2 → 3×3 →
4×4 is **shake-out order** — a harness defect surfaced at the cheapest rung invalidates the
expensive runs, which is an engineering reason to start small, not an epistemic one. Rungs may
run concurrently once W3-03 is green at each. DIRECTION's Amendment 2 says the same thing:
waypoint order is dependency order, and no waypoint gates another's dispatch.

**Where Waypoint 2's remaining debt sits.**

- **Mutation adequacy → W3-02, early, and the debt is a data-reconciliation problem, not a
  science problem.** All ten fixtures exist in `src/vb_mutants.zig`; the single machine source
  C8 reads still says 3; and C8 is vacuous until a promotion happens. Cheap to fix, expensive
  to leave.
- **The "seven closed promotion gates" are a *reading of the 3/10 figure*, not a separate
  debt** (`DIRECTION.md:270-271`). They are discharged by W3-02's reconciliation plus its
  dated note on Amendment 2. **No Waypoint-3 row waits on them.** The count is *computed from
  a reconciled matrix*, never quoted from memory (T744's rule).
- **T430's "unexecuted phase-2 audit" is not Waypoint-2 debt and sits nowhere in this
  order.** §1.5: the dispatchable row is a duplicate registration with the literal task id
  `--bundle`; the audit content was delivered under **T433**
  (`docs/infra/tool-consolidation/02-scope-audit.md`, pass-with-findings, F-a…F-f, residual
  F3–F5 line-citation errors). **Recommendation: close the phantom as kanban hygiene, outside
  Waypoint 3, preferably by landing T775's strict flag parsing so the class cannot recur.**
  If the operator instead wants a Waypoint-2 **kernel** execution audit — the analogue of
  `phase0-execution-audit.md`, which does not exist for Waypoint 2 — that is a distinct row
  and it belongs as a `needs W3-02` sibling of W3-15, because it is an instrument-validity
  question. §7 OPEN-3.
- **G3b already did much of rung 5.** `sprints/g3b-value-correctness/pass0/accept.md` records
  I4 `0/95,677,624`, C-A1 `0/616,030,190`, C-A2 `0/99,133,034`, key agreement `0/99,133,036`,
  I11 exhaustive `0/48,636,330` + `0/99,133,036` (T473), I11 0 at every rung, I5
  `0/3,455,412` — with T474's #2 auditor re-running the closure figures at HEAD. **Waypoint 3
  must cite that work, not redo it**; W3-12/W3-14 are sized as citation rows for the 4×4 cells
  and fresh work only at the new rungs. Two caveats travel with the citations: T474's N1 (4×4
  I5 placement-only) and the two structurally-impossible non-reachable entries in C-A2's
  denominator.

**Wall-clock, so the compute is not mistaken for the cost.** The 4×4 readings are minutes, not
hours (T743's compilation, worth carrying): closure C-A1+C-A2 245.8 s at 1,124 MB RSS (T383);
I5 149 s at 2,768 MB (T344); I11 69.5 s at 558 MB (T473); A2 50.6 s (T309) — each under the
runner's 4 GB cap. **The composition and the adjudication are the work; the compute is not.**
Every 4×4 run goes through `tools/runner` per `docs/infra/runner.md`.

**What this decomposition deliberately does not do.** It does not promote anything. Waypoint 3
produces dispositions; every promotion past CLAIMED remains gated per claim by Amendment-2
edge 5. **"Waypoint 3 complete" and "Z is PROVEN" are different sentences,** and L2 (proven
4×4 values) is downstream of the first, not equal to it.

---

## 4. Controls

Per never-trust-a-green-test, and per DIRECTION §7's "every instrument carries a null control
and a seeded-defect control **before its first reading counts**".

**Reused as-is, already carrying both controls — do not rebuild these:**

| instrument | null control | seeded-defect control |
|---|---|---|
| the ten mutants | the un-mutated fixture passes | all ten red-then-green fixtures in `src/vb_mutants.zig` (M1 `:171` … M10 `:536`) — **but see §1.1 for the matrix, not the fixtures** |
| battery I1–I12 (`vb_*.zig`, `zig build test`) | golden-master baselines (T292): pass = **unchanged from baseline**, never "fails" (Amendment 1) | the A1 synthetic mutant per invariant |
| I2 colour inversion | T260's independent Python re-implementation | kills M5 and M7 |
| I4 Bellman | ADR-0020 independent Python re-run at 2×2 | v1 basic-ko artifact's I2 failure (T260, ≈48%) as the regression-input pair |
| I5 SCC | third-route Python (T391); register-calibrated `vb_graph` post-fix | the historical **fabricated** 24 (defect C) — must read 0 true / 24 buggy |
| I7 DTT sanity | — | kills M6 |
| C-A1/C-A2 closure (`vb_closure.zig`, parametric on `w,h` from the header, `:81-82`) | 3×3 exhaustive in-suite (0 violations) | M8 fixture `:486` — 3×3 deleted entry, 0→2 / 0→1 / restore 0/0 |
| I11 move-set (`vb_i11.zig`) | kernel-vs-SMD1, 0/114 **vacuously** | allows-suicide mutant, 1/114 (T346). *The pair is the point: the null alone would prove nothing* |
| A1–A9 WZO2 acceptance | T212/T270 independent re-implementations | A6's three calibration fixtures (value→SHA, dropped ko state, zeroed DTT) |
| key agreement (`differential.zig`, T267/T345) | producer == consumer on a clean fixture | colex-bit-flip (T345 KEY-4x4); passes-bit-drop and pre-T265-ko (T530) |
| #2 auditor (RETRO_CONSIST) | `3x2.F3` writes-off, 0/378 | `3x2.F1` writes-on, 45/378; plus the `ko_ref >= d` shape (ADR-0013) |
| BATT-HEALTH | — | M9 `:445`: compile-time reflection over `vb.Invariant`, fails iff any returns `.skipped`. *This is what stops a check rotting into a skip* |
| falsification probes (t13/t389/t412/t416/t419) | E2-SANITY: trivial bounds `lo=−N,hi=+N` → leak-free everywhere | a planted divergence must be flagged; T416's null (ACYCLIC 0 edges) and seeded (`force_all_optimal` RED; the tie-handling control that undercounts 54→48) |
| claimlint C1–C14 | 15 known-good synthetic arms, printed every run | 18 known-bad synthetic arms; `calibration: PASS` live |
| the 17 frozen ko copies, exp4–7, brute forcers | — (they *are* the differential corpus) | every kernel-vs-fixture disagreement is a finding to adjudicate (DIRECTION §4) |

**New instruments, each owing both controls before its first reading counts:** C15 (W3-01,
three seeded defects); the non-vacuous C8 (W3-02, null = restore the old JSON); the WZO1↔WZO2
rung differential (W3-03); `tools/wp3-coverage` (W3-04, null = empty run-record set); the
stale-limit sweep's own grep (W3-05); `src/w3_keyadv.zig` (W3-10, three historical defects);
`src/w3_rjoint.zig` and `src/w3_scorer.zig` (W3-11); the seeding-provenance check (W3-12);
`zig build wp3-gate` (W3-19, four seeded defects).

**Four control disciplines this decomposition treats as load-bearing, each because the project
has already been burned by its absence:**

- **A positive control must exercise the instrument under test, not a parallel one.**
  `differential.zig:269-272` compared the solver's ko rule against an alias of itself
  (GRAND-AUDIT §1a; QA-023 standing rule, `AGENTS.md:146-148`). W3-11's fixture-identity
  assertion is this rule mechanized.
- **A vacuous control is a blind control and must be recorded as one.** Two instances now:
  the g3b spec premised that 3×2 is the first non-vacuous I5 rung and T363 measured that false
  (at 3×2 every `passes=0 ko=NONE` slot is cycle-reachable; at 4×3 the non-CR slots are all
  already KO_SENSITIVE; the first genuinely red-then-green rung is 4×4) — **and C8 itself,
  which reads 0 only because no claim is at PROVEN** (§1.1). Wave-2 rows must **print
  vacuity, not skip past it**.
- **Known-bads are synthetic, never live** (Amendment 1). Live artifacts are **regression
  inputs**: they must not *newly* fail. `0c3366f0`'s completeness checks must **pass** — its
  defect was refuted (T266/T277/T279) — and any new failure against it is a finding to
  adjudicate, not an expected result.
- **A control that cannot run must fail loudly, never pass vacuously** (DIRECTION §7), and
  **any counter that is impossibly clean is itself a finding** (T744; the QA-023 scar: an
  impossibly clean 1133/1133 TIE counter).

---

## 5. The finish line

**`zig build wp3-gate`** — one composite step, exit 0 only when all nine conditions hold.
Prose is not the gate; this is.

1. **C15 == 0** — shard union equals the register row set exactly (`missing: 0 · extra: 0 ·
   duplicate: 0`), `TODO: 0`, `invalid: 0`, `RT?: 0` (every proposed retirement ruled). C15
   failing, floor `C15: 0`.
2. **No `RD:` cell without committed evidence** — for every `RD:` cell, C3 UNBACKED does not
   name that row and its evidence path resolves inside `docs/evidence/`. An unbacked row may
   be `DM:` or `NA:`; **it may not be `RD:`**.
3. **C8 == 0, non-vacuously, and failing**, floor `C8: 0` (Amendment-2 edge 5) — and the
   reconciled matrix is the one C8 reads, with every SURVIVES entry naming the promotion gate
   it closes.
4. **Every `RD:` cell names its controls, and both fired** — the controls manifest
   (`docs/epics/E1-markovian/wp3-controls-manifest.json`) carries, per instrument, a
   red-then-green evidence path that **exists on disk**; the gate fails on any missing path.
5. **C4 == 0, C5 == 0, C12 dead == 0** — 49 claim IDs cited in `docs/` with no register row is
   incompatible with "every row re-derived": either the ID names a claim (mint the row) or it
   does not (delete the citation). C2 stays at its floor of 13 **or lower** — the floor never
   rises. C3 at or below its floor of 48.
6. **Coverage is honest** — `tools/wp3-coverage --check` exits 0; no `exhaustive` cell without
   a denominator; **no `RD:` cell citing an instrument the matrix marks `blind` at that rung**.
7. **Every rung has an artifact with verified provenance** — 2×2/3×2/3×3/4×3/4×4 each have a
   WZO2 artifact whose `artifacts/SHA256SUMS` line verifies on disk; the two too large to
   track additionally name their builder commit.
8. **`zig build test` green and the battery golden-master unchanged from `baselines.md`.**
9. **The ephemeral auditor's verdict is present and pinned** —
   `docs/audits/<date>-wp3-gate/VERDICT.md` exists, its `at HEAD <sha>` line equals
   `git rev-parse HEAD` at close, its verdict is PASS or PASS WITH FINDINGS, and every finding
   it raises carries a disposition. The auditor is human-shaped and ephemeral (DIRECTION §6);
   **the presence and pinning of its verdict is what the gate can check, and that is all it
   should claim to check.**

**The gate's own controls — because a finish-line gate is the instrument most likely to be
believed while blind.** Ship all four red-then-green before the first green reading counts:

- **known-good:** the tree at the moment the gate is declared satisfied. It must pass.
- **seeded defect A:** revert one shard cell to `TODO` → must fail on condition 1.
- **seeded defect B:** delete one `RD:` row's evidence file → must fail on condition 2.
- **seeded defect C:** mark one killed mutant `survived` in `kill-matrix.json` → must fail on
  condition 3.
- **seeded defect D:** strip one instrument's control path from the manifest → must fail on
  condition 4.

**A gate that passes all five is not a gate.**

**What the gate does not say.** It does not say Z is proven, it does not say the 4×4 values
are correct, and **it does not clear L2**. It says: every one of the 231 register rows has
been re-derived, demoted, or retired against the requirement tree, by an instrument whose
controls fire, at the rungs its scope names — and that nothing was left TODO.

---

## 6. Where the lanes disagree — the operator rules

These are presented, not resolved. Each carries this synthesis's recommendation.

### 6.1 Where the dispositions live

**T740:** a shard directory (`wp3/<node>.md`) plus C15 row-set equality.
**T742 / T743:** a single JSON ledger (`waypoint3/ledger.json` /
`docs/evidence/WAYPOINT3/verdict-ledger.json`) with a richer per-row schema
(`disposition`, `status_after`, `instrument`, `evidence`, `null_control`, `seeded_control`,
`auditor`, `open_precondition`).
**The T305 precedent:** a 12th column *inside* `CLAIMS.md` — "the only place the mapping lives
inside the register … cannot silently cover a subset".

**Recommendation: shards.** The reason is contention, not disagreement with T305: `CLAIMS.md`
is written by every absorption, so a 12th column serialises all nineteen rows behind unrelated
work, and C15's row-set equality recovers the anti-subset property without the column. **But
graft T742's schema into the shard cell** — `RD:<instrument>@<rung>` is thinner than
`{instrument, evidence, null_control, seeded_control, auditor}`, and gate condition 4 needs
the control paths to be machine-readable. The operator may reasonably prefer the in-register
column and accept the serialisation; **everything downstream is unaffected either way — only
W3-01's deliverable changes.**

### 6.2 What goes first

**T742:** the gate first ("a rule that stays prose is a rule we have chosen to re-learn").
**T743 / T744:** the mutation kill matrix first ("the currency, not a step").
**T740:** the recording surface first. **T741:** the inventory first, mutation row late,
because edge 5 binds promotion and not dispatch.

**Recommendation: recording surface, then currency, then the gate last** (W3-01 → W3-02 →
W3-19), with W3-00 ahead of all of them. T742's instinct is right that the gate must exist
before the work it measures — which is why C15 ships **in W3-01, report-only**, and only
becomes failing in W3-19. That gets T742's discipline without 231 `TODO` cells breaking the
pre-commit hook on day one. T741's analysis is correct on the mechanism (edge 5 gates
promotion, not dispatch) and it is why W3-02 blocks no dispatch — but it goes early anyway,
because a Wave-2 promotion taken on a stale matrix has to be re-done.

### 6.3 Whether "no UNTESTED survives" is a finish condition

**T742's gate rule R3:** *no live row's register status is `UNTESTED`* — "an UNTESTED survivor
means the waypoint is unfinished, not that the row is unknowable".
**T740's W3-07 + `NA:<reason>`:** an honestly-blocked row is dispositioned `NA:` with the
blocker named, and that is a *completed* disposition.

**These are incompatible, and it is the sharpest disagreement in the race.** 21 rows are
UNTESTED today; several are UNTESTED because the measurement is expensive or the instrument
does not exist (`4x4.S2-impl`, `4x4.S3b`, `4x4.D3`).

**Recommendation: T740's.** R3 as written would force either a large unbudgeted measurement
programme or a dishonest status change, and DIRECTION asks for "re-derived, demoted, or
retired" — not "proven". `NA:<reason>` with a mandatory named blocker is the honest third
option, and the gate can check that the reason is *present* even though it cannot check that
it is *good*. **But T742's concern is legitimate and the mitigation is explicit:** W3-08's
acceptance requires every `NA:` cell to name **what would change it**, and W3-18's sheet
surfaces the whole `NA:` set to the operator in one place. If the operator prefers R3, W3-08
becomes a measurement programme and its size goes from S to L or worse.

### 6.4 Whether 4×3 is in the theorem

Only **T744** noticed: `AXIOMS.md:20` names {2×2, 3×2, 3×3, 4×4}; the register carries 14
4×3-scoped rows and heavy 4×3 evidence. The other four lanes silently included 4×3 as a rung
(T740's five-rung table, T743's rung 4) without flagging that the theorem is silent about it.

**Recommendation: W3-17's brief, ruled on W3-18's sheet.** The rows get dispositioned either
way; only their *tree disposition* changes. **Do not RETIRE them** — they are real knowledge
feeding `all`-scoped claims.

### 6.5 Granularity, and the phantom row

Row counts: **9** (T742) · **12** (T741) · **13** (T744) · **16** (T743) · **17** (T740) ·
**19** here. The merge is coarser than T743 per-family and finer than T742 per-phase. **Any
Wave-2 family row may be split per-rung if a worker budget demands it** — the family row is
the proposed granularity, not the only correct one (T743's note, adopted).

On the phantom `--bundle` row all five lanes agreed it should close and none proposed
re-executing the audit. **Recommendation: close it as kanban hygiene outside Waypoint 3**, and
prefer that T775's strict flag parsing land so the class cannot recur (§1.5).

---

## 7. OPEN — assumptions not verified

- **OPEN-1 (structural; the one ruling wanted before W3-01 dispatches).** Shard directory vs
  12th `CLAIMS.md` column vs standalone ledger — §6.1.
- **OPEN-2.** Whether `artifacts/oracle-4x3-v2.wzo2` is small enough to track (WZO1 4×3 is
  3.19 MB and tracked, so probably), and whether the 4×3 fixpoint build fits the runner's 4 GB
  RSS cap. Not measured. If it does not fit, 4×3 stays on the WZO1 oracle with its documented
  format boundary — **recorded, not silent**.
- **OPEN-3.** Whether a **Waypoint-2 kernel execution audit** is owed. No
  `phase2-execution-audit.md` exists (only `phase0-execution-audit.md`), and the "T430
  phase-2 audit" in the brief is a different sprint's scope audit (§1.5, §3). Not assumed; if
  wanted, it is a `needs W3-02` sibling of W3-15.
- **OPEN-4.** Row sizes are estimates from row counts and instrument reuse, **not measured
  wall-clock on comparable rows**. The three most likely wrong: **W3-09** (46 evidence
  recoveries, each a small research task), **W3-11** (the seventeen-copy differential, whose
  disagreement count is unknown until it runs — every disagreement is a finding to adjudicate,
  so the row could fan out), and **W3-06** (29 negative rows, but three witness families cover
  most of them, so it could be much cheaper than L). T743's worker-day estimates
  (2–4 for the mutation row, 5–8 for the large family rows, 4–6 for the new instruments) are
  the only quantified sizings any lane offered and are recorded here as the alternative
  scale — **also unmeasured**.
- **OPEN-5.** Whether the per-invariant mutant top-up (synthetic mutants for I4/I1/I8/I9,
  which `mutants.md` §7 lists as the *remaining* gap after the ten-mutant catalogue) is
  Waypoint-3 scope or Waypoint-1 carry-forward. T741 proposed it as a row (its row 10) and
  flagged as OPEN whether T292 already delivered it; I did not verify T292's shipped diff
  either. **Not included as a row here** — the catalogue mutants are what edge 5 names — but if
  the operator wants it, it is a `needs W3-02` sibling of W3-15, size L, and it gates
  *promotion* of the claims those invariants cover, not dispatch.
- **OPEN-6.** Whether `RT` executions move rows to `archives/register/` as T373 did (339 →
  207) or leave them live with the marker. T373's precedent says move, with epitaphs, "archive,
  never delete" — assumed here, and W3-18's sheet assumes the operator rules once for the whole
  batch. T742's W3-9 additionally proposes **confirming the 132 already-archived rows' epitaphs
  resolve against the tree** — not included as a row (the archive is out of the 231-row
  denominator), but it is cheap and the operator may want it.
- **OPEN-7.** The 1237 out-of-tree evidence citations (C10) are far larger than W3-09's 46
  rows; W3-09 is scoped to the unbacked **PROVEN** rows only. Whether Waypoint 3 owes the same
  treatment to CLAIMED and MEASUREMENT rows citing `untracked/` is a scope question DIRECTION
  §7 does not settle — it speaks only of "proven".
- **OPEN-8.** `3x3.E2-RUN2`'s 8,000-game run log is not committed and may be unrecoverable
  (T743's D-1). W3-06 either re-runs it or demotes it with the debt named; whether the original
  run is recoverable anywhere was not established.
- **OPEN-9.** The definitive inventory of "the seven promotion gates" is not stated verbatim in
  one place. T743 reconstructed it from the register's own "held at CLAIMED per edge 5"
  language (`4x4.C1`, `4x4.FP1`, `GLOBAL.H4`, `GLOBAL.I5-SCC-CONTAIN`,
  `4x4.WZO2-A2/A5/A8-EXHAUSTIVE`, `CODE.WZO2-BUILD-REPRO`, `CODE.KEY-AGREEMENT`, plus the T273
  kernel claims) and noted the count may differ by a row or two. **W3-02's findings file should
  list the definitive set and reconcile any drift** — and per §3, the count is *computed from
  the reconciled matrix*, never quoted.
- **OPEN-10.** T531's actual state. It is `in_progress` with a 20-file hold set and no verdict
  note; whether it is genuinely live, abandoned, or mis-scoped was not determined here — that
  is W3-00's whole deliverable.

---

## 8. Provenance — which lane each row came from

Honest attribution, because the Race-I model comparison depends on it. "Trunk" = the row's
structure and acceptance criteria came from that lane substantially verbatim; "graft" = a named
improvement merged in.

| row | trunk | grafts |
|---|---|---|
| W3-00 hold-release | **T749** (new) | T743 OPEN-9 (the finding) |
| W3-01 shards + C15 | **T740** | T741 row 1 (inventory, folded into C15's output) |
| W3-02 kill-matrix | **T740** | T744 W3-01 (contradiction stated first; "either verdict is a pass"); T743 W3-01 (the unblocked-row list); **T749** (the C8-vacuity finding and the non-vacuity acceptance) |
| W3-03 rung artifacts | **T740** (+ its OPEN-2/5) | T742 W3-3 (anchor values, no-silent-overwrite); **T749** (the hold correction: the writer is hardcoded) |
| W3-04 coverage matrix | **T740** | — |
| W3-05 stale-scope sweep | **T749** (new) | T743 item 6 / T744 OPEN-4 (the 228-vs-231 drift) |
| W3-06 non-claims | **T740** | T743 W3-14 (row-ID list, E2-RUN2 debt); T742 W3-8 (independent re-implementation, E2-SANITY null) |
| W3-07 measurements | **T740** | — |
| W3-08 untested-honest | **T740** | — (T742's R3 would delete this row — §6.3) |
| W3-09 evidence commit | **T740** | — |
| W3-10 state nodes | **T740** | T743 W3-03 (three-defect seeded set, new-file routing), W3-06 (OEIS anchors) |
| W3-11 ruleset nodes | **T740** | T743 W3-04/W3-05 (two instruments as separate deliverables; B1 re-mechanization + its hold hazard); T742 W3-2 |
| W3-12 converge nodes | **T740** | T743 W3-08 (seeding as the cheap gap; wrong-provenance control; MONO honesty) |
| W3-13 table nodes | **T740** | T743 W3-09/W3-11 (anchor reconciliation, A5/A8/A9, control set); T742 W3-5 (the I7 decision) |
| W3-14 completeness | **T740** | T741 §0 (two stale-doc findings + the 2×2/3×2 seeded-closure OPEN) |
| W3-15 audit nodes | **T740** | T742 W3-6 / T743 W3-10 (the auditor half, its calibrating pair, ADR-0013); T744 W3-12 (end-to-end tracing, impossibly-clean rule) |
| W3-16 root nodes | **T740** | — |
| W3-17 4×3 ruling | **T744 W3-08** | — (the only lane to find it) |
| W3-18 ratification sheet | **T740** | T741 row 2 (family batching; unruled ⇒ stays live) |
| W3-19 finish gate | **T740** | T743 W3-16 (controls manifest); T742 §1.2 (per-rule counts, named rule on failure) |

Framing adopted whole from a lane, outside any single row: **T744's mechanical definition of
"re-verified"** (the preamble); **T742's two non-relitigable rulings** (§0 — which deleted two
large rows); **T743's findings-file-not-direct-write convention** (§2, which is what makes
Wave 2 concurrent).

---

**Landmark:** advances **L2 (proven 4×4 values)**. Waypoint 3 is now decomposed — 19
registerable rows in four waves, conflict-free holds, one mechanized finish gate with four
seeded controls of its own, and four disagreements escalated rather than papered over. **The
loss this exposes is ours, not an instrument's:** C8 — the gate that guards every promotion
Waypoint 3 exists to make — is vacuous today and reads clean, and two lanes read it opposite
ways from the same run. What remains before execution: the operator's ratification of §6 and
§7, then W3-00.
