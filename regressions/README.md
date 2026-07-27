# Regressions — saved games for improvement & regression testing

These are saved game records used (a) to study engine weaknesses for
improvement and (b) as regression fixtures. Each game has:

- `<name>.sgf` — the game record (replayable in Sabaki / any SGF viewer).
- `<name>.gtp` — a GTP transcript that reproduces the game (feed it to
  `bin/weizigo-oracle <artifact.wzo>`). For a fixed transcript (both sides
  played, no `genmove`) the reproduction is **artifact-independent** (only the
  rules/scoring are exercised) and is mirrored by a `zig` test in
  `src/gtp.zig`.

## 4x4-history-blunder (B+15.5, komi 0.5)

User (Black) beat weizigo-oracle (White) on 4×4.

- **Why it's a fixture:** it exercises the **end-game** (two consecutive passes
  → `final_score` → winner declared), **captures/ko** (D4, A3, A4 are each
  played twice — captured and replayed), and a **`HISTORY-DIVERGED` blunder**:
  at move 8 (`W A4`) the fresh-start table said White wins 16 (`stored-v0=-16`)
  but in the actual game — with PSK history from the capture/ko fight — `W A4`
  gave Black +16. White played a fresh-start-optimal move that was a losing
  blunder in the real game.
- **Epistemic status:** the blunder is the C2 falsification in action
  (fresh-start ≠ real-game; falsified at 3×2, see AGENTS.md foreclosures). The
  engine is *fresh-start perfect*, not *history perfect*, and logs
  `HISTORY-DIVERGED` honestly. The win is legitimate — the user capitalized on
  the divergence.
- **Regression:** the fixed transcript (`4x4-history-blunder.gtp`) reproduces
  `B+15.5` artifact-independently and is asserted by the `zig` test
  `4x4 regression: user-win B+15.5 ...` in `src/gtp.zig` (final area score = 16,
  → B+15.5 with komi 0.5). It guards the rules/capture/PSK/scoring path.
- **Improvement tracking:** to see whether the engine blunders less over time,
  re-run the user's Black moves with the engine playing White
  (`genmove W` instead of `play W`) and watch the margin / divergence count.
  This is **not** a stable automated test (the engine's White replies change
  with engine changes, and the Black replays depend on prior captures) — run it
  manually as a quality probe.

### Reproduce
```
bin/weizigo-oracle data/oracle-4x4.checkpoint.wzo < regressions/4x4-history-blunder.gtp | tail
# expect: = B+15.5
```
(Swap the artifact path for `data/oracle-4x4-parallel.checkpoint.wzo` to see the
UNDEF-slot pass-out behavior on the research artifact.)
## Diagnosis (2026-07-27): why these games were lost

Both 4×4 regressions are **the same game up to board symmetry** through ply 17
(verified under the vertical mirror col c ↦ 3−c). The cause of the loss was
measured and is **not** the ko rule:

- Positional-superko bans changed the best available value at **0 of 19 plies**
  in each game (one ban fired, at ply 14; it was never the best move).
- The loss is the player **chaining unchainable values**: in the KO_SENSITIVE
  region the artifact's per-position fresh-start values do not satisfy the
  history-free Bellman identity, so `Session.choose`'s max/min over children's
  stored values is not an evaluation. 16 of 19 plies are KO_SENSITIVE, including
  ply 1 — on 4×4 the engine starts the game inside that region.
- The ply-16 collapse (stored −16 vs +16 one ply down) is **32 points = 2n**,
  the measured worst case: the entire board swing.

Full write-up, numbers and reproduction: `docs/research/ko-sensitive-chainability.md`.
Tool: `bin/weizigo-chainability`.
