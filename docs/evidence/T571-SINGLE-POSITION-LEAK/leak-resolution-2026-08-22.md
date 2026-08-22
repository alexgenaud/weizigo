# The 4×4 single-position leak — resolved

**Task:** T571 (leaf) · **Worker:** claude-opus-5/T571 · **Date:** 2026-08-22
**Bundle:** `untracked/T571-4x4-single-position-leak.md`
**Landmark:** advances *the ledger is clean* — a caveat that had sat "unblocked and
unowned" since T472's Track-A ruling (2026-08-20, `92ff481`) is discharged, and
the discharge *cuts against* the framing that produced it: the leak was neither
a table defect nor a fact about 4×4 Go.

---

## 0. The question, and the three-line answer

T412's loop-onset study (`docs/research/loop-onset-2026-08-07.md:215-241`) found
**7 of 232** capped 4×4 games under table-argmax self-play visiting a
single-valued (`L == H`) table entry — **1,203 of 92,800** capped plies (1.30 %)
— and reported it under a caveat: the 4×4 table is "the writes-ON build", so the
leak might be an artifact of the KNOWN-WRONG `ko_ref ≥ d` cross-branch memo guard
(`GLOBAL.F1`, ADR-0013).

1. **The caveat was mis-aimed.** The guard is not in the WZO2 build path at all
   (§2), and the entries the leak consists of are `L == H` entries — by the
   artifact's own definition **outside** the distrusted `L ≠ H` KO_SENSITIVE
   column. The doubt pointed at the one half of the table the foreclosure does
   not touch.
2. **The values are not wrong.** All 45 distinct `L == H` states the 7 games
   visit satisfy their own one-step Bellman identity when re-derived with an
   *independent* successor generator: **0 violations / 45**, with a null control
   (0 / 5,000) and a per-state seeded-defect control (45 / 45 caught) (§3).
3. **The leak is the *player's*, not the table's or the game's.** It is an
   artifact of the replay engine's move selection: value-only argmax with a
   fixed lowest-cell-index tie-break. On the **identical** 500-position sample
   and the **identical** table, adding a distance-to-termination tie-break among
   value-tied children takes capped games visiting `L == H` from **7 / 232 to
   0 / 87**, and `L == H` plies from **1,203 / 92,800 to 0 / 34,800** (§4).
   Replicated at a second, independent sample (seed 997): **3 / 250 → 0 / 84**.

So the brief's two offered verdicts — (a) artifact, (b) real — are both refused,
and for the same reason: **"7 capped games touch `L == H`" is not a property of
the 4×4 table.** It is a property of *one* optimal-play tie-break policy. Under a
tie-break that also minimises distance-to-termination, 4×4 matches 3×3's clean
result: capped games are 100 % confined to the `L < H` bracketed region.

---

## 1. Reproduction — the 7 games, at HEAD

The T412 instrument is unchanged and its replay is deterministic (table-argmax,
no RNG in the optimal arm), so a re-run reproduces bit-for-bit.

```
zig build-exe -O ReleaseFast --dep version -Mroot=src/t412_loop_onset.zig \
  -Mversion=src/version.zig --cache-dir /tmp/weizigo/t571/cache \
  --global-cache-dir /tmp/weizigo/t571/global --name weizigo-t412-loop \
  -femit-bin=/tmp/weizigo/t571/t412-loop
tools/runner --rss-cap-mb 4096 --max-wall 3600 -- /tmp/weizigo/t571/t412-loop \
  --size 4 --sample 500 --seed 42 --json /tmp/weizigo/t571/repro-4x4-opt.json
```

Every aggregate field of the 2026-08-07 evidence file
(`docs/evidence/T412-LOOP-ONSET/loop-onset-4x4-opt.json`) is **identical**, and
all 232 capped-game `(colex, side)` witnesses match, including the 7 with
`pos_sg > 0`. Wall 0.9 s, peak RSS 511 MB.

The 7, as `(colex, side)` with T412's per-game counts:

| # | colex | side | bracket [L,H] | plies | `L==H` plies | first `L==H` ply | distinct states |
|---|---|---|---|---|---|---|---|
| 0 | 301964 | B | [−1, 0] | 400 | **396** | 4 | 14 |
| 1 | 126959 | W | [+1, +16] | 400 | 1 | 2 | 14 |
| 2 | 7928091 | W | [+3, +16] | 400 | **398** | 2 | 12 |
| 3 | 1057330 | B | [+3, +5] | 400 | 3 | 3 | 11 |
| 4 | 7457548 | W | [+2, +4] | 400 | 5 | 2 | 12 |
| 5 | 16160524 | B | [+4, +16] | 400 | 1 | 1 | 11 |
| 6 | 4957429 | W | [−16, 0] | 400 | **399** | 1 | 16 |

**A detail T412's aggregates concealed.** "A small leak" is two different
phenomena. Games 1, 3, 4, 5 graze `L == H` for 1–5 plies of 400. Games 0, 2, 6
spend **396–399 of 400 plies inside `L == H`** — they are not games that leak out
of the bracket, they are games that live in the decisive region and cycle there.
That split is what §4 explains.

---

## 2. The writes-ON contradiction, named and resolved

The bundle flagged a contradiction between two committed assertions:

- `docs/research/loop-onset-2026-08-07.md:234-236` — "The committed 4×4 table is
  the writes-ON build (`data/oracle-4x4.checkpoint.wzo` /
  `data/oracle-4x4-v2.wzo2`)".
- `docs/epistemic/SOLUTION-TREE.md:153` (T380 F-8) — the WZO2 construction has
  **no** finisher; `oracle_v2_build` reads the exp6 fixpoint directly.

**SOLUTION-TREE is right; the loop-onset sentence is wrong.** Three independent
grounds, all from source at HEAD:

1. **Which table the run used.** The evidence file records
   `"wzo2_path": "data/oracle-4x4-v2.wzo2"` — one table, not two. The
   loop-onset sentence names `data/oracle-4x4.checkpoint.wzo` alongside it and
   thereby imports the *checkpoint's* caveat onto an artifact that does not share
   its provenance. The two files are not even the same format (WZO1 vs WZO2) or
   the same ruleset (PSK `rules_id=1` vs basic-ko+TIE `rules_id=2`).
2. **The guard is absent from the build path.** The `ko_ref ≥ d` memo-write
   guard exists at exactly two sites, `src/oracle.zig:253` and
   `src/retro.zig:593`, both gated on `ctx.memo_writes`:
   ```
   if (hashable and ctx.memo_writes and ko_ref >= d) { ... write global memo ... }
   ```
   `grep -c 'ko_ref\|memo_writes' src/exp6_solve.zig src/oracle_v2_build.zig`
   returns **0** for both. The WZO2 producer's import closure is
   `oracle_v2_build.zig → {exp6_solve.zig, artifact2.zig, colex.zig}` and
   `exp6_solve.zig → {artifact.zig, rules.zig, qa023_brute_2x2.zig}` — neither
   `oracle.zig` nor `retro.zig` appears.
3. **The guard is not expressible there.** The bundle's own hypothesis was that
   the guard "can apply during the fixpoint itself, not only in the finisher".
   It cannot: `d` is *search depth along a history path*
   (`d = hist.len − 1`, ADR-0013 §"The bug (exact site)"), and
   `exp6.run_fixpoint_4x4` is a Jacobi/Gauss-Seidel sweep over an explicit,
   history-free state space keyed `(board, side, ko, passes)`
   (`exp6_solve.zig:1099-1143`). There is no search path, no `hist`, no `d`, and
   no cross-branch memo to guard. `exp6_solve.zig` touches disk only to *write*
   its output (`exp6_solve.zig:1712-1741`) — it seeds from no prior artifact.

This is consistent with, and independent of, T472's Track-A ruling already
recorded on `4x4.C1`: "the 3,455,412 L≠H bracket entries of
`data/oracle-4x4-v2.wzo2` are the ADR-0020 pure loopy-game fixpoint bracket …
never the historically unsound finisher (`retro.zig` writes only `.wzo`, never
`.wzo2`)".

**And the caveat was aimed at the wrong half regardless.** In WZO2, the
KO_SENSITIVE property *is* `L ≠ H` (`src/artifact2.zig:489`:
`.ko_sensitive = (entry[1] != entry[2])`), and the counts partition exactly:
3,455,412 KO_SENSITIVE + 95,677,624 KO_SENSITIVE-clear = 99,133,036 entries. The
leak is by construction made of `L == H` entries — every one of them in the
95,677,624-entry clear column on which the G3b I4 Bellman residual is
0 / 95,677,624. **The caveat expressed doubt about the leak by pointing at a
distrust that cannot reach it.**

Conclusion: the caveat was never load-bearing. It should never have been
written in those terms, and the "possibly-artifact" hedge in the study's
synthesis (`:316`, `:330`) is withdrawn — not because the leak is confirmed
real, but because the *artifact* hypothesis it hedged was inapplicable.

---

## 3. The values, re-derived independently — 0 / 45

*Instrument:* `src/t571_leak_probe.zig` (new, additive; reads only). The game
engine and `chooseWzo2` are copied verbatim from `src/t412_loop_onset.zig` so the
replay is the same play, not a second implementation of it.

Phase 1 replays the 7 games and dumps every `L == H` parent at its full Markov
key `(colex, side, ko, passes)`. Phase 2 recomputes each one's one-step Bellman
image using **exp6_solve.zig's own successor generator** — `genChildren4`,
`apply_place4`, base-3 `rank_board4` — instead of `rules.zig` + `colex.zig`,
mirroring `exp6_solve.zig:jacobiWorker`'s inner update exactly (double-pass
children scored by `genericAreaScore`, other children read from the table,
`map.get` misses skipped). This is the duplication-as-oracle move: the move
generator that produced the values checks them through a different code path
than the one that reads them.

```
zig build-exe -O ReleaseFast --dep version -Mroot=src/t571_leak_probe.zig \
  -Mversion=src/version.zig --cache-dir /tmp/weizigo/t571/cache \
  --global-cache-dir /tmp/weizigo/t571/global --name weizigo-t571-leak \
  -femit-bin=/tmp/weizigo/t571/t571-leak
tools/runner --rss-cap-mb 4096 --max-wall 3600 -- /tmp/weizigo/t571/t571-leak \
  --wzo2 data/oracle-4x4-v2.wzo2 --nullctl 5000 --sample 500 --seed 42 \
  --json docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed42.json
```

**Result.** 1,203 `L == H` arrivals (exactly T412's count) over **45 distinct
states**:

| reading | value | denominator |
|---|---|---|
| stored `(L,H)` equals its own one-step Bellman image | **45** | 45 |
| residual violations | **0** | 45 |
| states with no candidate child (check vacuous) | **0** | 45 |
| states carrying a pending ko point | 13 | 45 |
| states at `passes ≥ 1` | 6 | 45 |
| children with no table entry (`map.get` miss) | **0** | 219 children |

**Controls.**

- **N1 null** — the identical residual check over 5,000 `L == H` entries the leak
  never touches, sampled by a seeded strided walk over the group index:
  **0 violations / 5,000**, 0 vacuous. A non-zero count here would have
  convicted the checker, not the leak.
- **S1 seeded defect, per state** — re-run with every child value shifted by +1.
  A uniform child shift must move the parent's image by exactly +1.
  **45 / 45 detected, and 45 / 45 with shift exactly +1.**
  *The first S1 build fired on only 42 / 45.* The three misses were all
  `passes == 1`, White to move, with a double-pass terminal child: the bias was
  applied to table-read children but not to terminal children scored by
  `area_score`, so the minimising image was pinned by an unbiased child. That is
  a defect in the control, not a finding about the table; it is fixed
  (`t571_leak_probe.zig`, `bellmanImage`, the `sc +| bias` line) and recorded
  here because a control's blind spot is exactly the thing worth writing down.

Every one of the 45 states carries a **finite** DTT — the range is 1 … 10, never
`DTT_FAR` (255). Under the WZO2 DTT recurrence
(`oracle_v2_build.zig:165`, `DTT(s) = 1 + min over value-preserving children`)
that means each of these decisive positions has a value-preserving path to
termination in ≤ 10 plies. A game sitting in one of them for 400 plies is
therefore not being held there by the position.

Per-state detail (all 45, with boards, keys, child counts, recomputed values and
both controls) is in
`docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed42.json`,
`leak_states[]`.

---

## 4. The verdict — the leak is a tie-break artifact

`chooseWzo2` picks the child maximising (minimising, for White) the pinned value
`V = max(L, min(0, H))`, and among children *tied* at that value it keeps the
first one it saw — the lowest cell index. That is the whole of its tie-break.
Inside the `L == H` region many moves preserve the (single) value, so a fixed
index tie-break can cycle forever through value-preserving moves in a position
that is decisive and 1–10 plies from termination.

The probe re-runs the identical enumeration and reservoir sample as T412 (same
algorithm, same seed ⇒ the same 500 bracketed fresh-start positions) under three
move rules that differ **only** in how value-ties are broken:

| tie-break | capped | terminated | capped games visiting `L == H` | `L == H` plies | max terminated plies |
|---|---|---|---|---|---|
| **first index** (T412's rule) | 232 / 500 | 268 | **7** | 1,203 / 92,800 (1.30 %) | 40 |
| **min DTT** | 87 / 500 | 413 | **0** | **0 / 34,800 (0.00 %)** | 34 |
| **random** (attribution control) | 89 / 500 | 411 | **0** | 0 / 35,600 | 40 |

Independent second sample, seed 997 (the same instrument, `--seed 997`):

| tie-break | capped | terminated | capped games visiting `L == H` | `L == H` plies |
|---|---|---|---|---|
| first index | 250 / 500 | 250 | **3** | 399 / 100,000 (0.40 %) |
| min DTT | 84 / 500 | 416 | **0** | 0 / 33,600 |
| random | 86 / 500 | 414 | 1 | 1 / 34,400 |

On the 7 pinned games specifically, the DTT tie-break **terminates 5 of 7** in
6, 7, 7, 9 and 6 plies; the 2 that still cap (games 0 and 6 — two of the three
"396–399 plies inside `L == H`" games) then spend **400 / 400 plies inside
`L < H`** and 0 in `L == H`.

**What this establishes, and what it does not.**

- The DTT tie-break cannot lose value: it only chooses among children already
  tied at the best pinned value. That is structural (see `chooseWzo2`'s
  `tie_better` branch), not measured here.
- The **random** control matters. It shows the effect is chiefly the *degeneracy
  of a fixed tie-break*, not something special about the DTT column: a random
  tie-break also collapses the cap rate (232 → 89, 250 → 86) and almost
  eliminates the leak (0, and 1 ply at seed 997). The DTT tie-break eliminates it
  in **both** samples; random does so in one. So the sharpest true statement is
  the negative one: **"capped games visiting `L == H`" is not invariant under
  tie-break policy, therefore it is not a fact about the table.**
- The cap rate itself is not invariant either: **145 of T412's 232 capped games
  at seed 42 (and 166 of 250 at seed 997) terminate once ties are broken by
  DTT.** T412's Q1c reading "capped 46.40 % at 4×4" measures the fixed
  tie-break as much as it measures the table. This does **not** touch T412's Q1
  sibling test (5,080 / 47,456 at 3×3 and 6,073 / 200,000 at 4×4 positions where
  *every* optimal child is `L < H`), which is a table property with no player in
  it, nor its Q1b DTT read.
- **Scope.** 500-position samples of 1,962,142 bracketed fresh-start entries
  (0.025 %), two seeds. "0 capped games visiting `L == H`" means *none detected
  in these two samples under this tie-break*, not a proof over the table. The
  `L == H` count at seed 42 is 7 and at seed 997 is 3 — the "7" was always a
  sample statistic, and the study did not scope it as one.

---

## 5. The writes-OFF artifacts — provenance first, and it does not survive

The bundle asked for a writes-OFF cross-check "or a targeted re-solve … prefer
it", and required provenance before trusting a byte. The provenance step
disqualifies the files, so §3's targeted re-derivation is the cross-check that
stands.

**Hashes (this host, 2026-08-22).** The two `docs/evidence/README.md:165-166`
hashes reproduce exactly — so `SOLUTION-TREE.md:248`'s "neither committed,
hashed, nor audited" is wrong on *hashed*: both have been hashed since T216.

| artifact | sha256 | bytes | `rules_id` |
|---|---|---|---|
| `untracked/oracle-4x4-writesoff-bracket.wzo` | `73b9c27e97eb27e2f197eaaf3ec46f8a50f06caa6025c4ab399b8c5898f92232` | 258,280,358 | 1 (PSK) |
| `untracked/oracle-4x4-writesoff-checkpoint.wzo` | `28afa11bf095554ed313a400a3a5eb871cc49c4bfdefe07e1f2e8f3037f3fc4a` | 258,280,358 | 1 (PSK) |
| `data/oracle-4x4-parallel.checkpoint.wzo` | `28afa11bf095554ed313a400a3a5eb871cc49c4bfdefe07e1f2e8f3037f3fc4a` | 258,280,358 | 1 (PSK) |
| `data/oracle-4x4.checkpoint.wzo` | `a2174fedd6a0591dc66b0b42ef1f52bdc28b97c448dbc5b043d96de3a3b1e118` | 258,280,358 | 1 (PSK) |
| `data/oracle-4x4-basicko-tie-area.wzo` | `edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc` | 258,280,358 | 2 (basic-ko+TIE) |
| `data/oracle-4x4-v2.wzo2` | `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a` | 518,123,097 | WZO2 |

Three findings, in order of severity:

**F1 — `untracked/oracle-4x4-writesoff-checkpoint.wzo` is byte-identical to
`data/oracle-4x4-parallel.checkpoint.wzo`.** Same sha256, same length, same
payload CRC in the header (`0xd37646c1`). This settles the open D16 note in
`CLAIMS.md:1069-1072` ("Whether the checkpoint and the artifact are
byte-identical is nowhere stated") for this pair, and it means the
2026-07-27 Measurement 4 in `docs/research/ko-sensitive-chainability.md:255-300`
— the "writes-**OFF** 1.67 % vs writes-**ON** 4.08 %" table, the source of the
`4x4.M6-FLOOR` "definitional floor" and the 2.4× excess — compared
`data/oracle-4x4.checkpoint.wzo` against **`data/oracle-4x4-parallel.checkpoint.wzo`
under a different name**. Whatever that comparison measures, it is *not* cleanly
"writes-on vs writes-off": the two files differ in at least two ways at once
(serial vs parallel build, and whatever the writes flag was), so the 2.4× is
confounded. The chainability doc already recorded both files' roots as UNDEF
(`:320`) without noticing they were one file. **No claim status is proposed for
the M6 family here: `4x4.M6`, `4x4.M6-FLOOR`, `4x4.M6-EXCESS`, `4x4.WRITESOFF`,
`QA-007` and `QA-008` are all cited in prose but none is a live row in
`CLAIMS.md` (they left the register in the T373 triage).** The confound is
recorded for whoever revives them.

**F2 — both files are PSK (`rules_id = 1`), so neither can cross-check WZO2.**
WZO2 is basic-ko + TIE=0 (ADR-0020). PSK solving was abandoned 2026-07-24 as
intractable and not real Go. A writes-off/writes-on comparison against a PSK
table answers a question about a different game.

**F3 — the bracket-only file is 96 % empty at the states in question.** Of the
45 leak states, 26 are fresh-start (`ko = none, passes = 0`) and therefore
addressable in the WZO1 layout at all. Direct byte reads at
`32 + [0|3^16] + colex` (no tool, no engine):

| artifact | agrees with WZO2's `L` | UNDEF (−128) |
|---|---|---|
| `data/oracle-4x4.checkpoint.wzo` (writes-ON, PSK) | **26 / 26** | 0 / 26 |
| `data/oracle-4x4-parallel.checkpoint.wzo` | 26 / 26 | 0 / 26 |
| `untracked/oracle-4x4-writesoff-checkpoint.wzo` | 26 / 26 | 0 / 26 |
| `untracked/oracle-4x4-writesoff-bracket.wzo` | 1 / 26 | **25 / 26** |
| `data/oracle-4x4-basicko-tie-area.wzo` (T113, `rules_id=2`) | 0 / 26 | 10 / 26 |

The 26 / 26 agreement across three PSK files *and* WZO2 is a positive
corroboration and an expected one: these are `L == H` decisive positions, whose
value does not depend on the repetition rule (the rule-independence result,
T393/T394). It is **not** a writes-off cross-check — the "writes-off" file is one
of the three, and one of the other two is the writes-ON build.

`data/oracle-4x4-basicko-tie-area.wzo` is the one same-ruleset WZO1 file and it
is **disqualified as a comparator, not evidence against WZO2**: T129's own
write-up (`docs/research/newrule-certified-fraction-4x4-2026-07-31.md:1-40`,
same sha256) records **25,000 Bellman VIOLATIONS / 28,000** fresh-start decision
nodes on it and declares `QA-027` FALSE at 4×4. Its `vb` column is also 94.2 %
`±16`-or-UNDEF at stride 401 (n = 107,349), which is inconsistent with a
median-pinned `V` column (a `[−16,+16]` bracket pins to 0, not ±16), so the
column's semantics are not established either. Its root does match WZO2
(`vb[0] = +1`). **Open question, not a finding:** what the T113 export's value
column actually holds. It is not on T571's path — the leak states were
re-derived directly in §3.

---

## 6. What changes in the record

| file | change |
|---|---|
| `docs/research/loop-onset-2026-08-07.md` | the "Caveat on the 4×4 leak" (§Q1c) replaced with the resolution; the synthesis bullet and the provenance sentence corrected |
| `docs/epistemic/SOLUTION-TREE.md` | §(b) item 7 corrected on "hashed", and the F1/F2 provenance findings recorded |
| `findings/T571-single-position-leak.json` | one new row proposed (`4x4.LEAK-TIEBREAK`, MEASUREMENT) plus the artifact-identity row (`4x4.WRITESOFF-DUP`, MEASUREMENT) |

No existing claim's status is changed. `GLOBAL.F1` stays FALSE-AS-SCOPED — this
row does not touch its truth, only the question of where it reaches.

---

## Provenance

| artifact | path |
|---|---|
| probe instrument (new, additive, read-only) | `src/t571_leak_probe.zig` |
| replay instrument (unchanged, T412) | `src/t412_loop_onset.zig` |
| probe evidence, seed 42 | `docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed42.json` |
| probe evidence, seed 997 | `docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed997.json` |
| T412 baseline (reproduced verbatim) | `docs/evidence/T412-LOOP-ONSET/loop-onset-4x4-opt.json` |
| commands + hashes | `docs/evidence/T571-SINGLE-POSITION-LEAK/PROVENANCE.md` |

All runs under `tools/runner` (RSS / wall / CPU guards), `-O ReleaseFast`; peak
RSS 511 MB, wall 0.9 s per run. Table read-only: `data/oracle-4x4-v2.wzo2`.
Scores are Black-positive throughout; the side-to-move picks the array, never the
sign. No file under `src/` or `data/` was modified; `src/t571_leak_probe.zig` is
new and `build.zig` is untouched.

**Inbox.** `bin/managent inbox T571 --ack` at claim, mid-work and before
reporting: empty each time; no directive acted on.
