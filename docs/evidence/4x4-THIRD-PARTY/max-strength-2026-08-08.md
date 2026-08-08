# T420 — full-strength third-party engines: a better falsifier, not a stronger opponent

Task: T420 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-08
Identifier: `deepseek-v4-flash/T420` (abbr. `flash/T420`)

**Landmark line: L0 (the engine does not lose from claimed-won positions) — advanced.**
What a human can now see that they could not before: T381's claim-witnessing
result was *not* an artefact of weak opponents. GNU Go was already at its
documented maximum (level 10 = default), Pachi was cranked from ~11.5k to
~50–106k simulations per move (54.2M playouts, every move recorded), Fuego was
run with an explicit 1,000,000-game cap (its default is already uncapped) and
still the table's claimed-won positions held: **losses from claimed-won
0/68 per engine (0/136 new games; GNU Go 0/68 carried), ties-from-claimed
0/136**. What still stands in the way: 136 new games is still a sample, not a
proof; the ko-sensitive rows remain the untrusted region; C2 (real-game
history-independence) remains falsified at 3×2 regardless of any play result.

---

## 1. Why this row exists — strength is irrelevant, independence is everything

T381 established the falsification design: play the 4×4 oracle against engines
that share no code, no table and no author with it, and count only the
informative result — a loss (or tie) *from a position the table claims won for
our side*. The operator's question, relayed 2026-08-08: *"Can we crank GNU Go,
Pachi, or Fuego up to a higher skill level?"*

The reframe, from the brief and kept throughout: on 4×4 the game is decided
from the opening, and our engine plays table-optimal moves. A stronger
opponent therefore **cannot** beat us from a position the table claims won —
**if it ever does, the table is wrong, and that is the entire point of the
row**. This is a falsification instrument, not a strength contest. Question 1
below outranks every other result in the project's queue; the brief orders a
full stop and a full game record if it ever returns non-zero.

## 2. What "full strength" means per engine — established by probing, not assumed

The brief's standing rule: *verify each setting is actually in effect, do not
assume a flag was honoured.* The probe sequence (`weizigo-t381-evse --probe
--strong --engine <name>`, additive `--strong` mode) re-ran the T381 ruleset
probes under the strong settings **and** reported each engine's own
configuration and an achieved-playout measurement. Results:

| engine | strong setting | confirmed in effect? | headroom vs T381 |
|---|---|---|---|
| GNU Go 3.8 | `--level 10` (explicit) | yes — invocation accepted; `gnugo --help` documents level 0–10, **default 10** | **NONE** — T381 already ran at maximum. Honest result: *no headroom*, not a re-run. T381's 68 GNU Go games are carried as the full-strength measurement. |
| Pachi 12.90 | `threads=8 reportfreq=1000000 -t =50000` | yes — probe move achieved **58,828** simulations vs 50,000 requested | **REAL** — and a T381 correction surfaces: T381's `-t =1000` did **not** run 1000 simulations. Pachi enforces a ~0.1 s minimum search, so `=500`, `=1000`, `=10000` all landed on the same ~11.5k-simulation floor. The strong run is ~4–9× more search per move. |
| Fuego 1.1.SVN | `uct_param_player max_games 1000000` (time budget unchanged at `0 1 1`) | yes — `uct_param_player` reports `max_games 1e+06`; probe move achieved **194,095** GamesPlayed | **NONE in practice** — Fuego's default `max_games` is already `1.79769e+308` (uncapped; confirmed by querying `uct_param_player` before any setting). The search terminates on its own on 4×4 (~0.07–2.2 s, ~30–230k playouts/move) regardless of the time budget: `time_settings 0 1 1` vs `0 5 5` measured identical (~170k playouts on a midgame position). The 1,000,000 cap is set explicitly so the configured value is recorded; it does not bind. |

Ruleset parity was re-probed at the strong settings for all three engines:
ko recapture rejected, suicide rejected, `final_score` quirks unchanged —
**the same game** (Chinese area, komi 0, no suicide, basic ko) as T381, with
Fuego's `go_param_rules ko_rule simple` retained (its default positional
superko remains a different game; T381's discovery stands).

## 3. Method

**Instrument** — additive changes to `src/t381_evse.zig` (SHA
`fa32d563…`, at git HEAD `07d8c54`; build.zig untouched; engine sources
untouched; reads the artifact and the committed session/table code
`gtp.zig`/`rules.zig`/`artifact2.zig` only). New, gated by a `--strong`
flag so T381's baseline behaviour is unchanged:

- `engineForStrong()` — the three strong configurations of §2.
- **Achieved-strength recording per game, per engine move** — not the flag
  we passed:
  - *Pachi*: the GTP client now captures stderr (additive
    `spawnWithStderr`/`drainStderr`, poll-based, drained between commands so
    the pipe never fills) and parses Pachi's per-move `*** WINNER is X
    (A/B games)` summary — the only reliable per-move simulation counter
    (Pachi's own `pachi-result` reports an unrelated number, e.g. 13,502 vs
    the actual ~52k). `reportfreq=1000000` suppresses intermediate progress
    lines so stderr stays ~800 B/move.
  - *Fuego*: after each engine move, the read-only `uct_stat_search` GTP
    command is queried and `GamesPlayed` is parsed.
  - *GNU Go*: level 10 is a startup flag with no runtime counter; recorded
    as configured (documented default/max).
- Every game record gains `strength` (configured), `playouts[]` (per engine
  move), `playouts_total`, `playouts_missing`. Per-colour summary counters
  added (wins/losses/ties, losses-from-claimed, wins-from-non-claimed-roots,
  inside-root, capped, playout totals) so no figure ever needs merging by
  hand.

**Corpus and scoring** — identical to T381: the T366 corpus verbatim (3
canonical one-ply + 30 seeded random two-ply, seed 42, deduplicated = 33)
plus the empty goban = 34 openings × 2 colours = 68 games per engine.
Same scoring path: our `area_score` of the final position (every engine's
`final_score` is unreliable at 4×4 — GNU Go returns B+16.0 for an empty
board; recorded per game as data, never used). Ply cap 400, reported in its
own class (T381 had 1 capped game; **this run: 0 capped**).

**Build and run** (ad-hoc under `tools/runner` with its RSS guard, per the
standing rule):

```
zig build-exe -O ReleaseFast --dep version -Mroot=src/t381_evse.zig \
  -Mversion=src/version.zig --cache-dir /tmp/weizigo/t420/cache \
  --global-cache-dir /tmp/weizigo/t420/global --name weizigo-t381-evse \
  -femit-bin=/tmp/weizigo/t420/t381-evse
tools/runner -- /tmp/weizigo/t420/t381-evse --strong --engine <name> --json <path>
```

Pachi run: 185.8 s wall, peak RSS guarded by the runner. Fuego run:
353.5 s wall. Both exit 0.

## 4. The three questions — answers at full strength

All runs: 34 openings × 2 colours = 68 games per engine against
`data/oracle-4x4-v2.wzo2` (SHA `0c3366f0…`, same artifact T381 tested).

### Q1 — the one that outranks everything: no engine beat us from a claimed-won position

| engine (strength) | games | W–L–T | capped | claimed-won roots | results of claimed-won roots | **losses from claimed-won** | ties from claimed-won |
|---|---|---|---|---|---|---|---|
| GNU Go 3.8 (level 10, carried) | 68 | 46–21–1 | 0 | 39 | 39 W / 0 L / 0 T | **0 / 68** | 0 / 68 |
| Pachi 12.90 (=50000, threads 8) | 68 | 38–28–2 | 0 | 34 | 34 W / 0 L / 0 T | **0 / 68** | 0 / 68 |
| Fuego 1.1.SVN (max_games 1M) | 68 | 58–5–5 | 0 | 34 | 34 W / 0 L / 0 T | **0 / 68** | 0 / 68 |
| **total (new / carried)** | **136 new + 68 carried** | — | 0 | 107 | 107 W / 0 L / 0 T | **0 / 136 new, 0 / 68 carried** | 0 / 136 |

**The table was not refuted.** Every position the table claimed won for the
side we played was won, against Pachi searching ~50–106k simulations per move
and Fuego at an explicit 1M-game cap (its uncapped default). The 33 losses
(28 Pachi + 5 Fuego) all came from roots the table claimed for the
**opponent** — correct play on the losing side of a decided position, exactly
T381's reading. Colour split (never merged — the game is not colour-symmetric):

| engine | colour | W–L–T | losses from claimed-won | claimed-won roots | all won |
|---|---|---|---|---|---|
| GNU Go (carried) | B | 29–4–1 | 0 / 34 | 28 | yes |
| GNU Go (carried) | W | 17–17–0 | 0 / 34 | 11 | yes |
| Pachi | B | 27–6–1 | 0 / 34 | 27 | yes |
| Pachi | W | 11–22–1 | 0 / 34 | 7 | yes |
| Fuego | B | 33–1–0 | 0 / 34 | 27 | yes |
| Fuego | W | 25–4–5 | 0 / 34 | 7 | yes |

The colour asymmetry is the game, not the engine: the 4×4 root is
`[L=1,H=16]`, Black-favoured; White still holds 7–11 claimed-won roots (the
openings White wins from) and wins all of them.

### Q2 — wins from opponent blunders did NOT fall with strength

T381 won 35 games from roots the table did **not** claim for us (their
error, not our claim). If those were mostly opponent weakness, they should
shrink at full strength. Per engine, per colour (T381 → T420):

| engine | B | W | total |
|---|---|---|---|
| GNU Go | 1 → carried | 6 → carried | 7 → carried |
| Pachi | 0 → 0 | 5 → **4** | 5 → **4** |
| Fuego | 5 → 6 | 18 → 18 | 23 → **24** |

**Read: no meaningful drop** (Pachi 5→4; Fuego 23→24, +1). The earlier
margin was **not** primarily opponent weakness at these strength levels —
Pachi's error wins barely shrank despite ~5× the search per move, Fuego's did
not shrink at all (consistent with §2's finding that Fuego's 4×4 search
already saturates). The W-side numbers are structural: White wins mostly from
positions the table does not claim for White, because the 4×4 game is
Black-favoured.

### Q3 — no outcome left the root bracket [L,H]

T381 measured outcome-inside-root at 39/37/36 of 68. At full strength:
Pachi **40/68** (B 27/34, W 13/34; T381 37/68 = B 26, W 11), Fuego **36/68**
(B 25/34, W 11/34; T381 36/68 = B 25, W 11). No excursion in either engine —
the same alarm as T407's B3, on the harder sample, stayed quiet. In-bracket
counts are the same or slightly better than T381; the small Pachi
improvement is engine RNG, not a claim (T381 already noted Pachi varies
52/68 across runs).

## 5. Achieved strength — recorded per move, per game, never assumed

`playouts[]` is recorded for every engine move in every game (0 unreadable in
272 engine-move-sequences… precisely: 720 Pachi moves and 608 Fuego moves,
**playouts_missing = 0 in both runs**). Aggregate:

| engine | configured | engine moves recorded | playouts per move (min / avg / max) | total playouts | unreadable |
|---|---|---|---|---|---|
| Pachi | `threads=8 -t =50000` | 720 | 16,827 / **75,342** / 404,105 | **54,246,090** | 0 |
| Fuego | `max_games 1000000` (default ∞) | 608 | 1 (endgame pass) / **36,555** / 604,393 | **22,225,695** | 0 |

Fuego's min of 1 is an endgame pass — Fuego evaluates a decided endgame with a
single simulated game and passes (all such entries sit at the tail of games
that end in two passes; e.g. `fuego-o00-W` playouts `[…, 1, 1, 6751, 2143, 1,
1, 1, 1]` followed by `db dd pass pass`). Mid-game Fuego moves run 50–100k
playouts; the average is pulled down by cheap passes.

## 6. Controls

- **Null control (determinism of the strong harness)** — a completed game's
  recorded move list replayed through a *fresh* engine instance at the strong
  settings (play only, no genmove); the harness must reproduce the identical
  score with every move accepted:
  - `--strong --engine pachi --nullctl pachi-o33-B` — recorded 16, replay 16, **MATCH**, all moves accepted.
  - `--strong --engine fuego --nullctl fuego-o00-B` — recorded 2, replay 2, **MATCH**, all moves accepted.
- **GNU Go strong-configuration check** — `--probe --strong --engine gnugo`
  confirms `--level 10` is accepted, ruleset probes pass, and reports the
  documented default/max (§2). No game re-run: the level was already at its
  maximum in T381.
- **Score authority** — `--selfscore` recomputes a recorded game's score from
  its move list with no engine: `pachi-o33-B` 16=16, `fuego-o33-W` −2=−2. The
  result is a pure function of the position.
- **Move quality** — zero chainability refusals in 1,363 our-positions across
  both runs (Pachi 724, Fuego 639). Non-optimal plies: Pachi **0**; Fuego
  **33**, every one the designed pass-override heuristic (`chooseV2`: with the
  opponent's single pass standing and a table row in {[0,0], [−1,−1], [1,1]},
  play the best move instead of passing — all at `passes=1`, all in games
  whose **root** the table did not claim for us, none affecting a finding;
  T381's 5 similar plies were the same mechanism). Fuego passes more often in
  these White games than it did in T381's run (engine RNG — Fuego is
  nondeterministic), which is why the count is larger, not any change in our
  side's play.

## 7. Caveats — what this does and does not claim

- **Fresh-start claims only (C1).** A win in play does not certify the
  fresh-start value as a real-game value (C2 falsified at 3×2, T13). No loss
  from a claimed-won position occurred, so the playability question did not
  even arise.
- **Ko-sensitive rows remain the untrusted region** (foreclosure). The claims
  held in play again; that is a play result, not Track A's regeneration.
- **Sample.** 136 new games + 68 carried, from 34 openings. "0" is "none
  detected in this sample", not a proof. The corpus's forced openings are
  often losing for one colour and do not sample the full state space.
- **Engine RNG.** Move sequences vary run to run (T381: GNU Go 10/68, Pachi
  52/68); each run is a valid sample, and the load-bearing 0/N was stable in
  T381 and again here.
- **These are 19×19 engines.** GNU Go's broken 4×4 scoring is evidence they
  sit outside their competence at this size; the honest finding where higher
  settings do not change play (GNU Go, Fuego) is *reported*, not hidden by
  hunting for a configuration that moves the numbers.
- **Fuego's "no headroom" is 4×4-specific.** Its search saturates on this
  board; nothing here says a bigger board would not use more playouts.

## 8. Reproducibility

- Artifact under test: `data/oracle-4x4-v2.wzo2`, SHA
  `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a`
  (pinned in `artifacts/SHA256SUMS`).
- Instrument source `src/t381_evse.zig` SHA `fa32d563…`, built at git HEAD
  `07d8c54` with `zig build-exe -O ReleaseFast` (zig 0.16.0). Additive only:
  `--strong` flag, `engineForStrong`, stderr capture + Pachi WINNER parsing,
  Fuego `uct_stat_search` parsing, per-game/per-colour strength recording.
  T381's baseline behaviour is unchanged (no flag → same code path as T381).
- Analysis: `docs/evidence/4x4-THIRD-PARTY/analyze-t420.py` merges the raw
  runs, computes the per-colour tables and the T381-vs-T420 comparison, and
  emits the findings file. Re-runnable from the repo root.
- Data: `findings/T420-max-strength.json` (all 204 per-game records — 68
  GNU Go carried + 68 Pachi + 68 Fuego — with per-move playouts, brackets,
  findings, resolutions, colour splits, and the Q1/Q2/Q3 comparison; SHA
  `d7cba8c9…`). Run logs (per-game lines + runner RSS-guard record):
  `docs/evidence/4x4-THIRD-PARTY/raw/run-pachi-strong.log` (SHA
  `fda664c8…`), `run-fuego-strong.log` (SHA `940be35e…`). Analysis:
  `docs/evidence/4x4-THIRD-PARTY/analyze-t420.py` (SHA `09e4dd56…`).
- claimlint: the findings file conforms (task_id/date/model/claims); C7
  unabsorbed stays at 2 (the two pre-existing LOOPY-TAXONOMY rows), all floor
  counters unmoved, calibration PASS.

---

**Landmark line: L0 (the engine does not lose from claimed-won positions) —
advanced.** The table's claimed-won positions were re-tested with the
opponents at their maximum settings — GNU Go already there (level 10,
carried), Pachi cranked from ~11.5k to ~50–106k simulations/move (54.2M
recorded, 0 unreadable), Fuego at an explicit 1M-game cap (its default was
already uncapped; the search saturates on 4×4) — 136 new games, both
colours, same corpus: **losses from claimed-won 0/68 per engine, 0/136 new
games**, ties-from-claimed 0/136, no root-bracket excursions. The earlier
margin was not opponent weakness: wins-from-non-claimed-roots did not fall
(Pachi 5→4, Fuego 23→24). T381's claim survives its strongest available
falsifier; it remains a sample-based measurement, not a proof, and the
ko-sensitive rows remain the untrusted region.
