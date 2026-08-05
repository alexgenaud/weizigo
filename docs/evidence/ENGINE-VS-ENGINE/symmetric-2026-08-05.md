# T375 — the missing half of M3: did the NEW engine ever throw away a winnable position?

Task: T375 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-05
Identifier: `deepseek-v4-flash/T375` (abbr. `flash/T375`)

Milestone: **M3 (the new engine outplays the old one)** — advanced from *"the
old engine demonstrably throws games away"* to *"and the new engine was
measured for the same fault."*

---

## The answer, in one sentence

**Strictly stronger: yes, on the measured sample — because the new engine
threw away 0 of its 56 losses (0 of 30 in frame A, 0 of 26 in frame B,
mirror-classified with the old engine as arbiter), its own table never
claimed a winnable position at any of those 56 loss divergence nodes (L/H
check: 0 self-contradictions, all nodes in the fresh-start slice), and the
old engine threw away 3 (fA) and 7 (fB) of its 36/40 losses on the same 33
openings; "0" is "none detected in 66 games per frame", not a proof, and the
raw scoreline (old engine won 30/66 fA, 26/66 fB) is opening-driven and is
not evidence either way.**

---

## 1. Why this row exists — and what T366 could not answer

T366's classification is **one-sided by construction**: every label is about
the old engine (`genuine_loss` — the old engine lost a game its colour could
have won; `loss_not_attributable` — lost anyway; `equal_value` — did not
lose). Its arbiter substitutes the **new** engine's moves at the **old**
engine's decision points, never the reverse. So the raw scoreline — the old
engine won 30 of 66 games in frame A and 26 of 66 in frame B, meaning the
**new** engine lost those games — was labelled `equal_value`, which asserts
only that the old engine did not throw anything away. Whether the **new**
engine did was never tested. T375 runs the mirror.

**Overlap disclosure:** while T375 was being registered, the mirror machinery
was added to the instrument and committed as **19cd78b** (15:26:52) under the
T366 task (doc section 5.1), publishing the same mirror figures before this
row's own run. This row independently re-runs the committed instrument
(reproducing those figures exactly — the verify-then-promote second seat),
adds the L/H bracket check that neither T366's 5.1 nor 19cd78b made, and
runs the two controls neither documented. T366's 5.1 and this row agree.

## 2. Method — the mirror of T366, same instrument, same denominators

**Instrument:** the committed `src/t366_evse.zig` (SHA
`4e378353…`, commit 19cd78b), which already carries the mirror machinery
(`mirrorSubstitution` / `mirrorArbiter` / `classifyMirror`, per-frame
`mirror_summary`, per-game `mirror{}`). Compiled ad hoc with `zig build-exe`
in a detached worktree at the committed HEAD (the main tree's engine sources
were mid-edit by the in-progress T363 sprint; the worktree changed nothing).
**No `build.zig` edit, no engine-source edit, no `src/vb_*.zig` edit.**

**Run:** same openings (3 canonical one-ply + 30 seeded random two-ply,
deduplicated = 33 distinct), same seed (42), same two frames, same
denominator (66 games per frame = 33 openings × 2 colour assignments), same
artifacts (old `oracle-4x4.checkpoint.wzo` `a2174fed…`; new
`oracle-4x4-v2.wzo2` `0c3366f0…`). Wall time 0.6 s, 746 MB peak RSS
(`tools/runner` guard).

```
zig build-exe -O ReleaseFast --dep version -Mroot=src/t366_evse.zig \
  -Mversion=src/version.zig --cache-dir /tmp/weizigo/t375/cache \
  --global-cache-dir /tmp/weizigo/t375/global --name weizigo-t375-evse \
  -femit-bin=/tmp/weizigo/t375/t375-evse
weizigo-t375-evse --frame both --openings 30 --seed 42 \
  --old data/oracle-4x4.checkpoint.wzo --new data/oracle-4x4-v2.wzo2 \
  --out /tmp/weizigo/t375/sgf --json /tmp/weizigo/t375/raw.json
```

**Mirror semantics** (roles swapped from T366): at each of the **new**
engine's decision points (its colour's turns beyond the forced opening) the
**old** engine's move is substituted and the game replayed; at the old
engine's turns the original moves are replayed. If the old engine wins with
the new engine's colour from the same opening, the new engine threw away a
winnable position. Classification by outcome with T366's four labels,
inverted:

- `new_genuine_loss` — new engine lost (or drew) a game its colour could
  have won (or drawn): the old engine's substitution replay wins with its
  colour, or — when that replay diverges — the old-engine self-play arbiter
  wins/draws with its colour.
- `new_loss_not_attributable` — new engine lost, but even the old engine's
  moves with its colour from the same opening lose: the position was lost
  anyway.
- `new_equal_value` — new engine did not lose.
- `outcome_unknown` — substitution replay diverged and the arbiter cycled to
  the ply cap.

## 3. Results — the mirror, 66 per frame

| frame | enforcement (old / new) | new W-L-D | new genuine loss | new loss not attributable | new equal value | outcome unknown |
|---|---|---|---|---|---|---|
| fA | psk / psk (shared PSK) | 36–30–0 | **0** | 30 | 36 | 0 |
| fB | psk / basic-ko (new ruleset) | 40–26–0 | **0** | 26 | 40 | 0 |

Read: **the new engine threw away nothing in either frame.** All 30 (fA) / 26
(fB) new-engine losses are openings lost for its colour regardless of who
plays them — the old engine, substituted into the new engine's colour,
cannot win them either. This is the exact mirror of T366's finding: the old
engine threw away 3 of 36 (fA) / 7 of 40 (fB); the new engine threw away 0
of 30 / 0 of 26. The two halves are now measured, one-sided in the new
engine's favour, on the same 33 openings.

## 4. The check the mirror cannot make — the new table's own L/H bracket

The old engine is a **weak arbiter** for the new one — it is the untrusted
build. So each new-engine loss was also tested against **the new table's own
stored L/H bracket at the first-divergence node** (the node both engines
evaluated, read with the node's own `(ko, passes)` state): if the bracket
claims the position was won for the new engine's colour and the game was then
lost, that is a self-contradiction of exactly the kind T366 found in the old
table (`fA-o32-W`: a value its own play could not reach). Bracket values are
Black-positive — the side to move picks the lookup row, never the sign — so
"won for the new colour" is `new==B and L>0`, or `new==W and H<0`.

**Result: 0 self-contradictions in 56 new-engine losses (0 of 30 fA, 0 of
26 fB).** All 56 divergence nodes are in the fresh-start slice (ko = none,
passes = 0; 4 rows ko-sensitive, reported as data with their state); 0 nodes
ko-pending, 0 with passes > 0. At every one of them the new table's own
bracket already showed the position **lost** for the new engine's colour.

Two independent lines of evidence now agree the new engine threw away nothing
on this sample: the old-engine arbiter (mirror, 0/56) **and** the new
table's own bracket (L/H check, 0/56). A self-contradiction in the *new*
table would have been a serious M2 finding — none was found; report-don't-
adapt has nothing to stop for, and no witness state is recorded.

## 5. Controls

**Null control — PASS.** The instrument computes T366's own direction and
the mirror in the same run, so the null control is built in: re-running
T366's direction at seed 42 reproduces its published figures exactly — fA 3
genuine losses / 66, fB 7 / 66, and the same 10 genuine-loss game records
(fA-o19-W, fA-o21-B, fA-o32-W, fB-o02-B, fB-o04-B, fB-o06-B, fB-o17-B,
fB-o19-W, fB-o21-B, fB-o32-W). Game-by-game comparison against the committed
`findings/T366-engine-kifu.json` (19cd78b): **6072 scalar fields across all
132 games, 0 mismatches** (the only differing field is the sgf output path,
by out-dir). Finding: T366's doc prose says "62 of 66 first divergences
in-scope"; its own committed kifu JSON and this run both say 66/66 — the 62
is a stale T366 doc number, flagged, not reproduced.

**Seeded control — PASS.** A deliberately bad move (a pass) was injected for
the new engine at one decision point — fA-o00-B, moves-index 1, the new
engine's first White move — via an additive copy of the instrument
(`src/seedctl.zig` in the T375 worktree; one optional injection parameter,
all measurement code untouched). The game flips **W+16 → B+3** and the
mirror classifier catches it: `mirror_classification` flips
`equal_value → genuine_loss` (via the mirror-arbiter fallback — the old
engine's self-play wins W+16 with the new colour; the substitution replay
diverges on the injected line, the documented fallback path). The injection
is surgical: 65 of 66 frame-A games byte-identical, the colour-swapped twin
fA-o00-W byte-identical. The harness itself, run without injection, is
byte-identical to the main instrument (132 games, 0 mismatches).

## 6. SGF kifus

None committed. The brief commits an SGF kifu for every new-engine genuine
loss **if any**; there are none (0 fA, 0 fB), and the L/H check recorded no
self-contradiction witness. Full kifu data for all 132 games — moves,
divergence nodes, both engines' values, mirror substitution replays and
arbiters — is in `findings/T375-symmetric-arbiter.json`.

## 7. Scope, honestly stated

- **Not a real-game claim.** Everything here is the fresh-start slice (C1);
  real-game history-independence (C2) is falsified at 3×2 (T13) and out of
  scope. The L/H bracket is a fresh-start claim; the 0-self-contradiction
  verdict is a fresh-start-claim-vs-own-play check, the same logic T366
  applied to the old table.
- **Frame B is the old engine's PSK world.** The frame-B mirror tests the
  old engine in the only world it has (PSK); it cannot answer basic-ko
  position repetition, so it bounds rather than equals the basic-ko question
  for the new engine — T366's own caveat, inherited.
- **"0" is "none detected in 66 games per frame at these openings", not a
  proof.** The 33 openings are the same for both engines (colour-swapped),
  which is what makes the comparison fair — and small.
- **The mirror's substitution replay usually diverges; the self-play arbiter
  is the main decider.** The substitution replay diverges when the
  substituted engine's fresh line stops fitting the original move sequence —
  a replay-semantics property, symmetric in both directions: it decided 9 of
  the 56 mirror classifications and only 6 of the 76 old-direction non-wins
  in T366's own measurement (where the arbiter decided 70). The self-play
  arbiter decided the remaining 47 mirror classifications; `outcome_unknown`
  = 0 in both frames because the arbiter always completes.

## 8. Reproducibility

- Instrument source `src/t366_evse.zig` `4e378353…` (committed 19cd78b);
  instrument binary `/tmp/weizigo/t375/t375-evse` `d335a4ab…`; seedctl
  harness `src/seedctl.zig` `bbea5c37…` (committed with this row), binary
  `e3141a4c…`; all built at git HEAD 19cd78b (version stamp
  `weizigo-t366-evse 19cd78b built 2026-08-05T13:29:40Z zig 0.16.0`).
- Artifacts (pinned in `artifacts/SHA256SUMS`): old `a2174fed…`; new
  `0c3366f0…`.
- Games are deterministic: same seed, same openings, same moves. Any game can
  be replayed from its `moves[]` in the arbiter JSON with either engine.
- Files: `findings/T375-symmetric-arbiter.json` (relabelled instrument
  output: header T375, mirror summaries, L/H check with all 56 witness
  states, controls; game data passed through unchanged),
  `findings/T375-context.json` (this method, controls, overlap record), and
  this document. No SGFs (see §6).

---

**Milestone line: M3 (the new engine outplays the old one) — both halves now
measured: the old engine throws away 3 (fA) / 7 (fB) of its losses on these
openings; the new engine throws away 0 (fA) / 0 (fB), and its own table
never contradicts itself at any loss divergence node; strictly stronger on
this sample, not a proof.**
