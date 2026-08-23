# Waypoint 3 — decomposition spec (Race I lane, T740)

```
Task: T740 · Role: race lane (one of five, independent) · Model: claude-opus-5
Date: 2026-08-23 · At HEAD 3ce328e (working tree dirty: store + model-perf only)
Landmark: L2 (proven 4x4 values) is the product; L1 (the dashboard tells the truth) carries the measurement
Status: PROPOSAL. Not ratified. Registers nothing. The seat synthesizes across lanes; the operator rules.
```

**Waypoint 3** is DIRECTION.md §5's Phase 3 — the A-to-Z reverification program: "ladder
2x2 -> 3x2 -> 3x3 (anchor reconciled honestly) -> 4x4. Kernel vs fixtures differentially at
every rung; every register row re-derived, demoted, or retired against the requirement tree."
It has never been decomposed. This is the decomposition.

Every number below is printed by a command named next to it. A number without its command is
not a measurement (`register-tree-map.md` §3.1).

---

## 0. The measured starting state

`bin/weizigo-claimlint` at HEAD `3ce328e`:

| quantity | value | where |
|---|---|---|
| register rows | **231** | C0 `rows parsed: 231`, C9 `register rows: 231 · mapping doc rows: 231` |
| mapped to a tree node / proposed-retired | 228 / 3 | C9 |
| PROVEN | 66 | C3 (`46 of 66 PROVEN rows`) |
| **PROVEN with no committed evidence** | **46** | C3 `UNBACKED total` |
| CLAIMED | 59 | status-cell census, command below |
| MEASUREMENT | 51 | same |
| FALSE-AS-SCOPED / FALSE | 22 / 7 | same |
| UNTESTED | 21 | same |
| SUPERSEDED / INTRACTABLE / definition | 3 / 1 / 1 | same |
| dead evidence links | 13 | C2 (= the floor; never rises) |
| claim IDs cited in docs with **no row** | **49** | C4 `49 dangling IDs` (+ 2 unreferenced rows) |
| shadowed dependency | 1 | C5 |
| kernel claims with an unkilled mutant | 3 of 3 | C8 — **stale, see W3-02** |
| evidence citations outside the tree | **1227** | C10 (152 `/tmp`, 39 absolute, **1030 `untracked/`**) |
| dead / ambiguous glob citations | 5 / 5 | C12 |
| unclassified proposed IDs | 22 | C13 |

Status census command (the 231st row, `CODE.ADR0011-FMT`, carries escaped pipes in its claim
text and needs the `\|` guard; a naive 11-cell split silently drops it — that is why the
command is printed):

```sh
python3 - <<'EOF'
import collections
rows=[l for l in open('docs/epistemic/CLAIMS.md') if l.startswith('| `')]
def cells(l):
    return [x.strip() for x in l.replace('\\|','\x00').strip().strip('|').split('|')]
def norm(s):
    for k in ('FALSE-AS-SCOPED','SUPERSEDED','INTRACTABLE','MEASUREMENT','UNTESTED','CLAIMED','PROVEN','FALSE'):
        if s.startswith(k): return k
    return 'OTHER'
c=[cells(l) for l in rows]
c=[x for x in c if len(x)==11]
print(len(c), collections.Counter(norm(x[4]) for x in c).most_common())
EOF
```

**Believed rows — the re-derivation work list.** PROVEN + CLAIMED = **125**, by tree node:

| node | believed | node | believed |
|---|---|---|---|
| Z-TABLE-FAITHFUL | 18 | Z-R-STATE | 4 |
| Z-AUDIT | 16 | Z-R-TIE | 3 |
| Z-R-MOVE | 13 | Z-STATE-KEY | 3 |
| Z-NONCLAIMS | 12 | Z-TABLE | 3 |
| Z-R-SCORE | 10 | Z / Z-CONVERGE / MONO / FINITE / COMPLETE-ENUM | 2 each |
| Z-CONVERGE-FIX | 10 | Z-SYM / Z-R-SIGN / COMPLETE-PASSES / TABLE-ROUNDTRIP | 1 each |
| Z-TABLE-CONSISTENCY | 8 | | |
| Z-STATE-LEGAL | 6 | | |
| Z-STATE-REACH | 5 | | |

**Rung x artifact coverage (measured, `ls artifacts/ data/` + `git check-ignore`):**

| rung | WZO1 (tracked) | WZO2 | ladder-runnable below 3x3? |
|---|---|---|---|
| 2x2 | `artifacts/oracle-2x2.wzo` | **absent** | no |
| 3x2 | `artifacts/oracle-3x2.wzo` | **absent** | no |
| 3x3 | `artifacts/oracle-3x3.wzo` | `data/oracle-3x3-v2.wzo2` (261 KB, **gitignored**, SHA in `artifacts/SHA256SUMS`, verified matching) | yes |
| 4x3 | `artifacts/oracle-4x3.wzo` (3.19 MB) | **absent** | no |
| 4x4 | `data/oracle-4x4-*.wzo` (gitignored) | `data/oracle-4x4-v2.wzo2` (518 MB, gitignored, SHA in SHA256SUMS) | yes |

`.gitignore:4` ignores `data/`. So three of five rungs have no WZO2 artifact at all, and the
two that do have one hold it in an untracked file. The hash-in-SHA256SUMS mechanism is the
right answer for 518 MB and is already in place; it is the wrong answer for a 261 KB file.

---

## 1. The row set

Seventeen rows, four waves. Row IDs are proposal IDs (`W3-nn`), not kanban IDs — this document
registers nothing.

**Holds discipline.** Waypoint 3's per-row dispositions live in a **shard directory**,
`docs/epics/E1-markovian/wp3/<node>.md`, one shard per tree node, not in one ledger file and
not as a 12th column in `CLAIMS.md`. Reason: `CLAIMS.md` is the single most contended file in
the repo — every absorption writes it — so a 12th column would serialize every Waypoint-3 row
behind every absorption, and a single ledger file would serialize the twelve batch rows against
each other. Sharding by node makes the batch rows **conflict-free by construction**: each holds
exactly its own shards. C15 (W3-01) recovers the anti-subset property that T305 got from
putting the `tree` column inside the register: the **union of shards must equal the register
row set exactly, with no duplicate row**. See OPEN-1 — this diverges from the T305 precedent
and is the one structural choice the operator should rule on before W3-01 is dispatched.

**Disposition vocabulary** (one cell per register row, per DIRECTION §5's "re-derived, demoted,
or retired"):

| cell | meaning |
|---|---|
| `RD:<instrument>@<rung>` | re-derived — the row's assertion re-established at HEAD by a named instrument at a named rung, evidence committed under `docs/evidence/` |
| `DM:<from>-><to>` | demoted — the row cannot carry its status; the new status and the reason |
| `RT?` | retirement **proposed** (retirement is the human's, DIRECTION §1) |
| `RT` | retired — ruled by the operator, row moved to `archives/register/` |
| `NA:<reason>` | live but outside Z's scope, or honestly still untested — the reason is mandatory and is the content |
| `TODO` | not yet dispositioned; the gate requires zero |

### Wave 0 — instruments and fixtures (nothing about any claim's status changes)

---

**W3-01 · `wp3-shards-and-c15` · "Waypoint-3 shards + claimlint C15"**

- **deliverables:** `docs/epics/E1-markovian/wp3/` (one shard per tree node, every cell `TODO`);
  `src/claimlint.zig` (C15); `findings/T<n>-wp3-shards.json`
- **holds:** `src/claimlint.zig`, `docs/epics/E1-markovian/wp3/`
- **needs:** —
- **acceptance:**
  1. C15 prints, in C9's shape, `register rows: N · shard rows: N · TODO: n · invalid: 0 ·
     duplicate: 0 · missing: 0 · extra: 0`.
  2. Report-only at birth (no floor entry) — 231 `TODO` cells must not break the pre-commit hook.
  3. Cell grammar enforced: `RD:`/`DM:`/`RT?`/`RT`/`NA:`/`TODO`; anything else is `invalid`.
  4. **Null control:** all-`TODO` shard set -> `TODO: 231`, `invalid: 0`, exit 0. A C15 that
     cannot distinguish "nothing done" from "all done" is not a gate.
  5. **Seeded-defect controls, red-then-green, three, committed as tests beside C9's:**
     (a) delete one shard row -> `missing: 1`; (b) add a row for a claim ID with no register
     row -> `extra: 1`; (c) blank one cell -> `invalid: 1`.
  6. `zig build test` green; floor unchanged (C1a=0 C1b=0 C2=13 C6=0).
- **worked example:** generate the skeleton, do not type it —
  `bin/weizigo-claimlint --emit-wp3-skeleton docs/epics/E1-markovian/wp3/` then
  `bin/weizigo-claimlint | grep C15` must print `missing: 0 · extra: 0` on the first run. A
  hand-typed 231-row skeleton is a C15 failure shipped as a deliverable.
- **size:** M

---

**W3-02 · `kill-matrix-reconcile` · "Reconcile kill-matrix to the code"**

The machine source and the prose disagree, verified at HEAD:

- `docs/epics/E1-markovian/sprints/verify-battery/pass1/kill-matrix.json`:
  `"total_mutants": 10, "mutants_killed": 3`, with M1/M2/M3/M4 each `"verdict": "survived"`.
- `.../pass1/mutants.md:64`: `**Kill rate: 10 / 10**`, amendment log `:321` crediting T530
  (2026-08-20) with per-mutant red-then-green fixtures for M1/M2/M4 and inverting M3.
- `src/vb_mutants.zig` carries all ten fixtures: M1 `:171`, M2 `:206`, M3 `:254`, M4 `:303`,
  M5 `:349`, M6 `:379`, M7 `:407`, M9 `:445`, M8 `:486`, M10 `:536`.
- `src/claimlint.zig:2083` reads only the JSON, so C8 prints `with at least one unkilled
  mutant: 3` against a tree where the fixtures exist.

The brief's "mutation adequacy 6/10" is a third figure — the T475 reconciliation, superseded by
T530. Three live numbers for one quantity is the defect.

- **deliverables:** `kill-matrix.json`; `mutants.md` (amendment-log entry only);
  `src/claimlint.zig` (C8 report-only -> failing); `tools/hooks/claimlint-floor.json` (`C8: 0`);
  findings JSON
- **holds:** `kill-matrix.json`, `mutants.md`, `src/claimlint.zig`, `tools/hooks/claimlint-floor.json`
- **needs:** W3-01 (same file, `src/claimlint.zig` — one writer per file)
- **acceptance:**
  1. Per-mutant verdict taken **from the run**, not from prose:
     `zig build test 2>&1 | grep -E '^(ok|FAIL).*M(10|[1-9])-'` — the count of green
     kill-verification tests is what `mutants_killed` may say, and the command goes in the
     findings file.
  2. C8 prints `with at least one unkilled mutant: 0`, is flipped to failing, floor `C8: 0`.
  3. **Null control:** restore the pre-row JSON -> C8 prints `3`. Proves C8 reads the file.
  4. **Seeded-defect control:** mark one killed mutant `survived` while its claim is at PROVEN
     -> C8 reports a violation and exits non-zero; restore.
  5. If any of M1-M4 does not go red-then-green on re-run, the verdict is `fail-found` and the
     honest number goes in the JSON. **Do not write 10/10 because `mutants.md` says 10/10** —
     that is the exact error T475 caught in T363's "seven of seven".
- **consequence to record, not to edit silently:** DIRECTION Amendment 2's "T291's 3/10 kill
  rate ... means **seven promotion gates are known-closed**" is a reading of the 3/10 figure.
  At 10/10 that sentence is stale. Per DIRECTION §3 an axiom/amendment change is a **dated
  event**, so this row appends a dated note to Amendment 2 and registers a row; it does not
  rewrite the sentence.
- **worked example:** `python3 -c "import json;d=json.load(open('docs/epics/E1-markovian/sprints/verify-battery/pass1/kill-matrix.json'));print(d['mutants_killed'],'/',d['total_mutants'])"`
  must print `10 / 10` and `bin/weizigo-claimlint | grep -A3 'C8 '` must print `0`.
- **size:** S

---

**W3-03 · `rung-artifacts-v2` · "WZO2 artifacts at 2x2, 3x2, 4x3"**

Without these, "kernel vs fixtures differentially at every rung" is unrunnable below 3x3 —
three of the five ladder rungs have no WZO2 artifact.

- **deliverables:** `artifacts/oracle-2x2-v2.wzo2`, `artifacts/oracle-3x2-v2.wzo2`,
  `artifacts/oracle-4x3-v2.wzo2` (**tracked** — `artifacts/`, not gitignored `data/`);
  `artifacts/SHA256SUMS` updated; `docs/evidence/WP3-RUNGS/build-provenance-2026-08-nn.md`
- **holds:** `src/oracle_v2_build.zig`, `artifacts/SHA256SUMS`
- **needs:** —
- **acceptance:**
  1. Byte-identical rebuild from a named commit (the `CODE.WZO2-BUILD-REPRO` discipline);
     both hashes printed.
  2. Header `w`/`h` read back correct at **3x2 and 4x3** — the transposition control the g3b
     spec §7 names ("on a square board width and height are interchangeable"). A run that only
     covers squares has not tested this.
  3. WZO1 <-> WZO2 value agreement per rung reported as `agreed/total` with `total` stated.
     "Matches" is not a reading.
  4. **Null control:** run the builder twice -> identical bytes.
  5. **Seeded-defect control:** flip one value in a scratch copy -> the WZO1<->WZO2
     differential reports >= 1 disagreement; discard the copy. A differential that passes a
     corrupted copy is blind.
  6. `artifacts/SHA256SUMS` verifies clean: `shasum -a 256 -c artifacts/SHA256SUMS` for every
     line whose path exists.
- **worked example:** at 3x3 the mechanism already works and is the model —
  `shasum -a 256 data/oracle-3x3-v2.wzo2` reproduces the SHA256SUMS line
  `d79c17cd...` exactly (verified at HEAD). Do that for the three new rungs, with the files
  tracked.
- **size:** M · **OPEN-2** if 4x3 v2 exceeds a size the operator will commit.

---

**W3-04 · `instrument-rung-matrix` · "Generated instrument x rung matrix"**

Coverage is uneven and the current map (`docs/.../instrument-coverage.md`, T388) is
hand-maintained. One cell is known wrong by scope and a hand map cannot carry it: T474's N1
records the 4x4 I5 instrument as **placement-only** — `checkI5Wzo2`'s pass-edge path is dead
(SMD1 sentinel), E = 565,402,416 placement-only against ~616M with pass edges — so its E is
not cross-comparable with 3x2/4x3, though the 0/3,455,412 containment reading stands
(placement-only CR is a subset of full-graph CR, so a false PASS is impossible).

- **deliverables:** `tools/wp3-coverage` (generator); `docs/epics/E1-markovian/wp3-coverage.md`
  (generated, never hand-edited); findings JSON
- **holds:** `tools/wp3-coverage`, `docs/epics/E1-markovian/wp3-coverage.md`
- **needs:** W3-03
- **acceptance:**
  1. Every cell is exactly one of `exhaustive(<denominator>)`, `sampled(<n>/<N>)`, `not-run`,
     `blind(<reason>)`. A cell claiming `exhaustive` with no denominator fails the generator.
  2. Generated from run records; regenerating at HEAD twice is byte-identical.
  3. **Null control:** empty run-record set -> every cell `not-run`. No cell may default to
     `exhaustive`.
  4. **Seeded-defect control:** hand-edit one cell to bare `exhaustive` -> generator exits
     non-zero, naming the cell.
  5. The I5 4x4 cell reads `blind(pass-edge path dead, T474 N1)` for the E metric and
     `exhaustive(3,455,412)` for containment — two metrics, two cells, because they have
     different validity.
- **worked example:** `tools/wp3-coverage --check` exits 0 on HEAD's own generated file and
  non-zero after `sed -i '' 's/exhaustive(3,455,412)/exhaustive/' docs/.../wp3-coverage.md`.
- **size:** M

### Wave 1 — the cheap and the negative (parallel; each holds only its own shards)

---

**W3-05 · `wp3-nonclaims` · "Re-verify the 29 negative rows"**

DIRECTION §1: "all 282 rows, **proofs and falsifications alike**". 22 FALSE-AS-SCOPED + 7 FALSE.

- **deliverables:** `docs/epics/E1-markovian/wp3/Z-NONCLAIMS.md` (13 cells) + the negative cells
  in `Z-R-TIE.md`, `Z-TABLE-FAITHFUL.md`, `Z-CONVERGE-FIX.md`, `Z-COMPLETE-ENUM.md`,
  `Z-AUDIT.md`, `Z-TABLE.md`; `docs/evidence/WP3-NONCLAIMS/`; findings JSON
- **holds:** those seven shard files
- **needs:** W3-01
- **acceptance:** per row, the falsifying witness reproduced at HEAD **by an instrument that is
  not the one that first produced it** (duplication-as-oracle); both readings printed. Where no
  second instrument exists the cell is `NA:single-instrument` and says which — it must not read
  as re-derived. **Control per witness:** the same check on a state where the claim is *not*
  falsified must pass. A falsification instrument that fires everywhere has found nothing.
- **worked example:** `GLOBAL.LONGCYCLE` / `QA-013` / `QA-026` share the 3x2 witness
  `(178,0,6,0)`, goban `[B,W,B,_,W,_]`, Black to move, truncation values -3 and -6 against
  fixpoint L=H=-6 — already hand-verified by two independent implementations
  (`docs/evidence/QA-023/c1-witness-handcheck-2026-07-29.md`). Re-run both, print both, and
  print the passing control on a neighbouring non-witness state.
- **size:** L (29 rows, but three witness families cover most of them)

---

**W3-06 · `wp3-measurements` · "Re-read the 51 MEASUREMENT rows"**

A MEASUREMENT row is a datum, not a truth-claim, so it is not "re-derived" — it is **re-read**.

- **deliverables:** the MEASUREMENT cells across 13 shards; `docs/evidence/WP3-MEASUREMENTS/`;
  findings JSON
- **holds:** those shard files (disjoint from W3-05's set where possible; where a shard is
  shared, W3-06 needs W3-05)
- **needs:** W3-01, W3-05 (shared shards)
- **acceptance:** every MEASUREMENT row's number reproduced from a **named command at a named
  commit**, or dispositioned `DM:stale` with the reason. Denominators mandatory. A row whose
  instrument no longer exists is `DM:stale`, not silently carried.
- **worked example:** `GLOBAL.REACH-P4-CENSUS` states 258 / 2,586 / 73,758 / 1,929,038 /
  147,638,298 — re-run `bin/weizigo-reachcensus` and print all five with the command, or write
  `DM:stale` and say which one moved.
- **size:** L

---

**W3-07 · `wp3-untested-honest` · "Disposition the 21 UNTESTED rows"**

No new science. Each UNTESTED row gets `NA:<the specific blocker>` — the blocker is the content.

- **deliverables:** the UNTESTED cells; findings JSON · **holds:** those shards ·
  **needs:** W3-01
- **acceptance:** no cell says "untested" without naming what would change it. Also disposition
  the 3 SUPERSEDED, 1 INTRACTABLE, 1 definition row (`NA:` with the kind).
- **worked example:** `QA-023` / `GLOBAL.H1-MARKOV` ->
  `NA:contrast-generator misses shortest arrival in 93% of states (3x3) / 84.3% budget
  exhaustion (3x2); 0 failures in 404+80 pairs is a lower bound at denominators 24 and 6
  eligible states (T372, docs/evidence/QA-023/c1-contrast-2026-08-05.md)`. That is a
  disposition. "UNTESTED" alone is not.
- **size:** S

---

**W3-08 · `wp3-evidence-commit` · "Commit or demote 46 unbacked PROVENs"**

C3: **46 of 66 PROVEN rows have no committed evidence.** DIRECTION §7: "evidence committed
under `docs/evidence/` or the claim is not proven." C10 shows where it went instead: 1030
citations into gitignored `untracked/`, 152 into `/tmp`, 39 absolute paths. A row with no
committed evidence has nothing to re-derive **against** — this row is therefore a hard
predecessor of the Wave-2 batches, not a cleanup.

- **deliverables:** `docs/evidence/WP3-BACKFILL/` (recovered evidence); the affected shard
  cells (`RD:` where recovered, `DM:PROVEN->CLAIMED` where not); findings JSON
- **holds:** `docs/evidence/WP3-BACKFILL/`, and the shard cells for the 46 rows only
- **needs:** W3-01
- **acceptance:**
  1. Each of the 46 ends `RD:` with a path under `docs/evidence/` **or** `DM:PROVEN->CLAIMED`
     with the reason. No third outcome.
  2. C3 recomputed and printed before and after; the delta equals the number of `RD:` cells.
  3. **Control:** for every recovered evidence file, the number in the register is reproduced
     *from that file* by a printed command. A file that is committed but does not contain the
     number is not evidence.
  4. Demotion is the default, not the failure mode: an unrecoverable PROVEN row is demoted the
     same day, not carried as a TODO.
- **worked example:** the 13 C2 dead links (`untracked/B05-glm.md` reachable from 57 rows,
  `untracked/T07-audit-hypotheses.md` from 32, `untracked/T02-minimax.md` from 23) are the
  worst cluster; CLAIMS.md §"evidence recovery" already records four as **RECOVERED by
  re-implementation** and three as **LOST**. Re-implementation is the affirmative move: recover
  by re-deriving, then commit the re-derivation.
- **size:** L · this row is where Waypoint 3's honesty is won or lost.

### Wave 2 — the believed set, batched by tree node (125 rows)

Every Wave-2 row has the same shape: `RD:`/`DM:`/`RT?` for each believed row in its nodes,
against the kernel plus the battery, at every rung the claim's scope names, with the tree-gap
work its nodes own (`register-tree-map.md` §5) folded in. Each holds only its own shards, so
all seven can run concurrently. All seven `need` W3-01, W3-02, W3-03, W3-04, W3-08.

---

**W3-09 · `wp3-state-nodes` · "Re-derive state + sign nodes (20)"**
Nodes: Z-STATE-LEGAL (6), Z-STATE-REACH (5), Z-R-STATE (4), Z-STATE-KEY (3), Z-SYM (1),
Z-R-SIGN (1). Instruments reused as-is: colex bijection, `bin/weizigo-reachcensus`,
key-agreement (`rules.stateKey` vs `vb_movegen.stateKey`), I2 colour inversion.
**Owns tree-gap §5.2** — Z-STATE-KEY under *adversarial* move selection.
`CODE.KEY-AGREEMENT`'s own caveat: first-legal-move self-play under-covers cycle-intensive ko
positions, so full four-component key parity under adversarial selection is unverified.
**Acceptance:** key-agreement re-run at all five rungs with denominators (4x4's 0/99,133,036
is on record, T345) **plus** an adversarial selector that maximises ko-recapture depth, with
its own null control (the selector on a ko-free slice must find 0) and seeded-defect control
(one flipped key bit -> >= 1 mismatch). **Size:** M.

**W3-10 · `wp3-ruleset-nodes` · "Re-derive ruleset nodes (26)"**
Nodes: Z-R-MOVE (13), Z-R-SCORE (10), Z-R-TIE (3).
**Owns tree-gap §5.1 — Z-R joint well-definedness**, the largest genuinely open node: no row
asserts the axioms *collectively* define a self-consistent computable ruleset, and its [F] ("a
position where two interpretations of the axioms disagree on legality") is mechanized nowhere.
`register-tree-map.md` §5.1 is explicit that T273's differential is **not** the seventeen-copy
comparison AXIOMS §2 promises. **Also owns §5.4** (Z-R-TIE's Markovian-sufficiency test).
**Acceptance:** the seventeen demoted ko copies run as frozen differential fixtures against the
one production `rules.koAfterCapture` at every rung, disagreements enumerated and adjudicated
one by one (epic-01 bug -> catalogue; kernel bug -> the oracle earned its keep). **The
tautology check is mandatory and is the point:** `differential.zig:269-272` once defined
`engineKoNewGeneric` as `return solverKoGeneric(...)` and compared the solver's ko rule against
an alias of itself (GRAND-AUDIT §1a). Before the run counts, assert each fixture's
implementation is not the production one — by symbol identity, not by name. **Size:** L.

**W3-11 · `wp3-converge-nodes` · "Re-derive convergence nodes (16)"**
Nodes: Z-CONVERGE (2), MONO (2), FINITE (2), FIX (10), SEED (1 UNTESTED).
**Owns tree-gap §5.3** — Z-CONVERGE-SEED at 2x2/3x2/3x3: the only seeding row is
`4x4.FP1-C1` and it is UNTESTED; the other sizes have no seeding-provenance evidence at all.
**Acceptance:** L = Phi(L) and H = Phi(H) exhaustively at 2x2/3x2/3x3/4x3 (all fit) and at the
recorded 4x4 denominator (0/95,677,624 KO_SENSITIVE-clear, T343 — re-run or cite with its
command); seeding provenance recorded from build logs per rung, or `NA:` naming what is
missing. Control: a seeded off-by-one in one slot must raise the Bellman violation count.
**Size:** M.

**W3-12 · `wp3-table-nodes` · "Re-derive table nodes (30)"**
Nodes: Z-TABLE (3), Z-TABLE-ROUNDTRIP (1), Z-TABLE-FAITHFUL (18), Z-TABLE-CONSISTENCY (8).
The largest batch and the one holding the falsified-finisher family: `GLOBAL.F1` FALSE,
`GLOBAL.F2` orphaned via `GLOBAL.C3` and confirmed orphaned by ADR-0015/0017/0018.
**Acceptance:** for each of the 18 Z-TABLE-FAITHFUL rows, either the k=1 fixpoint build
satisfies it by construction (ADR-0020: the table *is* the fixpoint, no finisher) — in which
case the cell says so and cites the build — or it is a statement about a finisher-built table
and is `RT?`/`DM:`. **Do not let "satisfied by construction" pass unexamined:** it is a claim
about the builder, and its control is the round-trip plus consistency battery on the actual
committed artifact at each rung. **Size:** L.

**W3-13 · `wp3-complete-nodes` · "Re-derive completeness nodes (3)"**
Nodes: Z-COMPLETE-ENUM (2 believed + 2 FALSE-AS-SCOPED + 1 MEASUREMENT), Z-COMPLETE-PASSES (1).
**Owns tree-gap §5.5** — closure under the kernel move generator at 4x4 — which is **largely
already run**: T363/T383 measured C-A1 `0 / 616,030,190` and C-A2 `0 / 99,133,034` under the
corrected decode, and T474's #2 auditor re-ran both at HEAD with exact reproduction. So this
row is mostly citation and absorption, plus running the same closure at the three new rungs
from W3-03. **Acceptance:** closure at all five rungs with denominators; M8's deleted-entry
fixture (`src/vb_mutants.zig:486`, 0->2 / 0->1 / restore 0/0) re-run as the seeded-defect
control at each new rung. **Size:** S.

**W3-14 · `wp3-audit-nodes` · "Re-derive audit nodes (16)"**
Node: Z-AUDIT (16 believed). These are instrument-validity claims — the rows that say whether
the other rows' instruments can be trusted, so they are the ones a green reading most easily
launders. **Owns tree-gap §5.6** — the #2 auditor on a completed k=1 4x4 build
(`4x4.F3`, `4x4.D3` UNTESTED; T274's residue "our own +1 still awaits the #2 auditor").
**Acceptance:** each Z-AUDIT row's instrument re-run with **both** its controls; any instrument
whose controls do not both fire is `DM:` regardless of its verdict. `CODE.I5-INSTRUMENT-ADJUDICATION`
is the precedent to honour, not to trust: `vb_graph` was wrong on every graph metric while both
instruments' verdicts passed, and defect C **fabricated** the "24 natural violations" at 4x3
that two rows then repeated. **Size:** M.

**W3-15 · `wp3-root-nodes` · "Re-derive Z and the non-claims (14)"**
Nodes: Z (2), Z-NONCLAIMS believed (12). Last, because Z is exactly the conjunction of its
children. **Acceptance:** `GLOBAL.Z` gets `RD:` only if every child node's shard is free of
`TODO` and free of `DM:` on a row Z depends on; otherwise `GLOBAL.Z` stays `CLAIMED` and the
cell names the blocking children. **`GLOBAL.Z` must not be promoted by this row** — Waypoint 3
produces dispositions; promotion past CLAIMED is Amendment-2-gated per claim and is Waypoint 4
business at the earliest. **Size:** S.

### Wave 3 — close

---

**W3-16 · `wp3-ratification-sheet` · "One sheet, all human rulings"**

The **only** operator-facing row. Every `RT?` and every contested `DM:` from Waves 1-2 is
collected into one sheet with a RECOMMEND column filled and a RULING column empty. This is why
no Wave-1/2 row blocks: they propose, they do not wait.

- **deliverables:** `docs/epics/E1-markovian/wp3-ruling-sheet.md`; findings JSON
- **holds:** `docs/epics/E1-markovian/wp3-ruling-sheet.md` · **needs:** W3-05..W3-15
- **acceptance:** one line per proposal carrying (a) current status, (b) family reason, (c) what
  is lost if ruled, (d) live in-register dependents parsed from the `dependents` column filtered
  to non-retired rows, (e) external `docs/` citation count with three example paths, (f) a
  **sole-`e:`-evidence flag** where the row is the only evidence for a still-believed row.
- **worked example:** `retirement-ruling-sheet.md` (T324) is the exact precedent — 116
  proposals, 27 with live dependents, 8 flagged sole-evidence, ruled once and executed by T373
  (339 -> 207 rows, "archive, never delete"). Copy its shape verbatim.
- **size:** M

---

**W3-17 · `wp3-finish-gate` · "Mechanize the Waypoint-3 gate"**

- **deliverables:** `build.zig` (`zig build wp3-gate`); `src/claimlint.zig` (C15 report-only ->
  failing); `tools/hooks/claimlint-floor.json` (`C15: 0`); `docs/epics/E1-markovian/PHASES.md`
  (Waypoint 3 row); findings JSON
- **holds:** `build.zig`, `src/claimlint.zig`, `tools/hooks/claimlint-floor.json`,
  `docs/epics/E1-markovian/PHASES.md`
- **needs:** W3-02 (`src/claimlint.zig`), W3-16
- **acceptance:** §4 below, including its own three controls.
- **size:** M

---

## 2. Sequencing rationale

**What unblocks what.** Only four real edges exist; the rest is file ownership.

1. **W3-01 gates everything** — there is nowhere to record a disposition until the shards and
   C15 exist. This is the same edge DIRECTION Amendment 2 §3 already names: "Phase 3 row
   re-derivation <- the battery exists AND the register-to-tree mapping exists." The mapping
   exists (C9 green, 231 == 231); the *disposition surface* does not.
2. **W3-08 gates all of Wave 2** — 46 of 66 PROVEN rows have no committed evidence. You cannot
   re-derive a claim whose original derivation is not on disk; you can only re-prove it from
   scratch or demote it. Deciding which, per row, before the node batches start is what keeps
   Wave 2 from silently converting "no evidence" into "re-derived".
3. **W3-03 gates W3-04 and every rung-scoped acceptance in Wave 2** — three of five rungs have
   no WZO2 artifact, so "differentially at every rung" is currently unrunnable at 2x2, 3x2 and
   4x3.
4. **W3-15 comes last** by construction: Z is the conjunction of its children.

**`src/claimlint.zig` is the serializer**, not the wave number: W3-01 -> W3-02 -> W3-17 is a
hard chain on one file (one writer per engine file). Everything else in Waves 1-2 is
concurrent because the shard design gives each row disjoint holds. Amendment 2's rule applies
unchanged — the wave number is not a dependency.

**Where Waypoint-2's remaining debt sits.**

- **Mutation adequacy is W3-02, at the front, and is smaller than advertised.** The brief's
  6/10 is the T475 figure; `mutants.md:64,321` records T530 taking it to 10/10 on 2026-08-20
  with all ten fixtures present in `src/vb_mutants.zig`. What is actually broken is that
  `kill-matrix.json` — the single machine source C8 reads — still says 3, so three different
  numbers (3, 6/10, 10/10) are live for one quantity. That is a data-reconciliation row, not a
  science row, and it is cheap.
- **The "seven closed promotion gates" are a reading of 3/10, not a separate debt.** They are
  discharged by W3-02's reconciliation plus its dated note on Amendment 2. No Waypoint-3 row
  waits on them.
- **T430's "unexecuted phase-2 audit" is not Waypoint-2 debt and sits nowhere in this order.**
  Verified at HEAD: the dispatchable row is the malformed `--bundle` row (added
  2026-08-08T13:52:25Z) whose bundle `untracked/T430-phase2-audit.md` **does not exist on
  disk**; the live `T430` in the store is a different, `done` row (argus doctor console); and
  the phase-2 audit it names is the **tool-consolidation sprint's** phase-2 *scope* audit,
  delivered under `T433` at `docs/infra/tool-consolidation/02-scope-audit.md`. It has nothing
  to do with DIRECTION Phase 2 (kernel extraction). `docs/infra/tool-consolidation/02-scope-audit.md:240-244`,
  `docs/status/landmark-assignment-2026-08-19.md:51` and `docs/status/backlog-2026-08-19.md:55`
  all already record this, and T444/T446 already recommended close-with-evidence.
  **Recommendation: close the phantom row as kanban hygiene, outside Waypoint 3.** If the
  operator instead wants a Waypoint-2 *kernel* execution audit — the analogue of
  `phase0-execution-audit.md`, which does not exist for Phase 2 — that is a distinct row and I
  would put it as a `needs W3-02` sibling of W3-14, because it is an instrument-validity
  question. Flagged as OPEN-3 rather than assumed.
- **G3b already did much of Rung 5.** `sprints/g3b-value-correctness/pass0/accept.md` records
  I4 0/95,677,624, C-A1 0/616,030,190, C-A2 0/99,133,034, key-agreement 0/99,133,036, I11 0 at
  every rung, I5 0/3,455,412 — with T474's #2 auditor re-running the two closure figures at
  HEAD. Waypoint 3 must **cite** that work, not redo it; W3-11/W3-13 are sized as citation
  rows for the 4x4 cells and as fresh work only at the new rungs. Two caveats travel with the
  citations: T474's N1 (4x4 I5 placement-only) and the two structurally-impossible
  non-reachable entries in C-A2's denominator.

**What this decomposition deliberately does not do.** It does not promote anything. Waypoint 3
produces dispositions; every promotion past CLAIMED remains gated per claim by Amendment 2
edge 5. "Waypoint 3 complete" and "Z is PROVEN" are different sentences, and L2 (proven 4x4
values) is downstream of the first, not equal to it.

## 3. Controls

Per never-trust-a-green-test, and per DIRECTION §7's "every instrument carries a null control
and a seeded-defect control **before its first reading counts**":

**Reused as-is, already carrying both controls** (do not rebuild these):

| instrument | control status |
|---|---|
| the ten mutants | all ten red-then-green fixtures in `src/vb_mutants.zig` (M1 `:171` … M10 `:536`) |
| I2 colour inversion | kills M5 and M7 |
| I7 DTT sanity | kills M6 |
| C-A1/C-A2 closure | M8 fixture `:486`, 3x3 deleted entry, 0->2 / 0->1 / restore 0/0 |
| I11 move-set | M10 fixture `:536` — null (kernel-vs-SMD1, 0/114 vacuous) **and** seeded (allows-suicide, 1/114). The pair is the point: the null alone would prove nothing |
| BATT-HEALTH | M9 `:445`, compile-time reflection over `vb.Invariant`, fails iff any returns `.skipped` — this is what stops a check from rotting into a skip |
| golden-master baselines | `zig build test` fast path + `zig build battery-sweep`; pass condition is **unchanged from baseline**, never "fails" (Amendment 1) |
| claimlint C9 | the row-set-equality control W3-01's C15 is modelled on |

**New instruments, each owing both controls before its first reading counts:** C15 (W3-01, three
seeded defects), the reconciled C8 (W3-02, null = restore old JSON), the rung differentials
(W3-03), `tools/wp3-coverage` (W3-04, null = empty run-record set), the adversarial key
selector (W3-09), the seventeen-copy ko differential (W3-10).

**Three control disciplines this decomposition treats as load-bearing, each because the project
has already been burned by its absence:**

- **A positive control must exercise the instrument under test, not a parallel one.**
  `differential.zig:269-272` compared the solver's ko rule against an alias of itself
  (GRAND-AUDIT §1a; QA-023 standing rule, `AGENTS.md:146-148`). W3-10's fixture-identity
  assertion is this rule mechanized.
- **A vacuous control is a blind control, and must be recorded as one.** The g3b spec premised
  that 3x2 is the first non-vacuous I5 rung; T363 measured that false for the full
  (colex, side, ko, passes) graph — at 3x2 every passes=0 ko=NONE slot is cycle-reachable, and
  at 4x3 the non-CR slots are all already KO_SENSITIVE. The first genuinely red-then-green rung
  is 4x4. Wave-2 rows must print vacuity, not skip past it.
- **Known-bads are synthetic, never live** (Amendment 1). Live artifacts are **regression
  inputs**: must not *newly* fail. `0c3366f0`'s completeness checks must **pass** — its defect
  was refuted (T266/T277/T279) — and any new failure against it is a finding to adjudicate.

## 4. The finish line

`zig build wp3-gate` — one composite step, exit 0 only when all eight hold. Prose is not the
gate; this is.

1. **C15 == 0** — shard union equals the register row set exactly (`missing: 0 · extra: 0 ·
   duplicate: 0`), `TODO: 0`, `invalid: 0`, `RT?: 0` (every proposed retirement ruled). C15
   failing, floor `C15: 0`.
2. **No `RD:` cell without committed evidence** — for every `RD:` cell, C3 UNBACKED does not
   name that row and its evidence path resolves inside `docs/evidence/`. An unbacked row may
   be `DM:` or `NA:`; it may not be `RD:`.
3. **C8 == 0 and failing**, floor `C8: 0` (Amendment 2 edge 5).
4. **C4 == 0, C5 == 0, C12 dead == 0** — 49 claim IDs cited in `docs/` with no register row is
   incompatible with "every row re-derived": either the ID names a claim (mint the row) or it
   does not (delete the citation). C2 stays at its floor of 13 or lower — the floor never rises.
5. **Coverage is honest** — `tools/wp3-coverage --check` exits 0; no `exhaustive` cell without a
   denominator; no `RD:` cell citing an instrument the matrix marks `blind` at that rung.
6. **Every rung has an artifact with verified provenance** — 2x2/3x2/3x3/4x3/4x4 each have a
   WZO2 artifact whose `artifacts/SHA256SUMS` line verifies on disk; the two too large to track
   additionally name their builder commit.
7. **`zig build test` green and the battery golden-master unchanged from `baselines.md`.**
8. **The ephemeral auditor's verdict is present and pinned** — `docs/audits/<date>-wp3-gate/VERDICT.md`
   exists, its `at HEAD <sha>` line equals `git rev-parse HEAD` at close, its verdict is PASS or
   PASS WITH FINDINGS, and every finding it raises carries a disposition. The auditor is
   human-shaped and ephemeral (DIRECTION §6); the *presence and pinning* of its verdict is what
   the gate can check, and that is all it should claim to check.

**The gate's own controls — because a finish-line gate is the instrument most likely to be
believed while blind.** Ship all three red-then-green before the first green reading counts:

- **known-good:** the tree at the moment the gate is declared satisfied. It must pass.
- **seeded defect A:** revert one shard cell to `TODO` -> must fail on condition 1.
- **seeded defect B:** delete one `RD:` row's evidence file -> must fail on condition 2.
- **seeded defect C:** mark one killed mutant `survived` in `kill-matrix.json` -> must fail on
  condition 3.

A gate that passes all four is not a gate.

**What the gate does not say.** It does not say Z is proven, it does not say the 4x4 values are
correct, and it does not clear L2. It says: every one of the 231 register rows has been
re-derived, demoted, or retired against the requirement tree, by an instrument whose controls
fire, at the rungs its scope names — and that nothing was left as TODO.

## 5. OPEN — assumptions I could not verify

- **OPEN-1 (structural; the one ruling I would ask for before W3-01 is dispatched).** I put the
  dispositions in a shard directory rather than a 12th `CLAIMS.md` column. This **diverges from
  the T305 precedent**, which deliberately put the `tree` mapping *inside* the register ("this
  is the only place the mapping lives inside the register ... cannot silently cover a subset").
  My reason is contention, not disagreement: `CLAIMS.md` is written by every absorption, so a
  12th column serialises all seventeen rows behind unrelated work, and C15's row-set equality
  recovers the anti-subset property without the column. The operator may reasonably prefer the
  in-register column and accept the serialisation. Everything downstream is unaffected either
  way — only W3-01's deliverable changes.
- **OPEN-2.** Whether `artifacts/oracle-4x3-v2.wzo2` is small enough to track. The WZO1 4x3 is
  3.19 MB and is tracked, so the v2 probably is too, but I did not build one to measure it. If
  it is not, it joins the hash-only path with the two large artifacts.
- **OPEN-3.** Whether a **Waypoint-2 kernel execution audit** is owed. No `phase2-execution-audit.md`
  exists (only `phase0-execution-audit.md`), and the "T430 phase-2 audit" in the brief is a
  different sprint's scope audit (§2). I did not assume one is wanted; if it is, it is a
  `needs W3-02` sibling of W3-14.
- **OPEN-4.** Row sizes are my estimates from row counts and instrument reuse, not from
  measured wall-clock on comparable rows. The two I would most expect to be wrong are W3-08
  (46 evidence recoveries, each a small research task) and W3-10 (the seventeen-copy
  differential, whose disagreement count is unknown until it runs — every disagreement is a
  finding to adjudicate, so the row could fan out).
- **OPEN-5.** I did not verify that `src/oracle_v2_build.zig` can emit WZO2 at 2x2/3x2/4x3. It
  runs fixpoints at 2x2/3x2/3x3/4x4 (`:83-143`) and its writer path is hardcoded to
  `oracle-4x4-v2.wzo2` (`:543`). W3-03 may therefore include a small generalisation of the
  writer, which would change its size from M and add `src/oracle_v2_build.zig` to a longer hold.
- **OPEN-6.** Whether `RT` executions should move rows to `archives/register/` as T373 did
  (339 -> 207) or leave them live with the marker. T373's precedent says move, with epitaphs,
  "archive, never delete" — I assumed move, and W3-16's sheet assumes the operator rules once
  for the whole batch.
- **OPEN-7.** The 1030 `untracked/` evidence citations (C10) are far larger than W3-08's 46
  rows; I scoped W3-08 to the 46 unbacked **PROVEN** rows only. Whether Waypoint 3 owes the same
  treatment to CLAIMED and MEASUREMENT rows citing `untracked/` is a scope question I could not
  resolve from DIRECTION §7, which speaks only of "proven".
