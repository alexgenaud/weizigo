# Root cause: the depth-7 transposition "overwrite" bug (FIXED)

**Dead-end resolved.** Commit 39dbe4a (titled "Bugs in black/white
symmetries") reported a collision dump: one canonical `(blind, color, seq)`
key resolving to two different scores. The measurement harness
(`src/measure.zig`, since retired per ADR-0007) reproduced and localized
it: 5×5 depths 1–6 are clean; depth 7 trips `set_game_score` "overwriting
… old=−1 with new=3".

**Not a symmetry bug.** Every collision dump showed `inverse=true`, but
that's incidental (the orbit's canonical form is an inverse one) and the
inversion arithmetic is consistent. The real cause is **repetition + horizon**.

**Mechanism (two coupled defects, now both fixed):**
- **P1 — repetition not prevented.** Ko/superko is not implemented in the
  old `minimax.zig` (`KoRepeat` was an unused enum member). A position can
  appear inside its own search subtree: B at ply 5, `get(B)` misses,
  recursion starts; within B's own subtree a capture/recapture cycle
  reaches B again at ply 7; `get(B)` still misses → B is searched and
  stored twice.
- **P2 — horizon-limited value in a depth-agnostic table.** In a depth-7
  search, B at ply 7 is a leaf (pos_score = −1) while B at ply 5 has 2
  plies of lookahead (= 3). Different horizon → different score; the key
  has no depth, so the two writes collide.

Captures are the enabler: they decouple stone-count from ply-depth,
letting the same low-stone board recur at different plies.

**Fix.** P2 → score at true settled terminals (Benson + area), depth-
independent. P1 → positional superko (finite, acyclic-enough tree).
Remaining subtlety → GHI (see `ghi-and-superko.md`); the ko_ref GHI
caching rule is in `solve.zig`; the safer Kishimoto–Müller dependency-
guarded memo is in ADR-0013. See `decisions/0004`.

**Lesson.** A transposition table that lacks either horizon or history
keying will silently alias — the kind of bug no symmetry or anchor test
catches. "Sound by construction" needs a falsifiable auditor; see
`consistency-audit.md` (the bug this hid was finally convicted by the
#2 self-consistency auditor on a 3×2 sample).
