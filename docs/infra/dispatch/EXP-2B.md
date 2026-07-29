<!--managent set=A holds=src/qa023_probe.zig-->

# EXP-2B — QA-023 history-sensitivity probe (3×2)

**Closes:** the computational half of `QA-023`. **Blocks:** EXP-4.
**Blocked by:** nothing — this is independent of EXP-2 (Part A).

The task is **Part B of `docs/infra/dispatch/EXP-2.md`** — read that section in
full; it is the brief. Read also `docs/evidence/QA-023/audit-opus-2026-07-28.md`
for why the earlier attempt was void, and `004-opus-to-pi.md` in the live
milestone directory for the repair order.

**Why this is separate from EXP-2 (Part A).** Part A is a proof about whether the
state is sufficient. Part B is an empirical check that the same state reached via
different histories carries the same value. Neither needs the other's result, so
they run in parallel.

**Build precondition (mandatory, B-2 from the host incident).** All `zig`
builds on a host with a recent compressor incident run under `tools/runner`.
Use `tools/runner -- zig build-exe -O ReleaseFast src/qa023_probe.zig -femit-bin=…`
(or rely on the runner's auto-`-O ReleaseFast` and call it `tools/runner -- zig
build-exe src/qa023_probe.zig -femit-bin=…`). The runner SIGKILLs the process
group on a 4 GB RSS breach; the 2026-07-29 02:37 panic is the precedent
(`docs/infra/host/incident-2026-07-29.md`); the brief is `docs/infra/runner.md`.
**Builds without the guard are not your call to make; if the runner is
missing or the host's compressor is at >50% of segment limit, stop and
report.**

**KIND:** ANALYSIS plus one new source file. Do not touch `src/retro.zig`,
`oracle.zig`, `rules.zig`, `solve.zig`.

**ACCEPTANCE:** per EXP-2.md Part B — agreement across histories at every sampled
3×2 state, a **non-zero** cycle census (if zero, the board cannot test the claim:
escalate, do not report a pass), and a passing calibration case. 2×2 is a smoke
test only and is not evidence.

## B1 smoke — hard constraint (2026-07-29, post-thrash)

The 2×2 smoke has now **thrashed twice** — 75 min CPU at the 2026-07-29 02:37
panic and 87 min CPU on 2026-07-29 ~05:3x, both killed, zero useful output.
The cause is brief-level: the worker ran `qa023_brute_2x2.brute_value`, the
path-enumerating, no-memo brute from the earlier failed attempt — the exact
failure mode EXP-2.md Part B §B2 warns against. **Do not repeat it.**

- **B1 must not path-enumerate.** Do NOT use `qa023_brute_2x2.brute_value` or
  any full-history game-tree DFS for the 2×2 smoke. A path DFS enumerates
  *paths, not states*; cycle detection gives termination but not tractability,
  and it will thrash forever on a four-point board. For B1 use either (a) the
  probe's own **state-space value iteration** (the Part-A fixpoint on the 2×2
  `(board, side, ko, passes)` graph), or (b) a **full-tuple memo** on
  `(board, side, ko, passes)` — never a path DFS, never a state-only memo
  (that assumes the conclusion).
- **Run under `tools/runner` with a node budget + heartbeat.** Every
  evaluation carries an explicit node budget that **fails loudly** on
  exhaustion (never silently treat budget exhaustion as agreement); emit a
  heartbeat (≥1 progress line per minute). The runner SIGKILLs on a 4 GB RSS
  breach; the node budget catches the thrash before RSS moves (the thrash was
  RSS-flat at 1.7 MB — the runner alone would not have caught it, so the node
  budget is mandatory, not optional).
- **Do not pipe the run through `head -20`** (or any head/tee that swallows
  output). It masks progress and hides a thrash as silence. Run to a file or
  unbuffered stdout.
- **Expected 2×2 value is 0, not +1.** If the smoke returns +1 you have
  implemented PSK by accident (`docs/research/retrograde-3x3.md:224-245`).
- **Reuse, do not rewrite:** `src/qa023_probe.zig` (67 KB, 23 fns) is in the
  tree from the prior attempt; the census/calibration machinery beyond the
  B1 smoke looks real. Review-and-reuse it; replace only the B1 brute path.

**EVIDENCE:** `docs/evidence/QA-023/`.
