# Regressions — saved games for improvement & regression testing

These are saved game records used (a) to study engine weaknesses for
improvement and (b) as regression fixtures. Each game has:

- `<name>.sgf` — the game record (replayable in Sabaki / any SGF viewer).
- `<name>.gtp` — a GTP transcript that reproduces the game (feed it to
  `bin/weizigo-oracle <artifact.wzo>`). For a fixed transcript (both sides
  played, no `genmove`) the reproduction is **artifact-independent** (only the
  rules/scoring are exercised) and is mirrored by a `zig` test in
  `src/gtp.zig`.
- `<name>.txt` — where present, the raw engine log of the live `genmove`
  session (per-ply `child-value` / `stored-v0` / `KO_SENSITIVE` lines).

## 4x4-history-blunder (B+15.5, komi 0.5)

User (Black) beat weizigo-oracle (White) on 4×4.

- **Why it's a fixture:** it exercises the **end-game** (two consecutive passes
  → `final_score` → winner declared), **captures/ko** (D4, A3, A4 are each
  played twice — captured and replayed), and the engine's own
  `HISTORY-DIVERGED` reporting. The collapse is at **ply 16** (White's 8th
  move, `W A4`): the table's stored value for that node is **−16** (White
  winning by 16) while the best child value in the *same* table is **+16** —
  a 32-point gap.
- **Companion game:** `4x4-black-win-after-ko.txt` is the same game up to board
  symmetry through ply 17 (verified move-by-move under the vertical mirror,
  column c ↦ 3−c; value and area traces identical throughout). Ply 18 differs —
  a tied-value choice broken differently.

### Why White lost (measured 2026-07-27) — not the game's ko history

- A depth-1 history probe replaying both 4×4 regression games found
  positional-superko bans changed the best available value at **0 of 19 plies**
  in each game. Exactly one ban fired per game (ply 14) and it was never the
  best move. At the ply-16 collapse, **zero** PSK bans were active. The game's
  accumulated history did not remove White's winning move.
- The cause is that the table is **not chainable**
  (`docs/epistemic/GLOSSARY.md`) in the ko-sensitive region. Each ko-sensitive
  slot holds an *independent fresh-start* positional-superko solve, so `V0(P)`
  and a one-ply lookahead over `V0(child)` are under no obligation to agree.
  `Session.choose` takes an extremum over stored child values anyway, so it is
  steering by a quantity that is not defined there. At ply 16 the disagreement
  is the full board swing: 32 = 2n.
- Ko/PSK **is** ultimately why the region is unchainable — the bans live deep
  inside each slot's own subtree. What is false is the narrower claim that the
  *game's* history removed a move at that node.
- **16 of 19 plies are KO_SENSITIVE-flagged, including ply 1** — the empty 4×4
  board itself (bracket [−6, +16], i.e. L < H). On 4×4 the engine does not
  *enter* the unchainable region when a ko appears; it starts the game there.
- Sweep (`bin/weizigo-chainability <artifact>`, 2026-07-27; exhaustive at
  2×2/3×2/3×3/4×3, `--sample 37` at 4×4 on `data/oracle-4x4.checkpoint.wzo` =
  657,566 positions / 1,313,248 slots): ko-sensitive share of checked slots
  77.36 / 41.18 / 35.04 / 26.60 / 21.27 %, misprice rate *within* it
  19.51 / 19.05 / 7.91 / 3.58 / 4.08 %, max |stored − bellman|
  2 / 12 / 18 / 24 / 32. Max misprice = **2n exactly** for n ≥ 6 (the full area
  swing over [−n, +n]); 2×2 is the exception. **CLAIMED** — an observed
  regularity over four sizes, no proof offered, and per-board epistemic
  independence forbids extrapolating it.

### Epistemic status

The applicable claim is **C4** (fresh-start ≠ real-game on ko-sensitive
positions), plus the unchainability finding above — **not** C2. C2 is scoped to
the single-score (L==H) region, and every blundering node in these games is
KO_SENSITIVE-flagged (L < H), entirely outside C2's scope. For C2's own region
the sweep is *positive* news: **zero** identity violations outside the flag at
every size tested, with violations exactly co-extensive with the KO_SENSITIVE
flag (16/16, 72/72, 688/688, 6,092/6,092, 11,402/11,402).

The *table* is fresh-start-exact per slot (C1-level). The *player* is **not**
fresh-start-perfect in the ko-sensitive region, because chaining per-slot
fresh-start values is not a fresh-start strategy. Ply 14 of the companion game
shows it directly (`4x4-black-win-after-ko.txt:74`):

```
oracle: W -> D1  child-value=-16 stored-v0=-3 (HISTORY-DIVERGED) KO_SENSITIVE
```

The node's own fresh-start value is −3, yet the player chose a child valued
−16; a genuinely fresh-start-perfect player would achieve −3 there.

The engine logs `HISTORY-DIVERGED` honestly. The win is legitimate — the user
capitalized on a real engine defect.

Full write-up, numbers and reproduction:
`docs/research/ko-sensitive-chainability.md`. Tool: `bin/weizigo-chainability`
(source `src/chainability.zig`).

### Regression

The fixed transcript (`4x4-history-blunder.gtp`) reproduces `B+15.5`
artifact-independently and is asserted by the `zig` test
`4x4 regression: user-win B+15.5 ...` in `src/gtp.zig` (final area score = 16,
→ B+15.5 with komi 0.5). It guards the rules/capture/PSK/scoring path.

### Improvement tracking

To see whether the engine blunders less over time, re-run the user's Black
moves with the engine playing White (`genmove W` instead of `play W`) and watch
the margin / divergence count. This is **not** a stable automated test (the
engine's White replies change with engine changes, and the Black replays depend
on prior captures) — run it manually as a quality probe.

### Reproduce
```
bin/weizigo-oracle data/oracle-4x4.checkpoint.wzo < regressions/4x4-history-blunder.gtp | tail
# expect: = B+15.5
```
(Swap the artifact path for `data/oracle-4x4-parallel.checkpoint.wzo` to see the
UNDEF-slot pass-out behavior on the research artifact.)
