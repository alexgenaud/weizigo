# The full loopy-child partition, and the depth-2 question

**Task:** T419 · **Role:** worker · **Model:** deepseek-v4-flash (deepseek-v4-flash/T419) ·
**Date:** 2026-08-08
**Landmark:** advances `L2 (proven 4×4 values)` — the operator's five counts
asked on 2026-08-08 are now all answered. T412 answered two of them exactly,
conflated two into one bucket, and never measured the fifth; this row closes
the gap. Everything below reconciles **exactly** with T412's published table
on the same sample, so the new buckets are not a changed classifier — they
are the same classifier split finer.

---

## The five counts, led

1. **Forced-loop positions** (every optimal child is loopy) — already T412's:
   **5,080 / 47,456** at 3×3; **6,073 / 200,000** at 4×4. Reproduced exactly.
2. **Finer distribution** — already T412's: one-of-one **4,420 / 5,487**,
   all-loopy k≥2 **660 / 586**. Reproduced exactly.
3. **Loopy children exist, none optimal** (the operator's reassuring case —
   a loop is reachable but optimal play declines it): **9,480** at 3×3;
   **23,459** at 4×4. *New.*
4. **No loopy children at all**: **32,448** at 3×3; **169,606** at 4×4. *New.*
   (3)+(4) = the published no-loop bucket **exactly** (41,928 / 193,065).
5. **The depth-2 question** (sequential optimal loopy paths for both
   players): permissive/forced at depth 1–3, in §3. *New.*

---

## 0. What was already measured — and how this row extends it

`docs/research/loop-onset-2026-08-07.md` §Q1 classified each non-terminal
parent's children as **optimal** (pinned value == Bellman best) and **loopy**
(`L < H`, the value-ambiguity marker), and reported forced-loop / partial /
no-loop. The operator's five counts were: (1) the forced-loop count, (2) the
finer distribution, (3)+(4) the two halves of the no-loop bucket, (5) the
depth-2 question. T412 answered (1) and (2) exactly; (3)+(4) were conflated
under "no-loop" (41,928 / 193,065); (5) was never measured — it sits between
T412's depth-1 sibling test and T416's ∞-depth cycle test.

**Instrument.** `src/t419_taxonomy.zig` (additive; reads WZO2 only; no
engine, artifact, or axiom edits). It re-derives T412's buckets on the same
sample (3×3 exhaustive; 4×4 reservoir 200,000, seed 42, reproduced verbatim
from T412's code) — the reconciliation with the published table is the
regression check — then splits no-loop and computes depth-1..3 per
parent. The loopy criterion is `L < H` kept verbatim; no graph criterion is
substituted. 17 unit tests were written first (red against stubs, then
green) and wired into `zig build test` (`build.zig`); the wired test
artifact is absent from the suite's failed-command list and passes
standalone — the suite's remaining failures are pre-existing on this host
(the repo suite is known-red per `AGENTS.md`).

---

## 1. Gap 1 — the no-loop bucket, split

`no-loop` means "no **optimal** child is loopy". It conflated two different
epistemic states:

- **(a) positions with loopy children, none of them optimal** — a loop is
  reachable, but optimal play declines it. *The operator's reassuring case:*
  this is the evidence that the value system actively steers away from loops.
- **(b) positions with no loopy children at all** — nothing to decline.

| goban | no-loop (T412) | **(a) loopy children, none optimal** | **(b) no loopy children** | reconciliation |
|---|---|---|---|---|
| 3×3 (exhaustive, 47,456) | 41,928 | **9,480 (22.6 % of no-loop; 20.0 % of all parents)** | **32,448 (77.4 %)** | 9,480 + 32,448 = **41,928 ✓** |
| 4×4 (sample 200,000) | 193,065 | **23,459 (12.2 %; 11.7 % of parents)** | **169,606 (87.8 %)** | 23,459 + 169,606 = **193,065 ✓** |

The reconciliation is exact at both sizes — the classifier did not change
between T412 and this row.

**Reading.** The operator's reassuring case is real and large: at 3×3,
9,480 positions (a fifth of all parents) have a loopy move available that
optimal play declines. The value system does steer away from loops — *at
these positions*. Combined with the 5,080 forced-loop positions, the total
with any loopy child at all is 9,480 + 448 (partial) + 5,080 (forced) =
15,008 of 47,456 (31.6 %); optimal play declines the loop at 63 % of those
(9,480/15,008) and is forced into it at 34 %.

### The margin: how decisively is the loop declined?

For each (a)-position: **margin = | optimal value − best loopy child value |** —
how much worse the best loopy child is than the optimal value. A margin of 1
means optimal play barely declines the loop; a large margin means it is
decisively rejected. Distribution, not a mean:

**3×3** (n = 9,480; median **9**, mean 8.55, range 1–12):

| margin | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| count | 288 | 260 | 56 | 40 | 224 | 2,196 | 216 | 644 | 2,032 | 808 | 0 | 2,716 |

**4×4** (n = 23,459; median **15**, mean 13.94, range 1–26):

| margin | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| count | 602 | 571 | 454 | 312 | 192 | 181 | 79 | 392 | 56 | 1,514 | 914 | 1,169 | 3,099 |

| margin | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| count | 907 | 1,568 | 5,364 | 1,478 | 911 | 2,047 | 804 | 320 | 474 | 5 | 34 | 0 | 12 |

**Reading.** The distribution is decisive-rejection-heavy, not barely-decline:
at 3×3, 8,612 of 9,480 (90.8 %) decline by a margin ≥ 6, and the mass peaks
at margins 6, 9, 12 (the score lattice's structure); only 548 (5.8 %) decline
by 1–2 points. At 4×4 the same shape with a taller tail: 21,328 of 23,459
(90.9 %) decline by margin ≥ 6; 1,173 (5.0 %) by 1–2. So where optimal play
declines a reachable loop, it mostly rejects it by a wide margin — the loop
is not a near-tie alternative at these positions. (The 1–2-point tail is the
small set where the loop is a genuine near-alternative, worth a closer look.)

---

## 2. Gap 2 — the depth-2 question (permissive and forced)

> *"How many positions have two sequential optimal loopy paths for both
> players?"*

For each position `p` (mover X): count positions where **X has an optimal
loopy move to `q`**, AND **the opponent Y at `q` also has an optimal loopy
move to `r`** (and X again at `r` for depth 3). Two forms:

- **permissive** — *some* optimal move at each step is loopy (a loop is
  available);
- **forced** — *every* optimal move at each step is loopy (no escape at any
  step). This is the number that matters: a lower bound on how deep a
  compelled loop can run.

### 3×3 (exhaustive, 47,456 parents)

| depth | permissive (a loop is available) | forced (no escape) |
|---|---|---|
| 1 | 5,528 (= 5,080 forced + 448 partial, **exact** T412 reconciliation) | 5,080 (= T412's forced, **exact**) |
| 2 | **5,504** | **4,800** |
| 3 | **5,408** | **3,656** |

### 4×4 (sample of 200,000 — *every figure here is a sample statistic*)

| depth | permissive | forced |
|---|---|---|
| 1 | 6,935 (= 6,073 + 862, **exact** T412 reconciliation) | 6,073 (= T412's forced, **exact**) |
| 2 | **6,722** | **5,612** |
| 3 | **6,535** | **4,867** |

Monotonicity holds at both sizes: permissive decays 5,528 → 5,504 → 5,408
(3×3) and 6,935 → 6,722 → 6,535 (4×4); forced decays 5,080 → 4,800 → 3,656
and 6,073 → 5,612 → 4,867. The reconciliation flags in the JSONs are all
true.

**Reading.** The compelled loop decays slowly. At 3×3, 5,080 positions force
optimal play into a loop for one ply; 4,800 of them still force it two plies
deep (both players, every optimal move); 3,656 force it three plies deep.
The decay rate is mild (72 % of depth-1 survivors still forced at depth 3) —
the forced-loop region is not a thin one-ply veneer over an escape.

### Reconcile with T416 (the row's strongest control)

T416 found, at 3×3 exhaustive, **12 forced cycles / 80 states** (every node
on the cycle has no equally-optimal move that leaves it). The brief's gate:
**the depth-3 forced count must be ≥ 80**, because every state on a forced
cycle satisfies the depth-3 forced condition.

Why the condition holds: a *forced* cycle cannot contain an `L == H` node —
an `L == H` node has a value-preserving path to termination (finite DTT),
which must eventually leave the cycle, making some node on it indifferent.
So every node on a forced cycle is loopy, and every optimal child of it is
also on the cycle (strictly-prefers-to-stay) and loopy — hence forced at
every depth.

**Result: depth-3 forced = 3,656 ≥ 80 ✓** — the gate passes by 45×. (Depth-3
permissive, 5,408, also covers T416's full 4,550 states-on-cycles, consistent
with the cycles lying in the loopy region.) The 3,656 is a *lower bound* on
how deep a compelled loop can run — it far exceeds the 80 forced-cycle
states because it also counts positions on 3-ply all-loopy corridors that
may still have an exit at ply 4.

---

## 3. Controls (shown red before green, per `AGENTS.md` §tooling)

| control | instrument reading | purpose |
|---|---|---|
| **Tautology guard** (structural) | 0 / 47,456 (3×3), 0 / 200,000 (4×4) | the child enumerator and value computation agree with the table's fixpoint — same guard T412 reported |
| **Seeded `force_loopy`** (every child loopy) | **RED**: forced = 47,456/47,456 (100 %) at 3×3, depth-1 permissive = forced = 100 %, no_loop = 0 — matches T412's published force_loopy control (47,456/47,456 at 3×3, 50,000/50,000 at 4×4, cited from `docs/evidence/T412-SIBLING-DTT/`, not re-run at 4×4) | the detector fires universally when the data says so; the real counts are a genuine subset |
| **Null `none_loopy`** (no child loopy) | forced = 0, partial = 0, no_loop = 47,456 all in (b), depth-1..3 = 0 | the detector reads exactly zero when nothing is loopy |

Two notes, both honest:

1. **The null control caught a real defect.** During development the
   `none_loopy` flag was not wired into the classifier and the "null" run
   showed real data (forced 5,080, margins populated). The null control
   exposed it; it was fixed and re-verified before any reading was taken.
   This is the tooling-pipeline discipline working as intended.
2. **Seeded depth-2/3 read < 100 %** under `force_loopy` (3×3: perm2 37,350,
   forced2 30,432, perm3 37,094, forced3 25,918 of 47,456). This is correct
   semantics, not a detector miss: an optimal line that ends in a terminal
   leaf (double-pass) genuinely cannot continue — the "opponent at q" has no
   moves. Depth-1 reads 100 %; the real-run leaf cases are real.

---

## 4. Synthesis

**The five counts (with denominators), per size:**

| count | 3×3 (exhaustive, 47,456) | 4×4 (sample 200,000) |
|---|---|---|
| forced-loop (every optimal child loopy) | 5,080 | 6,073 |
| one-of-one subset | 4,420 | 5,487 |
| loopy children exist, none optimal **(a)** | **9,480** | **23,459** |
| no loopy children at all **(b)** | **32,448** | **169,606** |
| depth-2 forced / permissive | **4,800 / 5,504** | **5,612 / 6,722** |
| depth-3 forced / permissive | **3,656 / 5,408** | **4,867 / 6,535** |

**Known (this row).**
1. The no-loop bucket is two very different things, and the split is exact:
   at 3×3, 9,480 of 41,928 no-loop positions have a reachable-but-declined
   loop (the reassuring case); 32,448 have nothing to decline. Same shape,
   smaller share, at 4×4 (23,459 / 193,065).
2. Where optimal play declines a reachable loop it mostly does so
   decisively: median margin 9 (3×3) / 15 (4×4); ~91 % of the declined loops
   are rejected by margin ≥ 6, and only ~5 % are within 1–2 points of
   optimal.
3. The depth ladder shows a *compelled* loop decays slowly: 5,080 → 4,800 →
   3,656 at 3×3 — at 3,656 positions every optimal move is loopy for three
   full plies by both players. The depth-3 forced count (3,656) is 45×
   T416's forced-cycle floor (80), and permissive depth-3 (5,408) covers all
   4,550 states on T416's cycles.
4. Every published T412 bucket reproduced exactly on the same sample — the
   classifier did not change; the new numbers compose.

**Direction the result cuts.** Against the operator's hoped-for binary
("no problem" if loopy is always suboptimal for one player): the permissive
ladder shows a loop is available for 3+ plies at 5,408 positions and forced
for 3 plies at 3,656 — T416's cycles already settled that both players can
sustain a loop; this row shows the *compelled* corridor is deep, not a
one-ply artefact. **For** the operator's reassuring case: at 9,480 (3×3) /
23,459 (4×4) positions a loop exists but optimal play walks away — and
mostly by a decisive margin. The honest deliverable stands as before: the
fresh-start score table + the CLAIMED `[L,H]` fresh-start bracket, with the
explicit non-promise that neither equals nor bounds the real-game PSK score —
now with the loop region partitioned into declined / forced / absent, and the
forced corridor measured to depth 3.

**Scope limits (stated, not hidden).** (1) 4×4 is a sample; every 4×4
figure is a sample statistic, and the depth-3 forced 4,867 is a sample lower
bound — T416's forced-cycle status at 4×4 remains OPEN. (2) Fresh-start
table (C1) only; C2 (history-independence) is falsified at 3×2 and C3
(brackets bound real-game score) at 3×3 — no real-game claim. (3) The 4×4
artifact is the writes-ON checkpoint (AGENTS.md foreclosure: ko-sensitive
columns distrusted until Track A regenerates with `memo_writes=false`).
(4) The margin distribution is over positions, not over loop paths.

---

## Provenance

| artifact | path |
|---|---|
| instrument | `src/t419_taxonomy.zig` (additive; 17 unit tests wired into `zig build test`) |
| evidence — 3×3 real | `docs/evidence/T419-TAXONOMY/3x3-real.json` |
| evidence — 4×4 real | `docs/evidence/T419-TAXONOMY/4x4-real.json` |
| evidence — seeded control | `docs/evidence/T419-TAXONOMY/3x3-forceloopy.json` |
| evidence — null control | `docs/evidence/T419-TAXONOMY/3x3-noneloopy.json` |
| seeded control (cited, not re-run at 4×4) | `docs/evidence/T412-SIBLING-DTT/sibling-{3x3,4x4}-forceloopy-control.json` |
| findings aggregate | `findings/T419-loopy-taxonomy.json` |

Runs under `tools/runner` (4 GB RSS guard); 4×4 peak RSS 1,627 MB. Tables:
`data/oracle-3x3-v2.wzo2`, `data/oracle-4x4-v2.wzo2`. The 4×4 sample is
T412's declared sample (200,000 of 98,616,794 non-terminal parents, seed 42),
reproduced verbatim. Scores are Black-positive throughout; side-to-move
picks the array, never the sign. Identity: deepseek-v4-flash/T419 (worker).
