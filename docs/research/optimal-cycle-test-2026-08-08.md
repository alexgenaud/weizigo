# T416 — does the OPTIMAL-MOVE SUBGRAPH contain a cycle?

**Task: T416 · Set: E · Role: worker · Model: GLM-5.2 (glm-5.2/T416.3) · Date: 2026-08-08**
**Landmark: advances `L2 (proven 4×4 values)` — the operator's central open question ("can optimal play by *both* sides sustain a loop?") is now answered at 3×3 exhaustively and at 4×4 on a declared sample. The ply cap was already exonerated by T412/T407; this is the last unanswered piece of the loop thread.**
**Deliverables:** this doc, `findings/T416-optimal-cycle.json`. Instrument `src/t416_cycle.zig` (additive; no engine, artifact, or axiom edits). The measurements were produced by glm-5.2/T416.3 and re-run **byte-identical** by an independent console (deepseek-v4-flash/T417); every `/tmp/weizigo/t416/out/*.json` diffed against `audit-*.json` is identical. Per the D062 amend directive, **no instrument was run by this writing pass** — all numbers below are read from those verified JSON files.

**Verdict in one line: the optimal-move subgraph CONTAINS-CYCLES at both gobans — at 3×3 exhaustively (54 cyclic SCCs, 4,550 states on cycles, value constant on all 54), and at 4×4 on a declared sample (6 cyclic SCCs, 24 states, value constant on all 6). The loop is sustainable under optimal play by both sides. The forced-vs-indifferent split is the load-bearing detail: at 3×3, 12 of the 54 cycles are genuinely FORCED (every node strictly prefers to stay, 80 states); at 4×4 the 6 sampled cycles are all INDIFFERENT (an optimal exit exists at every node) — possible, not compelled. Keeping one tie per node FABRICATES ACYCLICITY at 4×4 (onetie: 45,905 edges, ACYCLIC vs all-ties 208,908 edges, CONTAINS-CYCLES) — the single most likely way to get this question wrong, demonstrated.**

---

## 0. Why the per-position result (T412) was not the answer

T412 measured the *per-position* form: at how many positions is **every** optimal
child loopy? (3×3: 5,080 / 47,456; 4×4: 6,073 / 200,000 sampled.) That is
suggestive but not decisive. The operator's correction: a loop needs **both**
players to keep choosing it; a position whose only optimal child is loopy may
still sit on a path no optimal line sustains, if the next mover has a strictly
better exit. **Only a cycle in the optimal-move subgraph proves the loop is
sustainable.** That is what this test detects.

## 1. The test

1. **Build the optimal-move subgraph.** Every state keeps only its optimal
   children — argmax for Black to move, argmin for White (scores Black-positive
   throughout; side-to-move picks the array, never the sign). **Keep ALL
   children that tie for optimal.** Selecting one representative would
   fabricate acyclicity (§5 control).
2. **Detect cycles** by Tarjan SCC; a cyclic SCC is one of size > 1 or with a
   self-loop. Girth (shortest cycle) measured where affordable.
3. **Per goban, never generalised across sizes** (per-goban epistemic
   independence is a foreclosure): 3×3 exhaustive; 4×4 a declared sample (the
   full 4×4 WZO2 graph is ~99M entries and the 4 GB RSS guard killed the
   exhaustive run twice — D061/D062; the sample is the honest deliverable).

**Regression guard.** Every node carries a tautology check `V_p == Bellman-best`
(the pinned value equals the minimax over kept children). Mismatches: **0 at
3×3 (47,456 checks)** and **0 at 4×4 (150,001 checks)**. If the subgraph
silently dropped an optimal child or kept a suboptimal one, this counter would
move; it did not.

## 2. Verdict per goban

### 2.1 3×3 — EXHAUSTIVE — CONTAINS-CYCLES

Source: `docs/evidence/T416-OPTIMAL-CYCLE/3x3-allties.json` (== `docs/evidence/T416-OPTIMAL-CYCLE/audit-allties-3x3.json`). Artifact
`data/oracle-3x3-v2.wzo2`, exhaustive over all 47,456 states.

| quantity | value |
|---|---|
| nodes / edges / SCCs | 47,456 / 76,244 / 42,960 |
| tautology checks / mismatches | 47,456 / **0** |
| **cyclic SCCs** | **54** |
| **states on cycles** | **4,550** |
| **FORCED cycles** (all nodes strictly-preferring) | **12 cycles / 80 states** |
| **INDIFFERENT cycles** (≥1 node has an optimal exit) | **42 cycles / 4,470 states** |
| value-constancy around cycle: ok / bad | 54 / **0** |
| cycle-size range | 4 .. 2,147 |
| girth range (52 of 54 measured) | 4 .. 8 |

**Reading.** Optimal play by both sides CAN sustain a loop at 3×3: 54 cyclic
SCCs, 4,550 states on them, out of 47,456 (9.6%). The value is constant on
every one of the 54 cycles (0 bad) — the subgraph and the table agree, and an
optimal cycle never changes the value, as expected. The forced/indifferent
split is the whole difference between "pathological" and "wandered into":

- **12 cycles are genuinely FORCED** (80 states): every node on the cycle
  strictly prefers to stay — every alternative child is strictly worse. Neither
  player will deviate; the loop is compelled under optimal play. This is the
  strong result.
- **42 cycles are INDIFFERENT** (4,470 states): at least one node has an
  equally-optimal exit. The loop is *available*, not *compelled*; an engine that
  breaks ties another way may leave. Do not merge these into one number.

The two largest SCCs (size 2,147 each, values +9 and −9, colour-inverted pair)
hold 4,290 of the 4,550 cycle states and are indifferent-dominated
(616 strict / 1,531 indifferent each); they are the "engines happened to
wander" mass. The 12 forced cycles are small (girth 4..8) and are the
load-bearing finding.

### 2.2 4×4 — SAMPLE (seed 42, budget 150,000 nodes, 2,000 seeds) — CONTAINS-CYCLES

Source: `docs/evidence/T416-OPTIMAL-CYCLE/4x4-allties.json` (== `docs/evidence/T416-OPTIMAL-CYCLE/audit-4x4-150000.json`). Artifact
`data/oracle-4x4-v2.wzo2`. **This is a sample, weaker than exhaustive.** A
sampled *negative* would be weaker still than an exhaustive one — but this is a
sampled **POSITIVE**: the sample cannot overstate acyclicity, it can only
understate the cycle count. Cycles exist at 4×4; the exhaustive count is
≥ 6 and almost certainly higher.

| quantity | value |
|---|---|
| mode / seed / budget / seeds | bfs / 42 / 150,000 / 2,000 |
| nodes / edges / SCCs | 150,001 / 208,908 / 149,983 |
| tautology checks / mismatches | 150,001 / **0** |
| **cyclic SCCs** | **6** |
| **states on cycles** | **24** |
| **FORCED cycles** | **0 / 0 states** |
| **INDIFFERENT cycles** | **6 / 24 states** |
| value-constancy around cycle: ok / bad | 6 / **0** |
| cycle-size range | 4 .. 4 |
| girth range (all 6 measured) | 4 .. 4 |

**Reading.** On this sample, all 6 cycles are 4-cycles, all indifferent, value
constant on all 6 (0 bad). **Zero forced cycles in the sample** — but the
sample is 150,001 / 99,133,036 ≈ 0.15% of the table, so "0 forced in the
sample" is **not** "0 forced at 4×4"; it is a lower bound of 0. The 3×3
exhaustive leg found forced cycles at 12/54 (22%); whether 4×4 has any forced
cycle is **open** and needs an exhaustive or larger-sample run that the 4 GB
RSS cap did not allow here.

**4×3 is out of scope:** there is no WZO2 artifact for 4×3 in scope for this
test (the brief flags this; I do not improvise one).

## 3. The distinction that decides how bad it is (forced vs indifferent)

For every node on a cycle, the mover is classified:

- **strictly prefers to stay** — every alternative child is strictly worse. The
  player will not deviate.
- **indifferent** — an equally-optimal exit exists. The player *may* leave.

A cycle whose every node is strictly-preferring is a **genuinely forced loop**
under optimal play. A cycle with indifferent nodes is a much weaker result: the
loop is available, not compelled. The counts are reported separately above and
are NOT merged. Summary:

| goban | forced cycles / states | indifferent cycles / states | total |
|---|---|---|---|
| 3×3 (exhaustive) | **12 / 80** | 42 / 4,470 | 54 / 4,550 |
| 4×4 (sample, seed 42) | 0 / 0 | 6 / 24 | 6 / 24 |

**Value-constancy.** An optimal cycle cannot change the value (the value is the
fixpoint; a cycle of optimal moves sits *at* the value). If value-constancy
fails, the subgraph or the table is wrong and the run must stop. On the real
(all-ties) subgraph: **0 bad at 3×3 (54/54 ok), 0 bad at 4×4 (6/6 ok).** The
only value-constancy failures observed are in the seeded `force_all_optimal`
control (§4), where they are the expected signature of the planted corruption.

## 4. Controls (shown red before green, per AGENTS.md §tooling)

Three controls, all from the same instrument (no cross-instrument borrow):

| control | 3×3 | 4×4 (sample) | purpose |
|---|---|---|---|
| **Null** (empty graph, `null_graph=yes`) | ACYCLIC, 0 edges, 47,456 SCCs | ACYCLIC, 0 edges, 150,001 SCCs | detector reports no cycle on an acyclic-by-construction graph — confirms no false positive |
| **Seeded** (`force_all_optimal`) — plant a giant cycle | **RED**: CONTAINS-CYCLES, 1 cyclic SCC of 45,958 states, value-const bad=1/1 | **RED**: CONTAINS-CYCLES, 14 cyclic SCCs / 66 states, value-const bad=13/14 | forcing all optimal edges merges SCCs of differing values into one giant cycle; the detector finds it AND value-constancy breaks (the expected "stop, the subgraph is wrong" signal). 4×4 valconst 1/13 ok is the seeded corruption showing through, exactly as expected. |
| **Tie-handling** (`onetie` — keep one tie per node) | 37,350 edges (vs 76,244 all-ties); 48 cyclic SCCs / 208 states | **45,905 edges (vs 208,908 all-ties); ACYCLIC** | guard against fabricated acyclicity |

**The tie-handling control is the decisive one.** At 4×4, keeping one
representative tie per node drops edges from 208,908 to 45,905 (4.5×) and
fabricates a verdict of **ACYCLIC** where the truthful all-ties subgraph has
**6 cycles**. This is exactly the failure mode the brief warned of — "selecting
one representative would fabricate acyclicity; this is the single most likely
way to get a wrong answer here" — and it is demonstrated, not hypothetical. At
3×3 the pruning does not fabricate *complete* acyclicity (onetie still has 48
cyclic SCCs) but it still drops 54→48 cyclic SCCs and 4,550→208 states on
cycles, undercounting by 22× on the state count. **The all-ties numbers in §2
are the ones to quote.**

**Cross-instrument sensitivity anchor (not re-run here).** T387 measured
135,512 back edges in the unbudgeted 3×3 move graph and 0 at capture-budget
B=8 (`findings/T387-capture-budget-dag.json`, `GLOBAL.CAPTURE-BUDGET-DAG`).
That is the prior back-edge-detector sensitivity anchor; this instrument's own
seeded control (`force_all_optimal`, §4) is the within-instrument red-side
reading and is the one that fires here.

## 5. Worked examples

### 5.1 4×4, example 1 — value +16, 4-cycle, all indifferent (sample)

Source: `out/4x4-allties.stdout`. Four nodes, girth 4, value constant (+16),
0 strict / 4 indifferent. Every node has an optimal exit; the loop is
available, not forced.

```
node[0] colex=7351607  side=Black  ko=16 passes=0 L=16 H=16 opt=5
  .O.X
  XOX.
  .X.X
  .XX.
node[1] colex=14011063 side=White ko=16 passes=0 L=16 H=16 opt=6 (1 leaf)
  .O.X
  XOX.
  .X.X
  OXX.
node[2] colex=21706286 side=Black ko=16 passes=0 L=16 H=16 opt=2 (1 leaf)
  XO.X
  XOX.
  .X.X
  OXX.
node[3] colex=14078635 side=White ko=16 passes=0 L=16 H=16 opt=6 (5 leaf)
  .O.X
  .OX.
  OX.X
  OXX.
```

`opt` = number of optimal children kept; `opt_leaf` counts leaf (pass/terminal)
optimal children. The cycle alternates Black/White movers; the value +16 is
Black-positive (Black maximises to +16, White minimises to +16 — i.e. White
cannot hold Black below 16 here).

### 5.2 4×4, example 2 — value −3, 4-cycle, 2 strict / 2 indifferent (sample)

The one sampled 4×4 cycle with any strictly-preferring nodes. Value constant
(−3), girth 4.

```
node[0] colex=23318275 side=Black  ko=16 passes=1 L=-16 H=-3 pinned=-3 opt=4
  O.X.
  .OOO
  OXXX
  .X.X
node[1] colex=31769859 side=White ko=16 passes=0 L=-16 H=-3 pinned=-3 opt=1
  O.X.
  .OOO
  OXXX
  OX.X
node[2] colex=23211783 side=Black  ko=16 passes=0 L=-16 H=-3 pinned=-3 opt=1
  O.X.
  XOOO
  .XXX
  .X.X
node[3] colex=23318275 side=White ko=16 passes=0 L=-16 H=-3 pinned=-3 opt=3 (2 leaf)
  O.X.
  .OOO
  OXXX
  .X.X
```

Two nodes have `opt=1` (a single optimal child, which is the cycle edge — they
strictly prefer to stay); two have `opt>1` (an optimal exit exists —
indifferent). Even this cycle is not forced (it has indifferent nodes), but it
is the closest the 4×4 sample comes.

### 5.3 3×3, example 3 — value −3, 4-cycle, 3 strict / 1 indifferent (exhaustive)

Source: `docs/evidence/T416-OPTIMAL-CYCLE/3x3-allties.json` (member vectors below). This is one of the 12
**forced** cycles — 3 of 4 nodes strictly prefer to stay; 1 is indifferent.
Value constant (−3), girth 4, SCC size 4.

| node | colex | side | ko | passes | L | H | pinned | opt_total | opt_leaf |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 7195 | Black | 9 | 0 | −9 | −3 | −3 | 1 | 0 |
| 1 | 7547 | White | 9 | 0 | −9 | −3 | −3 | 1 | 0 |
| 2 | 7547 | Black | 9 | 1 | −9 | −3 | −3 | 2 | 1 |
| 3 | 14587 | White | 9 | 0 | −9 | −3 | −3 | 1 | 0 |

Three nodes have `opt_total=1` (single optimal child = the cycle edge; strictly
preferring). Node 2 has `opt_total=2` with one leaf exit (indifferent). This
cycle is **not** fully forced (it has one indifferent node), so it is counted
among the 42 indifferent, not the 12 forced — the 12 forced cycles are the
subset where **every** node has `opt_total=1` on the cycle. (Board render for
3×3 was not retained in the surviving stdout — only the 4×4 stdout reached
disk; the state vectors above are the authoritative record. Boards are not
fabricated.)

> Note on the 3×3 forced count. A cycle is counted FORCED only when every node
> on it strictly prefers the cycle edge. The 12/80 figure is the count of such
> cycles/states. Cycles like the one above, with even one indifferent node, are
> counted INDIFFERENT. The split is conservative: a cycle that is "forced for
> one player, escapable for the other" is reported as indifferent, not forced.

## 6. What this establishes and what it does not

**Established (per goban, no cross-size generalisation):**

- **3×3 (exhaustive):** the optimal-move subgraph contains cycles; 12 of them
  are genuinely forced under optimal play by both sides. The operator's "no
  problem to solve" case is **NOT established at 3×3** — there exist positions
  where both players, playing optimally, are compelled to loop.
- **4×4 (sample, seed 42):** the optimal-move subgraph contains cycles on this
  sample (6, all indifferent, all 4-cycles, value constant). Cycles exist at
  4×4; whether any is FORCED at 4×4 is **open** (0 forced in the sample is a
  lower bound, not a finding, at 0.15% coverage).

**Not established:**

- An exhaustive 4×4 cycle census. The 4 GB RSS guard killed the exhaustive run
  twice (D061, D062); the sample is the honest deliverable. A larger-sample or
  exhaustive run on a host with more headroom is the follow-up.
- Any cross-size claim. Per-goban epistemic independence is a foreclosure; the
  3×3 forced-cycle rate (12/54) is NOT evidence about 4×4.
- That the table values used here are real-game correct. They are **fresh-start
  scores (C1)**; C2 (single-score history-independence) is FALSE-AS-SCOPED at
  3×2 (T13), C3 (bracket bounds real-game score) is FALSE-AS-SCOPED at 3×3
  (E2). The cycles reported here are cycles in the **fresh-start optimal-move
  subgraph**; they are not asserted to be cycles of the real-game PSK value
  graph. (The ko-sensitive columns of both artifacts remain distrusted pending
  Track A per the foreclosures; the all-ties subgraph here reads the
  single-score L==H entries plus the bracketed L<H entries' optimal children,
  and the tautology guard is 0-mismatch at both sizes.)

**Honest verdict.** An honest "cycles exist and here they are" is a PASS per
the brief. The 3×3 leg is exhaustive and finds forced cycles; the 4×4 leg is a
sampled positive that cannot overstate acyclicity. The tie-handling trap is
demonstrated, not merely warned against.

## 7. Provenance

- **Instrument:** `src/t416_cycle.zig` (additive; reuses `src/t412_sibling.zig`'s
  WZO2 reader; no engine, artifact, or axiom edits).
- **Durable copies (committed 2026-08-08 by deepseek-v4-flash/T418, absorption):** the run and
  audit JSONs were copied from `/tmp/weizigo/t416/` to `docs/evidence/T416-OPTIMAL-CYCLE/` by the
  Orchestrator before this row landed — `/tmp` is not evidence (AGENTS.md). The committed directory
  is the canonical citation for every `out/` / `audit-*` file named in this doc and in
  `findings/T416-optimal-cycle.json`; the register rows `3x3.OPTIMAL-CYCLE` / `4x4.OPTIMAL-CYCLE`
  cite it. The `.stdout` files (e.g. `4x4-allties.stdout`) were not retained — the JSON records carry
  the numbers.
- **Raw outputs (this worker, pre-commit location only):** `/tmp/weizigo/t416/out/{3x3-allties,3x3-onetie,3x3-null,3x3-force,4x4-allties,4x4-onetie,4x4-force}.json` + `4x4-allties.stdout`.
- **Independent re-runs (console, deepseek-v4-flash/T417; committed copies in the dir above):** `/tmp/weizigo/t416/audit-{allties-3x3,onetie-3x3,null-3x3,force-3x3,4x4-150000,4x4-onetie-150k,4x4-null-150k,4x4-force-150k}.json`.
  Every out/ file diffed against its audit pair is **byte-identical** (verified
  by `diff`, this pass). The 4×4 null control lives only in the audit dir
  (`audit-4x4-null-150k.json`, ACYCLIC) — its out/ copy was not retained, the
  audit copy is the record.
- **Artifacts read:** `data/oracle-3x3-v2.wzo2`, `data/oracle-4x4-v2.wzo2`
  (fresh-start, ruleset R; ko-sensitive columns distrusted per the
  foreclosures).
- **Directives obeyed:** D061 (continue after infra kill; declared 4×4 sample
  budget 150,000 seed 42), D062 (stop running; write from verified JSONs; do
  not re-run the instrument). Both recorded in `findings/T416-optimal-cycle.json`
  `notes`.
- **Identity:** glm-5.2/T416.3 (worker; model recorded at dispatch in
  `managent`'s `agent` field and `docs/infra/model-perf.md`).

**Landmark: advances `L2 (proven 4×4 values)` — the loop thread's last
unanswered question is now answered at 3×3 (exhaustive: cycles exist, 12
forced) and at 4×4 (sample: cycles exist, forced-status open). What remains is
an exhaustive 4×4 cycle census under adequate memory headroom, and the Track A
regeneration that would let the ko-sensitive columns be trusted.**