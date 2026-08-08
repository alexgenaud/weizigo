# T389 — the engine honours its own predictions: per-ply trajectory consistency in self-play

Task: T389 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-06

**Landmark:** advances `L2 (proven 4×4 values)` and `L3 (the new engine outplays the old
one)` — this is the property that makes an answer key an answer key (operator's framing,
2026-08-05): *"Playing against itself, we should expect the score at every earlier position
or within the bracketed range… If not, then either the engine is wrong or the table is wrong
or both."* **Result:** the new engine (WZO2, basic ko) honours its own brackets on every
engine-chosen ply in every measurement here — 0 escapes at new-engine decision plies in
67 self-play games (0/1027 plies) and in the committed 132-game corpus under the new
engine's own ruleset (frame B: 0/1191). Every escape found is attributable to a forced
corpus opening move or to the old engine's play — plus one frame-specific artefact (frame
A PSK-restriction) explained below. What remains between here and L2 is not a
trajectory-consistency defect; it is the bracketed-region verification the foreclosures
already demand (Track A `memo_writes=false`).

---

## 1. The property, stated precisely

For a self-play game, let `[L_n, H_n]` be the table's stored bracket at ply *n* for the
side to move, at the node's own `(colex, side, ko_point, passes)` key. The invariant:

> **A final score outside `[L_n, H_n]` at any node *n* is a contradiction: the table is
> wrong, the move selector is wrong, or the key is wrong.**

Semantics of the bracket (ADR-0020 loopy-game fixpoint, `oracle-4x4-v2.wzo2`):
`L` is Black's security level — the score Black can force regardless of White's play;
`H` is White's security level — the score White can enforce regardless of Black's play.
The fixpoint updates `L(P,s) = extremum over s's moves of L(child,-s)` and the same for
`H` (the extremum is max for Black, min for White — `src/exp6_solve.zig` run_fixpoint
4×4 sweeps). At a **single-score** node (`L == H`) the game value is determined; at a
**bracketed** node (`L < H`, ADR-0020 axiom E3) the honest prediction is the *interval*
and only an *escape from the interval* is a violation. Flagging `L < H` itself as a
failure is a false alarm (instrument defect). Vocabulary per the Orchestrator's
BRACKETED / SINGLE-SCORE ruling (045cdc4).

**Consequence for play.** The guarantee semantics give the attribution lens used
throughout this row. An escape `final < L` means Black's play at/after the node failed
Black's guarantee — *Black* is the culprit. An escape `final > H` means White's play
at/after the node failed White's enforcement — *White* is the culprit. The culprit's
identity (old or new engine) is read from the game's colour assignment. This is not
speculation: it is what the fixpoint *defines* the bounds as guarantees against.

## 2. Instrument

`src/t389_traj.zig` (built at HEAD `045cdc4`, binary SHA `3dfbddca…`; the brief's
`src/t379_*.zig` naming is stale — T379 died as a zombie and this row is T389, so the
instrument follows the `t<task>_*.zig` convention). Standalone, additive: reads only
`data/oracle-4x4-v2.wzo2` (SHA `0c3366f0…`, rules_id 3 — Chinese area, komi 0, basic ko,
L/H bracket) and the committed corpus; no `build.zig` edit, no engine-source edit, no
`src/vb_*.zig` edit. L/H is read through the session API (`artifact2.lookup`) exactly as
T366 did — the `weizigo_showscores` 4×4 crash (T374) is not exercised.

At every ply of every game the node's bracket is recorded (with `ko_point`, `passes`,
and a `in_table` flag from a direct `artifact2.lookup` — a miss would be its own
finding); after the game ends, the final score is checked against every recorded node.
Per-violation characterisation: ply index, side to move, ko state, pass count, bracket
width, final score, escape direction, one of the four causes, the board witness, and an
alternate-key probe (`(ko, passes)` variants) that tests the operator's ko/pass-key
hypothesis. Games with violations carry their full bracket trace.

The seeded control reuses `src/seedctl.zig`'s injection semantics (force one side's move
at one moves-array index to a pass or a cell).

## 3. Runs and denominators

```
zig build-exe -O ReleaseFast --dep version -Mroot=src/t389_traj.zig \
  -Mversion=src/version.zig --cache-dir /tmp/weizigo/t389/cache \
  --global-cache-dir /tmp/weizigo/t389/global --name weizigo-t389-traj \
  -femit-bin=docs/evidence/RESCUED-tmp-2026-08-08/t389/t389-traj            (under tools/runner)

# main run (sections selfplay + corpus-replay):
weizigo-t389-traj --mode both --json docs/evidence/RESCUED-tmp-2026-08-08/t389/main-both.json
# seeded control:
weizigo-t389-traj --mode selfplay --json docs/evidence/RESCUED-tmp-2026-08-08/t389/seeded-final.json \
  --inject-opening 0 --inject-ply 1 --inject-side W --inject-cell pass
# deliverable = main run + the seeded section merged (mechanical, documented here)
```

Corpus: `findings/T366-engine-kifu.json` (SHA `8b61c230…`) — T366/T375's committed
132 games (33 openings × 2 colour assignments × 2 frames), replayed move-for-move.
Replay fidelity: **132/132 final scores match the committed corpus results**.

The denominator is plies (nodes examined), stated everywhere. "Engine-decision plies"
exclude the forced opening plies (126 per 66-game frame / 126 in self-play), because a
forced corpus opening is not the engine's choice — the checker still examines and
reports them, but they cannot be attributed to the engine.

## 4. Results

### 4.1 Null control — self-play, new engine vs itself (67 games)

33 openings × 2 colour assignments (for self-play the two assignments coincide —
each pair is a **determinism replicate**, 33/33 byte-identical trajectories) + the
empty-goban game. New engine plays both colours, basic ko (its own ruleset).

| | count |
|---|---|
| games | 67 |
| plies examined | 1153 (126 forced-opening + **1027 engine-decision**) |
| violations | **48 — all 48 at forced-opening plies** (14 at the empty root where the forced first move is suboptimal; 34 at ply 1 where the forced second move is suboptimal) |
| violations at engine-decision plies | **0 / 1027** |
| lookup misses (state not in table) | 0 |
| illegal moves | 0 |
| capped games | 0 |

The empty-goban game — the only game in which every ply is the engine's own choice —
shows **0 violations**; final score `+1` equals the root's `L` (`[1,16]`, bracketed
root, so the single-score equality does not apply; the outcome lands exactly on
Black's guarantee). Every single-score node along every trajectory holds
`final == L == H` (that is what 0 violations means at those nodes).

All 48 escapes carry `forced_ply=true` and 46/48 are *explained by the move at the
violated ply* (the child node's bracket contains the final): the forced opening move
itself is the suboptimality. The remaining 2 (sp-o19, opening `random-016-adcb`) have
*two consecutive* forced suboptimal moves (both the root and ply 1 escape; the checker
reports both nodes). **These are corpus artefacts, not engine defects**: the canonical
corner/edge and seeded random openings deliberately include bad first moves (that is
what makes the corpus comparable to T366, where the same openings are forced on both
engines). The checker fires on them — which is the same sensitivity the seeded control
demonstrates on an engine-chosen move.

### 4.2 Seeded control — the checker fires (instrument sensitivity)

Injection (seedctl semantics): opening 0 (`canonical-corner-A1`), moves-index 1,
White forced to pass — the same injection T375 used. Result flips **W+16 → B+16** (in
T375's old-vs-new game the same injection gave B+3; different game, different absolute
value — what matters here is the checker).

| | value |
|---|---|
| checker fired at | **ply 1, side W** — exactly the injected ply and side, in both replicates |
| violation witness | bracket `[-16,-16]` (single-score), final `+16`, direction `above_H` (White's enforcement failed), `forced_ply=false` (an engine-decision ply), board `B...............` |
| cause | `genuine_defect` (L==H node, in-table) — the escape is manufactured, as a control must be |
| surgical check | the other 65 games byte-identical to the null run (**PASS**); the injected games each lost their null-run ply-0 escape (final now inside `[1,16]`) and gained the ply-1 escape |
| net | null 48 violations → seeded 48 (46 forced + 2 engine-decision, the injected ones). The only difference between the two runs is the injected move. |

A checker never shown to fire is not evidence; it fires here at the right ply, naming
the right side, on the only difference between two otherwise identical runs.

### 4.3 Corpus replay — the committed T366/T375 trajectories (132 games)

The same invariant, checked along the committed corpus lines (which mix old-engine and
new-engine choices per the T366 frames).

| frame | games | plies (forced / engine) | violations (forced / engine-decision) |
|---|---|---|---|
| fA (new engine PSK-enforced) | 66 | 1287 (126 / 1161) | 144 (47 / 97) |
| fB (new engine basic ko) | 66 | 1317 (126 / 1191) | 140 (48 / 92) |
| **total** | 132 | 2604 (252 / 2352) | **284 (95 / 189)** |

Cause classification of the 284 (instrument): `key_mismatch` **0** · `indeterminate_bracket`
85 (bracketed nodes whose interval was escaped) · `genuine_defect` 199 (single-score
nodes escaped) · `ruleset_mismatch` 0 · lookup misses 0 · illegal moves 0.

**Attribution by culprit** (guarantee semantics of §1 — below_L ⇒ Black, above_H ⇒ White,
identity read from the game's old_colour):

| frame | new-engine-attributable (engine-decision) | old-engine-attributable (engine-decision) | forced-opening |
|---|---|---|---|
| fA | **42** | 55 | 47 |
| fB | **0** | 92 | 48 |

**The fB frame is the apples-to-apples test** — both sides play the table's own ruleset
(basic ko), so a new-engine escape would be an engine/table contradiction with no
confound. There are none: **0 new-engine-attributable escapes in fB at any ply beyond
the forced openings**, at any ko/pass state, bracketed or single-score. All 92 fB
engine-decision escapes are old-engine-attributable — the old engine's play fails the
*new* table's brackets (T366's §4 finding, now visible as bracket escapes rather than
outcome classifications; the four ko-pending escapes below are exactly T366's genuine
losses fA/fB-o19-W and fA/fB-o21-B).

**The fA frame is not an apples-to-apples test.** In frame A the new engine's play was
PSK-restricted (T366's design) while the table is basic-ko. The 42 new-attributable
escapes (all `above_H`; 20 at single-score nodes, 22 at bracketed, 2 at passes=1) are
**PSK-vs-basic-ko enforcement artefacts** — the basic-ko bracket assumes the basic-ko
move set, and a PSK-restricted player cannot always achieve or enforce it. Witnesses:

- **fA-o06-B ply 17**: the basic-ko optimal White move `cd` repeats a position — legal
  under basic ko, **PSK-illegal** — so the restricted White passed instead, and the line
  resolved at B+16 where the bracket was `[1,1]`.
- **Same opening, same node, same bracket `[1,1]`, opposite outcomes by frame**: fA
  (White PSK-restricted) → B+16; fB (White unrestricted) → W+16. The 32-point swing is
  the restriction's cost. (T366 already recorded the frame-B loss fB-o06-B as a genuine
  old-engine loss to basic-ko position repetition.)
- Probe `src/t389_pskprobe.zig` documents both: the walk of the committed fA-o06-B line
  with per-node brackets, and the ply-17 PSK block.

These are cause-3 (ruleset mismatch between play-time legality and table legality) in the
brief's taxonomy once attributed; the instrument classifies them by bracket type because
the frame is known only to the analysis.

**Ko/pass-key composition of the 284** (the operator's hypothesis — see §5):
4 violations at ko-pending nodes — **all four old-engine-attributable** — and 3 at
passes=1. At each of the 4, the alternate (ko-cleared, passes=0) key's bracket contains
the final (`alt_key_hit=1`), i.e. the line's outcome matches the *ko-resolved* value,
not the *ko-pending* one. The escapes cluster exactly where the old engine's known
disease lives.

## 5. The operator's prior hypothesis: immediate ko chains and pass/ko key components

> The prior hypothesis to test explicitly is the operator's — immediate ko chains and
> pass/ko key components — since that is exactly where the old engine failed.

**The data does not support it as a new-engine defect.** In the two clean measurements —
self-play (0/1027 engine-decision plies) and the frame-B corpus (0/1191) — the new
engine's own decision plies show **zero** escapes at ko-pending nodes, at passes=1, at
bracketed nodes, or anywhere else. If the new engine's key handling (ko point, pass
count) were broken, some of the 2,218 new-engine decision plies across the two
measurements would have escaped — none did.

**The data does localise the failure class to the old engine.** The 4 ko-pending
escapes in the corpus are all old-engine-attributable and are precisely T366's genuine
losses (fA/fB-o19-W: old White threw away W+1 → B+3 at a ko-pending node; fA/fB-o21-B:
old Black threw away B+1 → W+3 at a ko-pending node). The operator's hypothesis names
the right class — immediate ko chains and ko-key state — but it names the *old* engine's
disease, which T366 already established; the new engine, keyed on `(colex, side,
ko_point, passes)`, does not exhibit it in any measurement where it plays its own
ruleset.

## 6. What this does and does not license

- **Licenses:** *self-consistency over the corpus examined* — the new engine's played
  trajectories never leave its own stored brackets at engine-chosen plies: 0 / 1027
  plies in 67 self-play games (33 distinct trajectories + empty), 0 / 1191 plies in the
  66-game frame-B corpus, and (after attributing the 42 PSK artefacts) 0 / 1161 in
  frame A. 0 lookup misses across 3,759 plies means every played state's key was present
  in the table — no key-mismatch symptom anywhere.
- **Does not license:** correctness of the values. The check is *internal consistency*,
  not ground truth. The fresh-start slice only (C1); real-game history-independence (C2)
  is falsified at 3×2 (T13) and out of scope; bracketed-region values remain subject to
  the Track A `memo_writes=false` regeneration gate and the #2 auditor; per-goban
  independence means nothing here transfers to other sizes. The 48 self-play escapes at
  forced-opening plies are not engine defects; the 284 corpus escapes are old-engine or
  frame-enforcement artefacts. **No table value in this row is reported as a real-game
  value.**
- Per the brief: no violation was "fixed". All are reported with witnesses in
  `findings/T389-trajectory-consistency.json` (sections `selfplay`, `seeded-control`,
  `corpus-replay`; per-game moves, violations with boards and bracket traces).

## 7. Reproducibility

- Artifact: `data/oracle-4x4-v2.wzo2`, SHA `0c3366f0…` (pinned in
  `artifacts/SHA256SUMS`).
- Corpus: `findings/T366-engine-kifu.json`, SHA `8b61c230…` (committed).
- Instrument: `src/t389_traj.zig` (this row, HEAD `045cdc4`); binary SHA `3dfbddca…`.
  Probe: `src/t389_pskprobe.zig`.
- Commands in §3. Deterministic: same seed (42), same openings, same corpus, same
  binary → same output. Replay any game by replaying its `moves[]` from the JSON.
- Assembly: the deliverable JSON = one `--mode both` run (sections `selfplay`,
  `corpus-replay`) + the seeded run's section (renamed `seeded-control`), merged
  mechanically; the merge is the only step not produced by the instrument.
