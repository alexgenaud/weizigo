# AUDIT-2X2-MISMATCH — the 24 EXP-4 2×2 mismatches are a buffer-aliasing bug

**Task: AUDIT-2X2-MISMATCH · Role: auditor · Model: Opus 5 · Date: 2026-07-30**

## 1. Verdict

**The divergence is not genuine.** All 24 mismatches are an artifact of a
successor-buffer aliasing defect in `brute_value_2x2`
(`src/exp4_solve.zig:555-594`). Fix the buffer and the exact
first-revisit-truncation value agrees with the loopy-game fixpoint on **all
172** reachable non-terminal 2×2 states — not just the 3 I was asked to
verify, and not just the 24 disputed.

Where the two sides stood, and where they now stand:

| | EXP-4 as committed | this audit |
|---|---|---|
| fixpoint V at the 24 states | ±4 | ±4 — **correct** |
| first-revisit truncation | 0 | ±4 (both semantics agree) |
| mismatches, 172 non-terminals | 24 | **0** |
| budget-exhausted at 500k nodes/state | 0 | **164 of 172** |

The fixpoint was right the whole time. The brute force was wrong twice over:
wrong values, and a wrongly-cheap search that made the run look clean.

EXP-4's headline results are **unaffected and now better supported**: 2×2 root
(empty, either side) = 0 under basic-ko + TIE=0, reproduced independently here
(L=−4, H=+4, V=median=0, converged in 4 sweeps, L=Φ(L) and H=Φ(H) with 0
failures). Previously the root's brute-force corroboration came out of the
same defective evaluator; it now comes from an exact one.

## 2. Root cause

`src/exp4_solve.zig:555-594`. One successor buffer is threaded through the
entire recursion:

```zig
fn brute_value_2x2(
    state: Brute2x2.State,
    ...
    succs_buf: *[5]Brute2x2.State,          // <-- caller's buffer
) ?i8 {
    ...
    if (Brute2x2.State.apply_pass(state)) |ns| { succs_buf[m] = ns; m += 1; }
    for (0..N2_N) |cell| {
        if (Brute2x2.State.apply_place(state, @intCast(cell))) |ns| { succs_buf[m] = ns; m += 1; }
    }

    var best: ?i8 = null;
    for (succs_buf[0..m]) |child| {
        const v = brute_value_2x2(child, history_set, depth + 1, node_budget, succs_buf);
        ...                                                                  // ^^^ same buffer
    }
```

The node writes its own children into `succs_buf[0..m]`, then iterates that
slice. Zig loads slice element `k` at iteration `k`, and the recursive call on
iteration 0 overwrites `succs_buf[0..m']` with a deeper node's children. So
**every child after the first is read back as some unrelated state** — a state
that is generally not even a successor of the current node. `main` allocates
exactly one buffer (`src/exp4_solve.zig:757`, `:833`) and passes it in, so the
whole search shares it.

The corruption is deterministic, not stack garbage: at each node all `m` slots
are written before any is read, so the clobbering pattern is a fixed function
of the traversal. That is why the defect reproduces exactly (§3).

### Why the values come out as 0

At every one of the 24 states, child 0 is `pass` — the only slot read before it
can be clobbered — and the winning move is a capture sitting in slot 1 or 2,
which is read back as an unrelated state. The side to move therefore never sees
its win, and the reported value comes off the pass line instead of the capture:

- idx=1141 (`BW/..`, Black, passes=1): `pass` immediately ends the game at area
  score 0. The capture is `place 3` (→ +4).
- idx=329 (`WB/..`, Black, passes=0): `pass` → idx=1544, itself one of the 24
  and mis-evaluated by the same defect. The capture is `place 2` (→ +4).

The mismatch set is exactly the set of positions whose win is unreachable
through slot 0 — which is why it comes out as a clean, symmetric family of 24
rather than as scattered noise, and why it was mistaken for a semantic pattern.

### Why "budget-exhausted: 0" was also false

Reading garbage children short-circuits the search: a clobbered state is often
already on the current path, which returns `TIE` immediately instead of
recursing. That shrank the tree by orders of magnitude. Run the identical
search with per-frame buffers at EXP-4's own 500k-node budget and **164 of 172
states exhaust it** (independently: 164 in Zig, 164 in Python). The honest
un-pruned first-revisit-truncation tree on 2×2 does not fit in 500k nodes.

EXP-4 §3's "148 agreements, 24 mismatches, 0 exhausted" therefore has no sound
denominator: the 148 "agreements" were produced by the same corrupted
evaluator and are coincidences, not confirmations.

## 3. Reproduction and repair

Two independent lines of evidence, in two languages.

**(a) Repair in place** — `src/audit_2x2_mismatch.zig` runs three evaluators
over every reachable non-terminal state against the same fixpoint tables:

| evaluator | difference from EXP-4 | disagreements | exhausted |
|---|---|---|---|
| (A) `brute_shared` | none — verbatim copy | 24 | 0 |
| (B) `brute_local` | successor buffer is a frame local | 164 | 164 |
| (C) `brute_ab` | frame-local buffer + alpha-beta | **0** | **0** |

(B) is (A) with one declaration moved; it isolates the defect. (C) adds
alpha-beta because (B) proves the exact search does not fit in a plain budget.
Alpha-beta is sound here: first-revisit truncation is an ordinary minimax over
a (path, state) tree, pruning only skips subtrees, and there is **no
transposition table**, so no path-dependent value is ever reused across paths.
With a full window the root value is exact whatever the move order; ordering
(most-favourable-material first) only changes the node count and is computed
from the goban alone, independent of the fixpoint tables.

Total alpha-beta cost: 20,527,408 nodes over 172 states, max 339,959 for a
single state.

**(b) Independent reimplementation** —
`docs/audits/2026-07-30-audit-2x2-mismatch.py` rewrites rules, state encoding,
area scoring, the L/H fixpoint, and the truncation evaluator from the
specification, sharing no code with the Zig. It reproduces:

- reachability 258 / 172 non-terminal / 86 terminal — matches EXP-4
- fixpoint in 4 sweeps, root L=−4 H=+4 V=0, L=Φ(L)/H=Φ(H) failures 0
- exact FRT vs fixpoint: **0 mismatches, 0 exhausted, 20,527,408 nodes**
  — the node count is *identical* to the Zig's, from two implementations
  written independently
- plain FRT at 500k budget: 164 of 172 exhausted — matches the Zig
- and, with the shared buffer deliberately emulated: **24 mismatches, index
  set identical to EXP-4's, per-state values identical** (fixpoint ±4,
  brute 0)

That last line is the causal proof. Injecting one defect — a single shared
5-slot list in place of per-frame lists — into an otherwise independent
implementation reproduces EXP-4's output exactly, all 24 indices and all 24
values. Nothing else about EXP-4's run needs to be wrong to explain the
mismatches, and nothing less than that explains them.

## 4. The three hand-verified states

Goban geometry. 2×2, cells row-major

```
0 1
2 3
```

adjacency is the 4-cycle 0–1–3–2–0; **0/3 and 1/2 are diagonal, not
adjacent**. Consequence: any two *adjacent* cells holding opposite colours put
both stones in atari simultaneously — W at 0 has only liberty 2, B at 1 has
only liberty 3 — so whoever moves captures. All 24 mismatch states are exactly
this shape (4 adjacent pairs × 2 colour orders × relevant `passes` values), and
the capture takes the whole goban.

### idx=329 — `WB/..`, Black to move, ko none, passes 0 → **+4**

Black's legal moves: `pass`, `place 2`, `place 3`.

1. **Black `place 2`.** Goban becomes `WBB.`; W's chain {0} now has neighbours
   1(B) and 2(B), no liberty → removed. Goban `.B/B.`. The placed stone at 2 is
   a lone stone (1 and 2 are diagonal, so no friendly connection) with
   liberties 0 and 3 → not suicide, legal.
   Ko test: `opp_before − opp_after = 1`, `captured_cell = 0`, but the placed
   stone has **2** liberties, not 1 → no ko point. Correct: basic-ko
   formalization (i) cannot fire on 2×2.
2. **White is forced to pass.** `place 0`: neighbours 1(B), 2(B); the B chains
   {1} and {2} each keep liberty 3, so nothing is captured and the new W stone
   has zero liberties → suicide, illegal. `place 3` is illegal for the same
   reason. Pass is White's only legal move.
3. **Black passes** → passes=2, terminal `.B/B.`. Area: 2 black stones; empty
   {0} borders 1(B) and 2(B) only, empty {3} borders 1(B) and 2(B) only → both
   Black territory. Black 4, White 0 → **+4**.

+4 is the maximum attainable on 4 points, and the line terminates in 3 plies
with no repeated state, so it is available under loopy-game *and*
first-revisit-truncation semantics alike. Both must return +4. Machine check:
`L=+4 H=+4 V=+4`, exact FRT `+4`, shared-buffer emulation `+0`.

Children as the solver enumerates them: `pass`→−4, `place 2`→+4,
`place 3`→+0. Slot 0 is `pass`; the win is in slot 1.

### idx=734 — `WB/..`, White to move, ko none, passes 0 → **−4**

The colour mirror. White `place 3` fills B's last liberty: B's chain {1}
(neighbours 0(W), 3(W)) is removed → `W./.W`; the placed stone at 3 has
liberties 1 and 2, legal; no ko (2 liberties). Black is then forced to pass
(`place 1` and `place 2` are both suicide against the W stones at 0 and 3).
White passes → terminal `W./.W`: 2 white stones plus empties {1} and {2}, each
bordering White only → White 4 → **−4**.

`L=−4 H=−4 V=−4`, exact FRT `−4`, shared-buffer emulation `+0`.
Node counts confirm the symmetry: idx=734 costs 44,723 alpha-beta nodes,
identical to its mirror idx=331.

**This state is also the `1-ko shape` anchor** — see §5.

### idx=1141 — `BW/..`, Black to move, ko none, passes 1 → **+4**

One pass has already been made, so `pass` ends the game immediately: terminal
`BW/..` scores 1 black stone − 1 white stone, with the empty region {2,3}
bordering both colours → neutral → **0**. This is the cleanest illustration of
the failure mode: 0 is exactly what the defective evaluator returns, because
`pass` is slot 0.

Black's winning move is `place 3`: neighbours 1(W) and 2(empty); W's chain {1}
(neighbours 0(B), 3(B)) has no liberty → removed → `B./.B`, passes resets to 0.
White is then forced to pass (`place 1`, `place 2` both suicide), Black passes,
terminal `B./.B` → **+4**.

`L=+4 H=+4 V=+4`, exact FRT `+4`, shared-buffer emulation `+0`.
Children: `pass`→+0, `place 2`→+0, `place 3`→+4.

Per-state checkpoints were written to `/tmp/audit-2x2-mismatch.log` as each
state was verified; the file is preserved as
`docs/audits/2026-07-30-audit-2x2-mismatch.stdout`.

## 5. Collateral: the `1-ko shape` anchor is a wrong expected value

`src/qa023_brute_2x2.zig:456-487` asserts

```zig
const s = State{ .board = [_]i8{ -1, 1, 0, 0 }, .side = -1, ... };
try expect(value(s) == 0);
```

That is idx=734. Its value is **−4**, by hand in §4 and by both machine
evaluators. The test's own comment reasons correctly that basic-ko
formalization (i) never fires on 2×2 — that part is right — and then
concludes "*(The 2x2 result must still be 0; this test asserts it.)*" That is a
non-sequitur: 0 is the value of the **empty-goban root**, not of an arbitrary
non-root position. `W B/. .` with White to move is a won game for White.

This matters beyond the test, because EXP-4 §3 recorded the disagreement as
"*anchor brute-force (7 states) | 6/7 agree; 1-ko shape fixpoint=−4 vs
brute=0*" and let it stand as evidence against the fixpoint. Both the anchor's
expected value and the brute-force number were wrong; the fixpoint's −4 was
right.

The test appears to pass today only because `qa023_brute_2x2.value()` is a
correct un-pruned FRT search whose tree at this state exceeds 500k nodes — I
could not resolve it inside this audit's time box (`zig test -O ReleaseFast
--test-filter "1-ko shape"` had not terminated when I stopped). Whether it
currently passes, fails, or simply never finishes is **not established here**;
the expected value being wrong is established regardless.

## 6. Spillover — same defect in four more solvers, not re-verified

The identical shared-buffer pattern appears in every descendant of this
function:

| file | function | lines |
|---|---|---|
| `src/exp4_solve.zig` | `brute_value_3x2` | 598-644 |
| `src/exp5_solve.zig` | `brute_value` | 995-1041 |
| `src/exp6_solve.zig` | `brute_value` | 824-862 |
| `src/exp6_hchain_audit.zig` | `brute_value` | 829-867 |

These are **worse** than the 2×2 case, because they also filter on the
clobbered goban buffer:

```zig
for (0..m) |k| {
    if (!is_legal3(&succ_boards_buf[k])) continue;   // clobbered board
    const child = succs_buf[k];                      // clobbered state
    const v = brute_value(child, ..., succ_boards_buf, succs_buf);
```

so children can be silently **skipped** as well as misidentified.

Consequences I did **not** re-run and am flagging rather than asserting:

- EXP-4's 3×2 cross-check (§4 of the research note: "165 agreements, 0
  mismatches, 335 budget-exhausted", and the root evaluation exhausting 10M
  nodes) is unsound as evidence in both directions. Its exhaustion counts are
  understated for the same reason as 2×2's.
- Any brute-force cross-check in EXP-5 (3×3), EXP-6 (4×4), or the EXP-6 H-chain
  audit that used these functions carries the same defect. Absence of
  mismatches there is not evidence of agreement.

Fixing all four is a one-line change per function (make the buffers frame
locals) plus alpha-beta or a much larger budget to make the corrected search
tractable. That is beyond this audit's scope.

## 7. Documentation corrections

- `docs/research/newrule-2x2-3x2-2026-07-28.md` §3, §7, §9: the sentences
  asserting "*genuine semantic divergence between loopy-game and first-revisit
  semantics at non-root positions*" at 2×2 should be **retracted**. There is no
  divergence at 2×2: 0 mismatches over all 172 reachable non-terminal states.
- §7 also offers the 2×2 gap as corroboration of the PINRULE-SUFFICIENCY 3×2
  finding ("*the same class of divergence … Here it appears even for
  empty-history (fresh-start) evaluations*"). That corroboration is void. The
  3×2 finding must stand or fall on its own evidence, which I did not examine.
- §9's `2x2.BASICKO-TIE` claim keeps **CLAIMED**, but the qualifier "*the
  24/172 non-root mismatches are a known semantic divergence*" should be
  replaced by: exact first-revisit truncation agrees with the fixpoint on all
  172 reachable non-terminal states (independent Zig and Python evaluators,
  20,527,408 nodes each).
- §6's calibration note is stronger than it reads: the perturbation test was
  called "inconclusive", and the anchor suite reported 6/7 — but one of those
  seven anchors had a wrong expected value and the evaluator producing all
  seven was defective. The calibration did not detect either. Worth recording
  as a calibration miss, not just a weakness.
- Cosmetic: `src/qa023_brute_2x2.zig:244` comments `TOTAL_STATES` as
  "`= 1620 for 2x2`" and `src/exp4_solve.zig:44` repeats "`// 1620`". The
  expression `81 * 2 * (n + 1) * 3` evaluates to **2430**. Harmless
  over-allocation — and the research note's "0 / 2430" inversion count is
  consistent with 2430 — but the comments are wrong.

## 8. What could not be established

- Whether the `1-ko shape` test in `src/qa023_brute_2x2.zig` currently passes,
  fails, or hangs (§5). Its expected value is wrong either way.
- Anything about 3×2, 3×3, or 4×4. The spillover in §6 is a code-identity
  finding, not a re-verification. I did not re-run EXP-4's 3×2 half, EXP-5,
  EXP-6, or EXP-7.
- Whether the loopy-game fixpoint is the *right* semantics for the project's
  rule. This audit establishes only that at 2×2 it agrees exactly with
  first-revisit truncation, so the two cannot be told apart there — which also
  means 2×2 has no discriminating power between them.

## 9. Files

- `docs/audits/2026-07-30-audit-2x2-mismatch.md` — this file
- `docs/audits/2026-07-30-audit-2x2-mismatch.py` — independent Python verifier
- `docs/audits/2026-07-30-audit-2x2-mismatch.stdout` — Python run output
  (also the per-state checkpoint log, `/tmp/audit-2x2-mismatch.log`)
- `src/audit_2x2_mismatch.zig` — three-evaluator comparison in Zig
- `docs/audits/2026-07-30-audit-2x2-mismatch-zig.stdout` — Zig run output

Reproduce with:

```
tools/runner -- zig run -O ReleaseFast src/audit_2x2_mismatch.zig
python3 docs/audits/2026-07-30-audit-2x2-mismatch.py
```

Both complete in under two minutes.
