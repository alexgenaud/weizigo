# Forward full-solve of empty 5x5: measured intractable (2026-07-16)

**Dead-end.** The naive approach (forward exhaustive minimax + transposition
table from the empty board) is not a route to the oracle.

**How we know.** `src/main.zig` with `FULL=true`, `-Doptimize=ReleaseSafe`,
wired+sized TT (256 MB blind arrays + 2 GB seq; ~2.3 GB resident). After
several minutes: `max_ply` climbed to 200–210 and plateaued; `tt_blocks`
stayed at 1 (TT cached zero blocks; GHI-tainted opening cannot safely cache).
Killed without completion. Confirmed: recursion depth is a *ply* count, not
a stone count — 3×3 lines exceed 2,100 plies (`research/oracle-3x3.md`).

**Lesson.** Builds the case for the retrograde direction (ADR-0007/0009):
scores must propagate from terminals over an enumerated canonical set, with
history-independence handled structurally rather than by the forward
search's "don't cache if tainted" — which here caches nothing. `solve.zig`
remains valid as a *correctness reference* on small / near-terminal roots.
Full write-up (with reproduction commands) is in git history.
