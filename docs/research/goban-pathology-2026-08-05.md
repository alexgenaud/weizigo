# Goban pathology — definition and census at every solved size

**Task:** T382 · **Role:** worker · **Model:** deepseek-v4-flash · **Date:** 2026-08-05
**Instrument:** `src/t382_census.zig` (additive; no engine/build edits) — modes `--slot`,
`--kocount`, `--cycles`, `--wzo2`, `--selftest`
**Data:** `findings/T382-pathology.json`, `findings/T382-context.json`
**Status:** CENSUS — every figure carries its denominator; committed cross-checks reproduced
(see §5). No solving, no re-derivation, no fixes.

**Landmark:** advances `L2 (proven 4×4 values)` and `L7 (the 5×5 decision, costed)` — the
project now has a *defined and measured* answer to "which board sizes are evidence about Go,
and which are evidence about small boards", and the ladder can say which rung a number
belongs to. What remains: the 3×3/4×3/4×4 history-dependence rates themselves are not
measured (cost argument, §4.5) — the ladder's load-bearing rungs (2×2, 3×2) are.

---

## 1. The operator's question

*"Do we have a formal definition of 'pathological goban'? … I only suspect 3×3 might be the
smallest board with realistic ko."* (Operator, 2026-08-05.)

We had none — the word existed only as loose prose. This document defines it as five named,
measurable components and measures each at every solved size (2×2, 3×2, 3×3, 4×3, 4×4).
Census only: the artifacts are the committed ones, the instrument is new, no value was
re-derived.

**The answer up front:** the smallest board with *realistic* ko (ko/history mechanisms that
change game values under reachable play) is **3×2**, one rung below the operator's guess.
There is **no defensible clean threshold** — pathology is a gradient with two real jumps
(2×2→3×2, and the appearance of multi-ko at 4×3). 2×2 is pathological in the opposite
direction from "constant ko": it has ko shapes, but none of them ever changes an `L==H`
value, and half its legal positions are annihilations. §6 states the argument.

---

## 2. The definition — five named, measurable components

A goban size is *pathological* to the extent that its ko/history machinery distorts the
values the engine stores relative to what real Go would produce, or that the goban's state
space is dominated by degenerate structures. Five components, each with an operational
definition and a measurement method. The first three are the operator's three; the last two
are what the existing data suggested (per the brief).

| # | component | operational definition | denominator |
|---|---|---|---|
| 1 | **full-kill frequency** | (a) share of legal positions where one colour has **zero stones** on the goban ("annihilated"); (b) share of non-settled slots where a full-kill move exists; (c) of those, the share where a full-kill move is **optimal** (some full-kill child's stored value equals the stored value) | legal positions; non-settled slots; full-kill slots |
| 2 | **ko density** | (a) KO_SENSITIVE (`L<H`) slot fraction; (b) the independent-ko-count distribution (B23 static ko shapes: 0-ko … 4+-ko) | side-slots (WZO1); compact entries (WZO2); ko-sensitive slots |
| 3 | **pass-optimality** | share of non-settled slots where the pass edge (V1(P,−side) = best opponent reply ∪ area) equals the stored V0 — i.e. passing is an optimal move | non-settled slots (split L==H / KO_SENS) |
| 4 | **cycle reachability** | whether the **move graph** (R8 legal moves over (pos, side, ko, passes∈{0,1})) has non-trivial SCCs reachable from the root; the cycle-reachable fraction (I5's notion: a state from which a non-trivial SCC is reachable) | full-graph vertices; root-reachable vertices |
| 5 | **history dependence** | fraction of `L==H` slots whose exact value differs under at least one reachable history | reachable `L==H` slots |

Component 5 is the one that answers "realistic ko". It is **measured only at 2×2 and 3×2**
(committed probes); at 3×3/4×3/4×4 it is bounded structurally (component 4 + the pending-ko
potential) because measuring it is a solve campaign, not a census (§4.5).

---

## 3. The census — every solved size, every component

Artifacts: `artifacts/oracle-{2x2,3x2,3x3,4x3}.wzo` (committed, WZO1, PSK era) ·
`data/oracle-4x4.checkpoint.wzo` (WZO1, writes-ON, the only 4×4 with a filled root) ·
`data/oracle-{3x3,4x4}-v2.wzo2` (WZO2, basic-ko + TIE=0). Hashes in
`findings/T382-context.json`. All runs 2026-08-05, ReleaseFast under `tools/runner`.

### 3.1 Component 1 — full-kill frequency

| goban | legal positions | annihilated (a colour at zero stones) | % | zero Benson-alive (a colour) | slots with a full-kill move | % of non-settled | full-kill **optimal**, all | optimal, `L==H` subset | optimal, KO_SENS subset |
|---|---|---|---|---|---|---|---|---|---|
| 2×2 | 57 | 29 | **50.88%** | 57 (100%) | 74 / 106 | 69.81% | 58/74 (78.4%) | 24/24 (**100%**) | 34/50 (68.0%) |
| 3×2 | 489 | 125 | **25.56%** | 489 (100%) | 448 / 918 | 48.80% | 426/448 (95.1%) | 304/304 (**100%**) | 122/144 (84.7%) |
| 3×3 | 12,675 | 1,021 | **8.06%** | 12,675 (100%) | 5,716 / 24,826 | 23.02% | 5,652/5,716 (98.9%) | 4,950/4,950 (**100%**) | 702/766 (91.6%) |
| 4×3 | 321,689 | 8,189 | **2.55%** | 321,687 (99.9994%) | 61,698 / 640,110 | 9.64% | 61,554/61,698 (99.8%) | 59,878/59,974 (99.84%) | 1,676/1,724 (97.2%) |
| 4×4 | 24,318,165 | 131,069 | **0.539%** | 24,317,841 (99.9987%) | 1,340,858 / 48,599,962 | 2.76% | 1,340,298/1,340,858 (99.96%) | 1,336,536/1,336,552 (**99.999%**) | 3,762/4,306 (87.4%) |

Reading: **annihilation is a small-board phenomenon** — 51% of 2×2 positions, 26% of 3×2,
8% of 3×3, 2.5% of 4×3, 0.5% of 4×4 legal positions have a colour with zero stones. Where a
full-kill move exists it is almost always *optimal* in the trusted (`L==H`) region — 100%
at 2×2/3×2/3×3, 99.84% at 4×3, 99.999% at 4×4 — so full-kill is not a mirage: on small
boards the killing capture is usually the right move. The zero-alive reading (a colour with
no Benson-alive stone) is 100% through 3×3 and 99.999% at 4×3: on these gobans **both
colours' unconditional life almost never coexists** — someone is always dead by Benson (or
stone-less). At 4×4 it should finally be measured to see where two-life positions begin.

### 3.2 Component 2 — ko density

**KO_SENSITIVE fraction (WZO1 flag, an L<H bracket property — not a score).** Two
denominators, both measured:

| goban | non-settled slots (measured here) | all legal slots (scaling-census form) |
|---|---|---|
| 2×2 | 82/106 = **77.36%** | 82/114 = 71.93% |
| 3×2 | 378/918 = **41.18%** | 378/978 = 38.65% |
| 3×3 | 8,698/24,826 = **35.04%** (matches chainability) | 8,698/25,350 = 34.31% |
| 4×3 | 170,276/640,110 = **26.60%** (matches chainability) | 170,276/643,378 = 26.47% |
| 4×4 | 10,367,922/48,599,962 = **21.3332%** (matches chainability) | 10,367,922/48,636,330 = 21.32% |

The monotone decline 77% → 41% → 35% → 27% → 21% (WZO1) confirms the brief's trend
direction. **The "7×" magnitude in the brief is a format mix**: 26.45% (4×3) is a WZO1-era
number and 3.49% (4×4) is WZO2-era. On a consistent WZO1 denominator the drop 4×3→4×4 is
26.5% → 21.3% (≈1.2×), not 7×. On a consistent WZO2 denominator (3×3 → 4×4, below) it is
10.9% → 3.5% (≈3.1×). Direction confirmed; the 7× figure is not.

**KO_SENSITIVE fraction (WZO2, L<H over compact entries):**

| goban | KO_SENS / entries | % |
|---|---|---|
| 3×3 (`oracle-3x3-v2.wzo2`) | 5,408 / 49,428 | **10.94%** |
| 4×4 (`oracle-4x4-v2.wzo2`) | **3,455,412 / 99,133,036** | **3.4856%** — reproduces the committed I5/brief headline exactly |

(4×3 has no WZO2 artifact. The brief's 170,181/643,378 = 26.45% pairs the I5 reachable-graph
numerator — flagged ko=none passes=0 states, which exclude 95 unreachable flagged slots —
with the WZO1 all-slot denominator. Measured here: 170,276/643,378 = 26.47% all slots,
26.60% non-settled. The 95-slot gap is consistent with root-unreachable flagged slots; not
independently verified.)

**Independent-ko-count distribution** (B23 static ko shapes; 3×3 and 4×4 reproduce B23
byte-identically — a calibration anchor):

| goban | ko-sensitive slots | 0-ko | 1-ko | 2-ko | 3-ko | 4+-ko |
|---|---|---|---|---|---|---|
| 2×2 | 82 | 50 (61.0%) | 32 (39.0%) | 0 | 0 | 0 |
| 3×2 | 378 | 294 (77.8%) | 84 (22.2%) | 0 | 0 | 0 |
| 3×3 | 8,698 | 7,010 (80.6%) | 1,688 (19.4%) | 0 | 0 | 0 |
| 4×3 | 170,276 | 122,888 (72.2%) | 46,448 (27.3%) | **940 (0.55%)** | 0 | 0 |
| 4×4 | 10,367,922 | 6,741,026 (65.0%) | 3,415,640 (32.9%) | 211,000 (2.04%) | 256 (0.0025%) | 0 |

Reading: **multi-ko shapes first appear at 4×3** (2-ko, 0.55% of the ko-sensitive region);
3-ko first appears at 4×4 (256 slots). Below 4×3 the ko-sensitive region is purely 0-ko and
1-ko — a single-ko sub-solver covers all of it (the B32/T117 result, now with the lower
rungs measured). 2×2 has no 0-ko-only caveat-free reading: 39% of its ko-sensitive slots
carry a ko shape, despite the board being too small for the shape to ever change an `L==H`
value (§4.5, component 5).

### 3.3 Component 3 — pass-optimality

| goban | non-settled slots | pass optimal, all | pass optimal, `L==H` | pass optimal, KO_SENS |
|---|---|---|---|---|
| 2×2 | 106 | 40 (37.7%) | **0/24 (0%)** | 40/82 (48.8%) |
| 3×2 | 918 | 232 (25.3%) | 124/540 (23.0%) | 108/378 (28.6%) |
| 3×3 | 24,826 | 6,336 (25.5%) | 4,226/16,128 (26.2%) | 2,110/8,698 (24.3%) |
| 4×3 | 640,110 | 178,344 (27.9%) | 130,008/469,834 (27.7%) | 48,336/170,276 (28.4%) |
| 4×4 | 48,599,962 | 14,861,608 (30.6%) | 11,554,998/38,232,040 (30.2%) | 3,306,610/10,367,922 (31.9%) |

Reading: pass-optimality is a **constant ≈25–31%** at 3×2 and above, and **exactly 0% in the
trusted region at 2×2** (0/24 — passing is never optimal on a single-valued 2×2 position).
That 2×2→3×2 jump (0% → 23%) is one of the two real discontinuities in the census. (The
KO_SENS columns use median-pinned values and are distrusted; the `L==H` columns use the
fresh-start single-score values.)

### 3.4 Component 4 — cycle reachability

Move-graph SCC census (Tarjan over the full (pos, side, ko, passes∈{0,1}) graph; R8 move
generator; the I5/vb_scc model). Measured 2×2/3×2/3×3 here; 4×3/4×4 from the committed I5
runs (models stated).

| goban | V (full graph) | E | non-trivial SCCs | max SCC | root-reachable (of V) | root-reachable in a non-trivial SCC | `L==H` ko=none p0 slots cycle-reachable |
|---|---|---|---|---|---|---|---|
| 2×2 | 1,140 | 2,042 | 1 | **160** | 170 (14.9%) | 160 (94.1%) | **32/32 = 100%** |
| 3×2 | 13,692 | 33,486 | 1 | **1,676** (= T134/I5) | 1,730 (12.6%) | 1,676 (96.9%) | **600/600 = 100%** |
| 3×3 | 507,000 | 1,756,536 | 1 | **48,602** | 49,426 (9.7%) | 48,602 (98.3%) | **16,652/16,652 = 100%** |
| 4×3 | (I5) 1,929,035 | 6,858,926 | — | 1,284,078 | — | — | — |
| 4×4 | (I5) 99,133,036 | 565,402,416 | — | 47,429,504 (47.9%) | — | 97,689,592 cycle-reachable (98.5%) | KO_SENS ⊂ cycle-reachable (0/3,455,412) |

Reading, and the reconciliation with T12: **every size ≥ 2×2 has abundant cycles in the move
graph**, and 100% of `ko=none passes=0` slots are cycle-reachable at 2×2/3×2/3×3 (the
vacuity T363 attributed to 3×2 extends down to 2×2 and up to 3×3). The `2x2.T12` row's "no
reachable non-root cycles" is true only of **PSK-legal reachability** — under PSK every
cycle is cut by a position-repetition ban. A concrete witness at 2×2 (7 states, all
ko=none, no immediate recaptures, hence basic-ko-legal):

```
{W@0} B --B@1--> {W@0,B@1} W --W@2--> {W@0,B@1,W@2} B --B@3 (captures 2)-->
{B@1,B@3} W --W@0--> {W@0,B@1,B@3} B --B@2 (captures 1)-->
{B@1,B@2,B@3} W --W@0 (captures 3)--> {W@0} B
```

This is a capture-exchange cycle: the goban revives itself. PSK forbids the final
re-creation; basic ko does not. So "2×2 has no cycles" and "2×2's C2-pilot is tautological"
are **ban effects, not the absence of cyclic structure** — a correction to how the T12 row
is usually glossed. The 3×2 max SCC (1,676) reproduces the committed T134/I5 calibration
value exactly, cross-validating the graph construction.

The one non-vacuous rung stays 4×4 (98.5% cycle-reachable, 1.5% of states off-cycle, all
KO_SENSITIVE on-cycle) — consistent with the G3b vacuity finding.

### 3.5 Component 5 — history dependence

| goban | measured | structural bounds |
|---|---|---|
| 2×2 | **0** (T12 C2-pilot over all L==H × histories; EXP-8 sample: 0/10 L==H diverged, 28/46 KO_SENS did) | pending-ko potential: **16/24 = 66.7%** of L==H slots |
| 3×2 | **154/508 = 30.3%** of reachable L==H slots (T13, 2026-07-30; 4,432/134,504 falsifying pairs; 132 positions) | pending-ko potential: 244/540 = 45.2% |
| 3×3 | not measured | cycle: **100%** of L==H ko=none p0 slots cycle-reachable (measured); pending-ko potential: 6,480/16,128 = 40.2% |
| 4×3 | not measured | cycle: I5 shows all KO_SENSITIVE cycle-reachable; pending-ko potential: 193,160/469,834 = 41.1% |
| 4×4 | not measured | cycle: 98.5% of states cycle-reachable (I5), all KO_SENSITIVE on-cycle; pending-ko potential: 17,336,360/38,232,040 = 45.3% |

**Why 3×3/4×3/4×4 are not measured:** the T13-style measurement is a history-aware solve
per (slot, history) pair — the T13 exhaustive at 3×2 cost ~5 min on 17 workers over 134,504
pairs. The 3×3 line space is ≥10⁴× larger by the same method, and EXP-8 already measured
exact-PSK-under-history to be budget-intractable even at 3×2 (3/3 solved with one empty
point). That is a solve campaign, not a census; the brief's bar ("census only") applies.
The structural bounds are loose: pending-ko potential sits at 40–67% of L==H slots at every
size, yet at 2×2 (66.7% potential) the measured rate is 0 — the bounds over-approximate by
an order of magnitude or more.

The two measured rungs bracket the phenomenon: **0 at 2×2, 30.3% at 3×2.** The mechanism at
3×2 is position-repetition bans, not ko recaptures per se — T13's hand-verified example
(`idx=413`) is a goban-winning capture that repeats a position from five plies earlier and
is PSK-banned, collapsing +6 to +1. At 2×2 the divergence that EXP-8 found (28/46, all in
the KO_SENS region) is ko-recapture-driven. Both mechanisms exist structurally at both
sizes; what changes between 2×2 and 3×2 is whether they ever touch an `L==H` value.

---

## 4. Definitions and trust notes — all load-bearing

1. **`L==H` vs KO_SENS values.** All value-based comparisons (full-kill optimality,
   pass-optimality) are reported split by region. The `L==H` columns use the fresh-start
   single-score values (C1-proven at 2×2/3×2, claimed above). The KO_SENS columns use
   median-pinned stored values which are **distrusted pending Track A** — they are reported
   for completeness only and must not be quoted as truth (AGENTS.md foreclosure).
2. **The KO_SENSITIVE flag itself is safe to read** — it is the L<H bracket property, not a
   score (the chainability/reachcensus discipline).
3. **The 4×4 checkpoint is the writes-ON build** and the only 4×4 artifact with a filled
   root; its ko-sensitive *column* is the distrusted one. Its flag counts reproduce the
   committed chainability readings exactly (21.3332% non-settled).
4. **Scores are Black-positive throughout; no game value is quoted.**
5. **Cycle-reachability is the move-graph notion (I5's), not PSK-reachable play.** Under
   PSK the reachable game tree is acyclic at every size by construction. The component
   measures where ko machinery *can* be active, not where a real game necessarily cycles.
6. **Per-goban epistemic independence (AGENTS.md).** Every row is a separate measurement;
   the gradient descriptions in §6 are observations about the measured set, not a
   monotonicity theorem that licenses extrapolation to 5×5.
7. **The 4×3/4×4 cycle rows cite the committed I5 runs** (GLOBAL.I5-SCC-CONTAIN,
   accept.md), whose graph models differ from the t382 cycles model (4×3: (pos, side,
   passes) without ko; 4×4: the WZO2 compact space). They are cited, not re-measured.

---

## 5. Calibration (per brief: null and seeded controls before a counter's first reading)

`weizigo-t382-census --selftest` ran **before any reading** and passed 11/11:

- **Known-good, instrument-level:** Tarjan on a hand-built graph (one 2-cycle → 4 SCCs, 1
  non-trivial, max size 2); ko-shape detector on hand-built positions (3×3 single pocket →
  1 point/1 cluster; 4×4 two disjoint pockets → 2 points/2 clusters).
- **Null control:** 1×1 artifact through encode/decode — zero KO_SENS flags, one legal move
  (the pass), empty goban is a full-kill position by definition.
- **Seeded defects:** flipping a clear KO_SENS flag on 2×2 moves the count by exactly +1;
  perturbing a stored value to +127 (impossible as a score) makes pass-optimality false.
- **Committed cross-checks, all PASS:** 2×2 legal = 57 (OEIS A094777); 3×3 and 4×4
  ko-count distributions byte-identical to B23; 4×4 non-settled KO_SENS = 10,367,922
  (= chainability); 4×4 WZO2 = 99,133,036 entries and 3,455,412 L<H (= I5/brief headline);
  3×2 max SCC = 1,676 (= T134/I5); 3×2 100% cycle-reachable (T363 vacuity).

One instrument bug was caught by calibration, not by inspection: the zero-alive counter
initially read 100% at every size because both colours' checks used Black's Benson array
(colour fixed at +1). The fix (per-colour `benson_alive`) is what made the 4×3 reading drop
to 99.9994%. This is exactly the "impossibly clean counter" red flag from the standing
rules.

---

## 6. The operator's question, answered

**What is the smallest board with realistic ko?**

**3×2.** The two measured rungs bracket the phenomenon: 2×2 has zero history dependence in
its `L==H` region (T12 pilot + EXP-8), 3×2 has 30.3% (T13). Ko shapes and cycles exist
structurally at 2×2 (39% of its KO_SENS slots carry a ko shape; the move graph has a
7-state capture-exchange cycle) — but at 2×2 they never change a single-valued position's
value. At 3×2 they do, and by a third of the reachable single-score region. The operator's
3×3 guess was **one rung high**.

**Is there a defensible pathology threshold, or a gradient?**

**A gradient, with two real jumps — no clean line.** The evidence:

1. **Full-kill and annihilation are small-board phenomena with no threshold**: 50.9% of
   2×2 legal positions are annihilations, falling monotonically 25.6% → 8.1% → 2.5% →
   0.54%. Every size has them; there is no size where they vanish.
2. **KO_SENSITIVE density declines monotonically** (77% → 41% → 35% → 27% → 21% WZO1;
   10.9% → 3.5% WZO2) — a slope, not a step. The brief's "7×" is a denominator mix (§3.2).
3. **Jump 1: 2×2 → 3×2.** History dependence 0 → 30.3%; pass-optimality in the trusted
   region 0% → 23%; annihilation 51% → 26%. The 2×2 rung is degenerate in the *opposite*
   direction from "constant ko": its ko machinery never binds on a single value. This is
   the one place a threshold is defensible: **below 3×2, ko is structurally present and
   operationally inert.**
4. **Jump 2: 4×3.** The first multi-ko positions (2-ko, 0.55% of the ko-sensitive region);
   3-ko only at 4×4 (256 slots). Below 4×3, a single-ko sub-solver covers 100% of the
   ko-sensitive region.
5. **Cycle reachability is vacuous at 2×2/3×2/3×3 and first non-vacuous at 4×4** (98.5%
   cycle-reachable, all KO_SENSITIVE on-cycle) — a structural milestone, not a pathology
   threshold.

**What this means for the ladder-rung arguments:** a number taken at 2×2 or 3×2 is taken on
a rung where annihilation is a quarter to half of all positions, ko shapes never move
single values (2×2), and history dependence is either absent or maximal-sample (3×2).
Numbers at 3×3 and above are on rungs where annihilation is ≤8%, pass is genuinely optimal
~26% of the time, and the ko machinery's value-shifting capacity is at least structurally
present everywhere. The honest deliverable sentence: **the ladder's small rungs are
evidence about tiny-board Go; the "realistic ko" behaviour the operator suspects starts at
3×2, and the multi-ko behaviour starts at 4×3.** Both statements are about the measured
set, not a monotonicity law.

---

## 7. Reproduction

```
tools/runner -- zig build-exe -O ReleaseFast src/t382_census.zig --name weizigo-t382-census
./weizigo-t382-census --selftest                                  # 11/11, run FIRST
./weizigo-t382-census --slot  artifacts/oracle-2x2.wzo            # ... and 3x2, 3x3, 4x3
./weizigo-t382-census --slot  data/oracle-4x4.checkpoint.wzo      # 39 s wall
./weizigo-t382-census --kocount <artifact>                        # all five sizes
./weizigo-t382-census --cycles artifacts/oracle-2x2.wzo           # ... and 3x2, 3x3
./weizigo-t382-census --wzo2 data/oracle-3x3-v2.wzo2
./weizigo-t382-census --wzo2 data/oracle-4x4-v2.wzo2
```

Raw outputs: `/tmp/weizigo/t382-run/` (disposable). Findings:
`findings/T382-pathology.json`, `findings/T382-context.json`.

## 8. Files

- `src/t382_census.zig` — the instrument (this task; additive, no build.zig / engine edits)
- `findings/T382-pathology.json` — the five-component census, machine-readable
- `findings/T382-context.json` — runs, hashes, calibration, trust labels
- `docs/research/goban-pathology-2026-08-05.md` — this document

**Landmark:** advances `L2 (proven 4×4 values)` and `L7 (the 5×5 decision, costed)` — the
census gives the ladder a defined and measured pathology vocabulary: "realistic ko" starts
at 3×2 (measured history dependence), multi-ko starts at 4×3, cycle-reachability turns
non-vacuous at 4×4, and annihilation is a ≤2.5% phenomenon by 4×3. What remains between
here and L2: the 3×3/4×3/4×4 history-dependence rates (a solve campaign, not a census),
and for L7 the 5×5 decision must weigh that the small-rung numbers are small-board
evidence by these five measures.
