# 3x3 forward fresh-start filling: measured intractable (2026-07-17)

**Dead-end.** Forward building of the 3×3 fresh-start oracle (the
oracle.zig prototype, with the validated solve.zig semantics) is not tractable.

**How we know.** Three measurements, all ReleaseFast in `src/oracle.zig`:
- Cold ascending sweep from empty: no progress in >5 min (the empty root
  alone is the full 3×3 solve through a GHI-tainted, unmemoizable opening).
- Warm bottom-up sweep (8-stone endgame roots first): after 13:49 min
  (826 CPU-s) still inside layer 8 (the 402 8-stone roots). Killed.
- Single-root probes (10M-node budget): the first two legal 8-stone roots
  each exceeded 10M nodes (~7 s apiece), with search lines reaching
  2,186 and 1,958 plies deep on a 9-cell board.

**Why.** An "endgame" root is not small: its best line often captures and
reopens the board (the ADR-0006 eye-prune only protects Benson-alive
groups). The reopened subtree is the whole game; its ko-affected core is
GHI-tainted so the memo never keeps it; every root pays it again. Under
positional superko, individual lines are legal for thousands of plies
(capture cycles that never exactly repeat a position) so each unmemoized
descent is astronomically deep. Cost: ≥10M nodes/root × 25,350 roots — years.

**Lesson.** Forward fresh-start filling cannot build the oracle even at 3×3.
Closes the question empirically at the smallest interesting scale; the
retrograde engine (ADR-0009) is the critical path, not an optimization.
What remains valid: the rules kernel, the validation battery, and the
fresh-start score semantics (ADR-0008). Full write-up is in git history.
