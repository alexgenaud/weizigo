# T266 — why the 4×4 WZO2 artifact is "missing" passes=1 entries

```
Task:    T266 · Role: worker · Model: claude-opus-5 · Date: 2026-08-02
Brief:   untracked/T266-artifact-incompleteness.md
HEAD:    c344f02 (working tree carries another seat's in-flight src/claimlint.zig edit; untouched here)
Artifact: untracked/oracle-v2/oracle-4x4-v2.wzo2, SHA-256 0c3366f0…  (verified by shasum this session)
          untracked/oracle-v2/oracle-3x3-v2.wzo2, SHA-256 d79c17cd…
Status:  FAIL-FOUND, but not where the brief expected it —
         the artifact's passes=1 coverage is CORRECT AND COMPLETE;
         the defects are in the CHECKER and the ENGINE'S DISPLAY PATH.
Evidence: t266_scan.py · t266_calibrate.py · t266-scan-2026-08-02.stdout
          · t266-calibration-2026-08-02.stdout (all in this directory)
```

## Verdict in one paragraph

`CODE.WZO2-INCOMPLETE` is **wrong as stated**. The `passes=1` side-entries that
T261 measured as missing are missing because they are **unreachable**, and the
set of absent entries is *exactly*, with zero exceptions over all 24,318,165
groups, the set that the rules make unreachable. There is no builder defect, no
dropped pass edge, and nothing to fill. The two real defects this task did find
are (1) `src/oracle_v2_accept.zig:150-165` carries a second, **unfixed** copy of
the ko rule that T265 fixed in `src/gtp.zig` — this, not artifact coverage, is
what makes A1/A2/A8 fail; and (2) `src/gtp.zig:1222-1225` looks up the bracket
for the wrong side-to-move on every genmove, which is what produced the
`colex=12 side=1 ko=16 passes=0` miss. **A rebuild is not needed.** Per DIRECTION
§5 no fix is applied here; §5 of this document specifies the battery check.

---

## 1. The mechanism (question 1)

### 1.1 The derivation

Three facts about the state graph, each read out of the source at HEAD:

**F1 — `passes=1` has exactly one kind of in-edge: a pass from `passes=0`.**
`genChildren4` (`src/exp6_solve.zig:914-942`) emits, for a state with
`passes = p < 2`, one pass child at `passes = p+1` and placement children at
`passes = 0` (line 937). So a `passes=1` state is never entered from another
`passes=1` state, and never by a placement. The census seeds only
`(empty, side, KO_NONE, 0)` for both sides (`src/exp6_solve.zig:964-969`), so it
is not a root either.

**F2 — the pass child always carries `ko = KO_NONE` and flips the side.**
`pass_enc = encodeState4(board_idx, 1 - side, KO_NONE4, passes + 1)`
(`src/exp6_solve.zig:927`). Therefore

> `(P, s, KO_NONE, 1)` is reachable **iff** `(P, 1−s, ko, 0)` is reachable for some `ko`.

**F3 — a `passes=0` state is entered only by a placement, and a placement always
leaves at least one stone of the mover's colour on the goban.**
`genericPosFromMove` (`src/exp6_solve.zig:161-177`) writes `pos[cell] = colour`
(line 164), removes only *opponent* chains (line 170, guarded by
`pos[q] * colour < 0`), and returns `error.Suicide` if the mover's own chain
ends up captured (line 176). So on success the mover's stone survives.

Combining, with `side=0` = Black to move and `side=1` = White to move: a
`passes=0` state with White to move is the result of a **Black** placement and
therefore needs ≥1 black stone; one with Black to move is the result of a
**White** placement and needs ≥1 white stone. The empty goban is the sole
exception — it is a seed root for both sides. Hence:

> **The monochrome-side law.** For a non-empty goban `P`:
> `(P, Black to move, ko, 0)` is reachable only if `P` has ≥1 white stone, and
> `(P, White to move, ko, 0)` only if `P` has ≥1 black stone.
> With F2: **`(P, s, KO_NONE, 1)` is unreachable exactly when `P` is monochrome
> in the colour of side `1−s`.**

### 1.2 The concrete case the brief asked for

Take `colex = 12` at 4×4 — a single **black** stone on cell 5 (GTP `B3`), which
is the position after Black's first move in the transcript below. The absent
entry is `(colex=12, White to move, ko=none, passes=1)`.

*It cannot exist.* By F1 its only possible predecessor is
`(colex=12, Black to move, ko, 0)` for some `ko`. By F3 that state is entered
only by a White placement, and a White placement leaves a white stone; the
goban has none. The empty-goban exception does not apply. Therefore no legal
basic-ko line reaches it. ∎

The artifact agrees exactly (`t266_scan.py --lookup`):

| state | in artifact? |
|---|---|
| `colex=12`, White to move, ko=none, passes=0 | **present**, `L=1 H=16 DTT=2` |
| `colex=12`, Black to move, ko=none, passes=1 | **present**, `L=16 H=16 DTT=1` |
| `colex=12`, Black to move, ko=none, passes=0 | **absent** — no White stone (F3) |
| `colex=12`, White to move, ko=none, passes=1 | **absent** — pass child of the above (F2) |

### 1.3 Exhaustive confirmation — every group, not a sample

`t266_scan.py` is an independent Python re-implementation of the WZO2 reader
(it shares no code with builder or consumer; it parses only the frozen byte
layout at `src/artifact2.zig:19-34`). It classifies **every** group.

Hypothesis **T266-H1**: `(P, s, passes=1)` absent ⟺ `P` monochrome in colour `1−s`.

| | 3×3 | 4×4 |
|---|---|---|
| groups (denominator) | 12,675 | 24,318,165 |
| entries | 49,428 | 99,133,036 |
| monochrome-black / monochrome-white groups | 510 / 510 | 65,534 / 65,534 |
| groups one-sided at passes=1 | 1,020 | 131,068 |
| absent-but-**not** monochrome (would refute H1) | **0** | **0** |
| monochrome-but-**present** (would refute H1) | **0** | **0** |
| **T266-H1** | **CONFIRMED** | **CONFIRMED** |

Not one exception in 24.3M groups. The arithmetic closes with no slack either:
stored `passes=1` entries = `2 × n_groups − monochrome_groups` exactly —
`2(12,675) − 1,020 = 24,330` ✓ and `2(24,318,165) − 131,068 = 48,505,262` ✓,
both equal to the measured counts.

(`65,534 = 2¹⁶ − 2`: every non-empty monochrome 4×4 goban except the fully
filled one, which has no liberties and is illegal. Every one of them *is* in
the artifact, reachable with the other side to move.)

The whole result rests on my Python colex decode agreeing with `src/colex.zig`,
so that was tested against the Zig side rather than assumed, in both colours. My
decode says a lone stone on cell `C` has colex `1 + 2C + (1 if black)`; the Zig
engine independently reported `colex=12` for its own black `B3` (cell 5). The
mirror prediction — `genmove w` from an empty goban must miss at **colex 11**
with the engine-side `side=-1` — was recorded before the run and came out
exactly:

```
weizigo-oracle: WARNING bounds2 lookup-miss #1 — state colex=11 side=-1 ko=16 passes=0
```

and `--group 11` renders precisely a lone white stone on cell 5, holding exactly
the two entries the law predicts (Black-to-move passes=0, White-to-move passes=1)
and neither of the two it forbids.

### 1.4 So the answer to question 1 is (a) — with the corollary the brief drew

The brief's framing was: either (a) the entries are genuinely unreachable, "in
which case self-play must be reaching illegal states, and *that* is the bug", or
(b) they are wrongly dropped. It is **(a)**. The corollary holds too — the
consumers *were* going off-manifold — but §3 and §4 show that is a consumer
defect, not evidence of artifact incompleteness.

---

## 2. Does the census enumerate pass edges for both sides? (question 2)

**Yes, for both sides, unconditionally.** By source: `genChildren4` appends the
pass child before any legality test and before the placement loop, for every
state with `passes < 2` regardless of side (`src/exp6_solve.zig:926-929`); the
census expands every state it marks and applies its legality filter only to
`passes == 0` children (`src/exp6_solve.zig:1008-1019`), so a pass child is never
filtered out.

That is a code reading, so it was also tested against the artifact directly.
Hypothesis **T266-H2**: if pass edges were enumerated for both sides, then for
every group `(P, s, KO_NONE, 1)` is stored ⟺ `(P, 1−s, ko, 0)` is stored for
some `ko`. A group where the `passes=0` parent is present but its pass child is
not is a **dropped pass edge**; the converse is an **orphan**.

| | 3×3 | 4×4 |
|---|---|---|
| dropped pass edges (side 0 / side 1) | 0 / 0 | 0 / 0 |
| orphaned passes=1 entries (side 0 / side 1) | 0 / 0 | 0 / 0 |
| denominator | 2 × 12,675 = 25,350 | 2 × 24,318,165 = 48,636,330 |

**Zero.** The `if (data.map.get(lin))` guard at `oracle_v2_build.zig:384-390`
that the brief pointed at is doing exactly the right thing: it declines to write
states the fixpoint never produced, and the fixpoint never produced them because
they do not exist.

Three further whole-artifact invariants, same denominators, all exact:

| check | 3×3 | 4×4 | denominator (4×4) |
|---|---|---|---|
| passes=1 entries with `ko ≠ KO_NONE` (design §2.5) | 0 | 0 | 48,505,262 |
| passes=0 entries whose ko point names an **occupied** cell | 0 | 0 | 2,122,512 with ko≠none |
| entries mis-ordered or duplicated within a group | 0 | 0 | 74,814,871 intra-group steps |
| passes=0 entries violating the monochrome-side law | 0 | 0 | 50,627,774 |

### 2.1 The instrument was calibrated before these zeros were believed

Every counter above reads zero, and "impossibly clean counters are red flags"
(AGENTS.md, QA-023 rules). `t266_calibrate.py` byte-patches **synthetic** mutants
of the 3×3 artifact in a scratch directory — never live data, per DELEGATEE.md's
calibration rule — one mutant per counter, and requires the targeted counter to
fire:

```
K0-null-control            -> PASS (clean, as required)
K1-dropped-pass-edge       -> PASS (caught: h1_absent_not_mono_s0, CB1_dropped_pass_edge_s0, CB4)
K2-monochrome-law          -> PASS (caught: CB2_monochrome_law, CB1_dropped_pass_edge_s1, CB1_orphan_s0)
K3-ko-on-occupied-cell     -> PASS (caught: CB3_ko_on_occupied_cell)
K4-passes-bit-flip         -> PASS (caught: CB3_passes1_ko_not_none, CB4)   [T193 replayed]
K5-duplicate-key           -> PASS (caught: CB4_order_or_dup, CB1_orphan_s0)
# calibration: PASS — instrument catches every seeded defect
```

Null control clean, five seeded defects all caught. The zeros count.

---

## 3. The `genmove b` miss (question 3)

### 3.1 Reproduction

At HEAD (`c344f02`), rebuilt this session:

```
$ printf 'boardsize 4\nclear_board\ngenmove b\nquit\n' | ./gtp-head oracle-4x4-v2.wzo2
weizigo-gtp c344f02-dirty built 2026-08-02T20:35:35Z zig 0.16.0
weizigo-oracle: WARNING bounds2 lookup-miss #1 — state colex=12 side=1 ko=16 passes=0
                not in artifact, fell back to area score 16
oracle: b -> B3  child-value=1 stored-v0=1 KO_SENSITIVE [L=16,H=16] dtt=2
```

Every time, as the brief says.

### 3.2 The explanation

Two things have to be said in order, because the first is a naming trap.

**`side=1` in that warning is Black, not White.** The warning prints the *engine*
`i8` side (`src/gtp.zig:168`), where `+1` = Black; the artifact's key byte uses
`0` = Black (`src/artifact2.zig:343-345`). So the missed state is
`(single black stone on B3, **Black** to move, ko=none, passes=0)` — precisely a
monochrome-black goban with Black to move, which §1 proves unreachable. The
artifact is right to lack it.

**The engine should never have asked.** The query comes from the bracket-display
suffix:

```zig
1204:  s.applyMove(side, c.cell) catch {};          // s.pos is now POST-move
...
1223:  const row = s.bounds2(&s.pos, s.ko_point, @intCast(s.passes), side);
1224:  break :blk std.fmt.bufPrint(&sbuf, " [L={d},H={d}]", .{ row.L, row.H }) catch "";
```

`bounds2` is called *after* `applyMove`, so `s.pos` is the position after the
move, but `side` is still **the mover**. After Black plays, it is White's turn;
the engine asks the table about Black-to-move on Black's own result. On the
opening move that state is monochrome-black and therefore absent → the miss, the
area-score fallback, and the printed `[L=16,H=16]`. The correct bracket is the
one the table does hold: `(colex=12, White to move, ko=none, passes=0)` =
`[L=1,H=16]`.

### 3.3 The miss is the visible 0.2% of a bug that is silently wrong the rest of the time

The wrong-side query only *misses* when the post-move position is monochrome —
which in practice is only the opening move. Everywhere else it finds an entry
and prints a wrong one, with no warning. From the self-play transcript below:

| after | displayed `[L,H]` | true `[L,H]` for the actual side to move |
|---|---|---|
| `b → B3` (colex 12) | `[16,16]` (area fallback) | `[1,16]` |
| `w → C2` (colex 234) | `[-16,-1]` | `[1,16]` |
| `b → C3` (colex 1636) | `[16,16]` | `[1,16]` |
| `w → B2` (colex 10020) | `[-16,-1]` | `[1,16]` |

Row 4 happens to be the exact colour-inverse of the truth (that position is
symmetric under 180° rotation), which is why the output reads like a sign
convention and was never questioned. Row 3 is not the inverse of anything — the
displayed `[16,16]` and the true `[1,16]` are simply different states. This is a
**display/telemetry defect only**: the move choice comes from
`choose_with_check` (line 1202) and is unaffected — the engine plays `B3` and
goes on to win.

**Session totals:** 1 miss in 55 lookups for a single `genmove`; **1 miss in 525
lookups** across a full 18-ply self-play — all of them this one call site.

---

## 4. What actually makes A1/A2/A8 fail — and it is not the artifact

T261 attributed the A1 refusals to the passes=1 gap:

> "When self-play passes, it looks up `(colex, side, ko=none, passes=1)` — if
> that specific side's entry is absent, it's a refusal." *(m4b-triage-T261.md,
> A1 root_cause)*

**The checker's own output refutes this.** Running `oracle_v2_accept a1` at HEAD:

```
3×3:  A1 REFUSAL: colex=14717 side=1  ko=6  passes=0 entry not found
      A1 REFUSAL: colex=14671 side=-1 ko=6  passes=0 entry not found
      A1 REFUSAL: colex=12684 side=1  ko=8  passes=0 entry not found
      A1 REFUSAL: colex=15525 side=1  ko=0  passes=0 entry not found
      A1 REFUSAL: colex=970   side=-1 ko=0  passes=0 entry not found
      A1 self-play: queries=104 refusals=8
4×4:  A1 REFUSAL: colex=38475072 side=-1 ko=12 passes=0 entry not found
      A1 REFUSAL: colex=1320150  side=1  ko=13 passes=0 entry not found
      A1 REFUSAL: colex=38487321 side=-1 ko=12 passes=0 entry not found
      A1 REFUSAL: colex=38509733 side=1  ko=0  passes=0 entry not found
      A1 REFUSAL: colex=3405068  side=-1 ko=3  passes=0 entry not found
      A1 self-play: queries=106 refusals=7
```

Every one of the ten sampled refusals is at **`passes=0`** with a **non-none ko**
(KO_NONE is 9 at 3×3 and 16 at 4×4). **None** is at `passes=1`. **None** is at
`ko=none`. The mechanism T261 named is not the mechanism observed. Note also
that A1's walk cannot pass voluntarily at all — `oracle_v2_accept.zig:613-618`
increments `passes` only when `nmoves == 0` — so the passes=1 population is
barely exercised by it. The "7.7% refusals ≈ 8.0% one-sided groups" agreement was
a coincidence of two unrelated rates on a denominator of 104.

### 4.1 One refusal traced end to end

`colex=14717 side=1 ko=6 passes=0` at 3×3 (an auditor must follow one datum from
entry to verdict — AGENTS.md, QA-023 rules):

```
colex=14717  3x3      4 entries in the group:
   O . X          side=0(B) ko=9 (none) passes=0  L=-9 H=-1 DTT=4
   O X X          side=1(W) ko=9 (none) passes=0  L=-9 H=-9 DTT=3
   . O O          side=0(B) ko=9 (none) passes=1  L=-2 H=-1 DTT=1
                  side=1(W) ko=9 (none) passes=1  L=-9 H=-9 DTT=3
```

The group is present and complete; every stored entry has `ko = none`. The
checker asked for `ko = 6`. Cell 6 is the empty point at bottom-left, so White's
previous move captured a single black stone there. Under the solver's ko rule
(`src/exp6_solve.zig:899-910`) a ko point is set only when the capturing stone is
itself in atari with no friendly neighbour (`liberties == 1 and friendly == 0`).
Each white stone adjacent to cell 6 — cells 3 and 7 — has a friendly neighbour
(cell 0 and cell 8 respectively). **No ko point arises.** The solver stored
`ko = none`; the checker constructed `ko = 6`; the lookup missed.

### 4.2 Root cause: a second, unfixed copy of the ko rule

`src/oracle_v2_accept.zig:150-165`:

```zig
fn koAfterCapture(old_pos: anytype, side: i8, new_pos: anytype, ko_none: u8) u8 {
    ...
    if (opp_before - opp_after == 1 and last_captured != ko_none) return last_captured;
    return ko_none;
}
```

Any single-stone capture sets a ko point. That is **exactly the defect T265 found
and fixed** — but T265 fixed `src/gtp.zig`, whose copy now carries the atari test
at `src/gtp.zig:731-743`. The acceptance checker's copy was never touched. Two
implementations of one rule, one fixed, one not; the one that produces the
project's acceptance verdicts is the broken one.

This is the fourth instance of the producer/consumer key-disagreement family
(T178 exp6-rank-vs-colex, T193 passes bit, T265 gtp ko, now T266 accept ko), and
it is the concrete case DIRECTION §4.2 describes when it says the ko rule "exists
only as ~14 divergent copies and no production implementation."

Consequence: **A1, A2 and A8's failures are not evidence about the artifact.**
Their child sets and self-play walks are built with a ko rule the artifact was
never built with, so they go off-manifold and then measure the fallout. T261's
"17,136 missing children" and "4,224 L/H violations" are, on this evidence,
almost certainly the same cause; I did not re-measure A2/A8 to apportion them
and mark that **unestablished** (§7).

---

## 5. The completeness check the Phase 1 battery must run (deliverable 2)

### 5.1 The property, stated correctly

"Complete" cannot mean *every* `(goban, side, ko, passes)` is stored — most are
unreachable and must stay absent. The property is:

> **G-CENSUS.** The set of states stored in the artifact equals the set reachable
> from the two seed roots under ruleset R.

Two directions, and both are needed — the first alone cannot see spurious
entries, the second alone cannot see missing ones:

- **C-A1 (closed).** For every stored entry `s` and every child `c` of `s` under
  the **kernel** move generator with `passes(c) < 2`: `c` is stored.
  *Denominator:* `Σ_s |{children of s with passes<2}|`. *Pass:* zero missing.
- **C-A2 (grounded).** Every stored entry other than the two seed roots has at
  least one stored parent. *Denominator:* `n_entries − 2` (99,133,034 at 4×4).
  *Pass:* zero orphans.

C-A1 ∧ C-A2, with the two roots stored, is exactly G-CENSUS. It refers to no
incidental structure — no monochrome boards, no passes=1 asymmetry — so it stays
correct if the rules change.

**It must run against the kernel move generator** (DIRECTION §4.2), not a private
copy. That is the point: a C-A1 failure is then *either* an artifact defect *or*
a producer/consumer key disagreement, which are the only two things it can be,
and both are findings. Had C-A1 existed and been wired to a single ko
implementation, T178, T193, T265 and §4.2 above would each have been caught by
it. Cost at 4×4 is ~1.3 × 10⁹ child generations plus a lookup each; if it is
sampled, the sample size and selection rule **must be printed** (T261's error was
a 5,000-group prefix reported as if uniform — §6).

### 5.2 The cheap exact layer

These are necessary conditions implied by G-CENSUS, they need no move generator,
and they run over the whole 4×4 artifact in **under 9 seconds** — so there is no
excuse for sampling them. All are implemented in `t266_scan.py` and measured
above.

| id | invariant | denominator (4×4) |
|---|---|---|
| C-B1 | pass-edge closure: `(P,s,KO_NONE,1)` stored ⟺ `(P,1−s,ko,0)` stored for some ko | 2 × n_groups = 48,636,330 |
| C-B2 | monochrome-side law: `(P,s,·,0)` stored ⟹ `P` has a stone of colour `1−s`, or `P` empty | 50,627,774 passes=0 entries |
| C-B3 | ko domain: `passes=1` ⟹ `ko = KO_NONE`; `ko ≠ KO_NONE` ⟹ that cell is empty on `P` | 48,505,262 + 2,122,512 |
| C-B4 | key bytes strictly increasing within each group (the format sort; strictness = no duplicates) | 74,814,871 intra-group steps |
| C-B0 | header self-hash + `Σ counts = n_entries` + colex strictly increasing | 1 + 1 + 24,318,164 |

C-B2 is the T266 theorem mechanized. It is worth having precisely because it
pins the population this task was asked about: a future build that drops a
reachable `passes=1` entry, or invents an unreachable one, is caught in seconds
rather than by a human playing twenty moves.

### 5.3 Calibration — and why `0c3366f0` cannot serve as the known-bad

Required controls, one per check, all **synthetic** (DELEGATEE.md: "Draw
known-bads from synthetic fixtures, not live data — live faults get fixed, and
the check then silently tests nothing"):

| control | seeded defect | must fire |
|---|---|---|
| K0 | none (null control) | nothing |
| K1 | delete a `(P,s,KO_NONE,1)` whose pass parent is present | C-B1, C-A1 |
| K2 | delete a `passes=0` placement child | C-A1 only — **C-B1 must stay silent**, proving C-B1 does not subsume C-A1 |
| K3 | insert `(P, Black to move, ·, 0)` for monochrome-black `P` | C-B2, C-A2 |
| K4 | flip one passes bit (T193 replayed) | C-B3, C-B4 |
| K5 | point one ko field at an occupied cell | C-B3 |
| K6 | duplicate a key byte within a group | C-B4 |
| **K7** | run C-A1 with the **pre-T265 ko rule** in place of the kernel's | C-A1 must fail loudly |

K0 and K1–K6 are implemented and passing in `t266_calibrate.py` (§2.1). K7 is
specified, not implemented: it is the control `2B-5` lacked — one that exercises
*the instrument under test* rather than a parallel path — and it is the control
that would have caught §4.2. A battery run must also **fail** if any check
executed zero comparisons (DIRECTION §7: controls that can't run must fail
loudly, not pass vacuously).

### 5.4 Report against DIRECTION §5 — the battery will not fail `0c3366f0` on completeness

DIRECTION §5 states that `0c3366f0` "is a certified-defective calibration input —
the battery must fail it; a battery that passes an artifact known to be broken is
itself broken." That instruction rests on `CODE.WZO2-INCOMPLETE`, and this task
refutes it. **A completeness check specified to fail `0c3366f0` for
incompleteness would be a check specified to report a defect that is not there.**
C-B1–C-B4 pass it, measured, exhaustively, above.

The two documents were already in tension: DIRECTION §5 nominates a live artifact
as the known-bad, and the standing calibration doctrine forbids exactly that. The
doctrine wins, and the K-series above discharges DIRECTION's real requirement —
that the battery be shown able to fail — without depending on a defect that does
not exist. The registered defect this task *does* supply as a control is the
pre-T265 ko rule (K7), which is a genuine live fault, still present, and
reproducible on demand.

**This is not a claim that `0c3366f0` is correct.** It is a claim about one
property. Nothing here tests whether the stored `L`/`H` values are right, and
C-A1/C-A2 remain unrun. `WZO2-4X4-VALID` should stay FALSE-AS-SCOPED — on the
honest ground that its completeness has been established only for the structural
layer, not on the refuted ground of missing entries.

---

## 6. How T261's measurement went wrong

T261's numbers are correct measurements, wrongly generalized.

Its 4×4 sample was the **first 5,000 groups in file order**. Groups are sorted by
colex, and colex is layered by stone count (`src/colex.zig:41-49`), so those 5,000
groups are the sparsest gobans — stone-count layers 0 to 4, colex 0..5007.
Monochrome density falls off geometrically with stone count: a `k`-stone layer
has `2^k` colourings of which exactly 2 are monochrome — 100% at `k=1`, 50% at
`k=2`, 25% at `k=3`, 12.5% at `k=4`, and 0.003% at `k=16`. The sample sat
entirely in the region where the phenomenon is dense.

Re-running that exact sample reproduces T261 to the digit — 1,393 one-sided
groups, 27.9%, 8,607 passes=0 and 8,607 passes=1 entries — confirming the
selection rule. Extrapolating 27.9% across all 24,318,165 groups gave ~6.77M.
The true figure over the full denominator is **131,068** (0.539% of groups,
0.269% of the 48,636,330 side-entries). **Overstated 51.7×.**

The failure was not arithmetic; it was reporting a prefix as a sample. AGENTS.md
already requires every number to state its denominator — this one stated the
sample size but not that the sample was ordered and the property correlated with
the ordering.

---

## 6a. A third defect, found while filing this — C7 drops proposed rows

`findings/T266-incompleteness.json` proposes four new register rows. Claimlint's
C7 reports **one**.

Two independent bugs in the hand-rolled `new_rows` scanner, both at HEAD
`c344f02` (line numbers resolved with `git show HEAD:src/claimlint.zig`, since
the working tree carries another seat's edits):

1. **Truncation** — `src/claimlint.zig:1676`:
   `if (nr_depth == 0 and nr_count > 0) break;` exits the array the moment the
   first row object closes. Proved by A/B on this file: rows ordered
   `[PASS1-LAW, ACCEPT-KOKEY, GTP-LHSIDE]` → C7 reports only `CODE.WZO2-PASS1-LAW`;
   reversed → only `CODE.GTP-LHSIDE`. `new-rows touched` reads 2 both times
   (1 from `T172-gap5.json`, 1 here) while this file holds 4.
2. **Status mis-parse** — after matching the key `status`, `ns` is left on that
   key's closing quote (`:1716`) and the skip set at `:1718` omits `"`, so the
   value read starts one character early and captures `": "`. Every new row's
   status prints as `` `: ` ``. Reproduced with a plain `PROVEN` status and a
   one-line claim, so it is not a content problem.

DELEGATEE.md already warns that a *non-conforming* findings file disappears
silently from C7. This is the same hazard one step further in: a **conforming**
file loses rows 2..N. Registered as `CODE.CLAIMLINT-C7-NEWROWS`. Not fixed here
— `src/claimlint.zig` is mid-edit by another seat (T272) and one writer per file
is the rule.

## 7. What I could not establish

- **A2's 17,136 missing children and 4,224 L/H violations, and A8's 5,096 DTT
  violations, are not individually apportioned.** §4 shows A1's refusals are
  ko-driven and that A2/A8 share the checker's `koAfterCapture`, so the same
  cause is very likely, but I measured only A1's refusal states. Re-running
  A2/A8 after the accept-module ko fix is the test; it belongs to the fix task.
- **C-A1 and C-A2 were not run.** They need the kernel move generator, which is
  Phase 2. Everything measured here is the structural layer (§5.2).
- **Whether the solver's ko rule is the *right* rule** is not settled here — that
  is an axioms question (T271/T275, `AXIOMS.md`). This task establishes only that
  `exp6_solve.zig`, `gtp.zig` (post-T265) and the artifact agree, and that
  `oracle_v2_accept.zig` does not.
- **No claim about the correctness of the stored `L`/`H` values.** Out of scope.
- The working tree carried another seat's in-flight `src/claimlint.zig` edit,
  which **fails to compile** (`src/claimlint.zig:1228: use of undeclared
  identifier 'loadRejections'`), so `zig build` is red at the time of writing.
  Not mine, not touched; flagged because it blocks a full build.

## 8. What I would check next

1. Fix `oracle_v2_accept.zig:150-165` to the kernel ko rule — or better, delete
   it and call the one implementation (DIRECTION §4.2) — then re-run A1/A2/A8.
   Prediction, recorded before the run so it can be wrong: A1 refusals → 0.
2. Fix `gtp.zig:1223` to query before `applyMove` (or with `-side`). Prediction:
   `genmove b` misses → 0.
3. Add C-B1–C-B4 to the Phase 1 battery with the K-series controls; specify
   C-A1/C-A2 against the Phase 2 kernel.
4. Grep the remaining ko copies for the same divergence before Phase 2 extraction
   — T265 fixed one of them, this task found the second, and DIRECTION says there
   are ~14.
5. Fix C7's `new_rows` scanner (§6a) — two one-line changes — and re-run it over
   the whole of `findings/` to see how many previously-proposed rows were never
   surfaced for absorption.

## 9. Reproduction

```sh
shasum -a 256 untracked/oracle-v2/oracle-4x4-v2.wzo2     # 0c3366f0…
python3 docs/evidence/ORACLE-V2/t266_scan.py untracked/oracle-v2/oracle-3x3-v2.wzo2 \
                                             untracked/oracle-v2/oracle-4x4-v2.wzo2
python3 docs/evidence/ORACLE-V2/t266_calibrate.py \
        untracked/oracle-v2/oracle-3x3-v2.wzo2 /tmp/weizigo/t266-mutants
python3 docs/evidence/ORACLE-V2/t266_scan.py --group untracked/oracle-v2/oracle-3x3-v2.wzo2 14717
python3 docs/evidence/ORACLE-V2/t266_scan.py --lookup untracked/oracle-v2/oracle-4x4-v2.wzo2 12 1 16 0
tools/runner -- zig build-exe --dep version -Mroot=src/oracle_v2_accept.zig \
        -Mversion=src/version.zig -femit-bin=/tmp/weizigo/accept
/tmp/weizigo/accept untracked/oracle-v2/oracle-3x3-v2.wzo2 a1
printf 'boardsize 4\nclear_board\ngenmove b\nquit\n' | \
        ./bin/weizigo-gtp untracked/oracle-v2/oracle-4x4-v2.wzo2
```

Captured stdout: `t266-scan-2026-08-02.stdout`, `t266-calibration-2026-08-02.stdout`.
