# ORACLE-V2 CONSUMER-LOAD TEST — T178

```
Status:   evidence of a test run (no claim rows promoted)
Task:     T178 — oracle-v2 consumer-load test
Worker:   DSFlash/T178 · Date: 2026-07-31 (UTC run 23:50–00:05)
Instrument: src/oracle_v2_consumer_load.zig (new, T178)
Subject:  the WZO2 artifact (format contract: docs/epic-01-markovian/sprints/oracle-v2/pass0/design-M1.md)
```

Sprint.md acceptance item 3 — "Consumer-load smoke test (non-negotiable — 058
F1–F4)": *an artifact task is not done until the consumer has loaded the
artifact.* The check exists because format-level checks passed on v1 while the
engine refused/ misread it (channel 058). This run is that check for WZO2.

## 0. What the brief asked

Load the WZO2 artifact, query the empty 4×4 goban on both sides under
basic-ko + TIE=0, verify against the committed anchor; "must complete in
seconds". Brief: `untracked/T178-consumer-load.md`.

## 1. Blocker: the 4×4 WZO2 artifact does not exist

`untracked/oracle-v2/` was never created; no `*.wzo2` exists anywhere on the
host (find across `/Users/alex` and `/`; git history; heartbeat). T165 (M2b)
delivered the **builder code** (`src/artifact2.zig`, `src/oracle_v2_build.zig`),
not the artifact. Producing the 4×4 artifact is the EXP-6 fixpoint (~3,158 s
wall, 3.1 GB RSS — `docs/evidence/QA-026/4x4/PROVENANCE.md`) plus DTT and
serialisation (R9 budget ≤ 4 h) — **not a seconds task**. The 4×4-specific
query is therefore BLOCKED on the absent artifact; the committed 4×4 anchor
it would verify is `root = +1`, bracket `[+1,+16]` B / `[-16,-1]` W
(`4x4.BASICKO-TIE`, CLAIMS.md:443; EXP-6 provenance).

The consumer path itself is exercised end-to-end at 3×3 (the largest goban
whose fixpoint completes in seconds), against the committed 3×3 anchors.

## 2. What passed (3×3, seconds budget)

Run: `tools/runner -- zig run -O ReleaseFast src/oracle_v2_consumer_load.zig`
(wall 5.3 s incl. compile; runtime 1.1 s — within the "seconds" budget).

Fixpoint and census independently reproduce the committed `3x3.BASICKO-TIE`
row (CLAIMS.md:442): reachable = **73,758** (committed 73,758), fixpoint
**16 sweeps** converged (committed 16), root L==H==9 B / −9 W.

Artifact built to `untracked/oracle-v2/oracle-3x3-v2.wzo2`: 12,675 groups,
49,428 entries, 261,215 bytes. SHA-256 `91e215a3b9dc8018a705486097121162be74314a5c3189dcead601bff4e5f6cd`.
DTT: 8 relaxation sweeps, 0 FAR, 49,428 non-FAR distinct values, max 11
(non-constant, consistent — the committed v1 artifacts had a constant 255).

Consumer load via `artifact2.load` (the exact M3 engine path): PASS.
Empty-goban queries (stdout data lines):

```
CONSUMER-LOAD 3x3 empty-B passes=0 L=9 H=9 V=9 anchor=9 PASS
CONSUMER-LOAD 3x3 empty-W passes=0 L=-9 H=-9 V=-9 anchor=-9 PASS
CONSUMER-LOAD 3x3 empty-B/W passes=1 (coverage) B L=9 H=9 W L=-9 H=-9 PASS
VERDICT PASS failures=0 elapsed_ms=1106
```

TIE=0 pin applied reader-side: `V = max(L, min(0, H))` (spec F5).

## 3. CRITICAL finding: WZO2 group keys use the wrong colex convention

The real consumer (the GTP engine, `weizigo-oracle`, built from `src/gtp.zig`
at 2026-07-31 01:54) loads the artifact and answers, but **reads the wrong
state for every non-empty position** — the 058-class defect this test exists
to catch.

### 3.1 Mechanism (measured, 3×3)

| instrument | key convention for goban address |
|---|---|
| format contract design-M1 §2.1 | "the same colex as the v1 artifact and the engine's internal addressing" |
| v1 writers: `oracle.zig:210`, `retro.zig:275,453,549,643,773` | combinatorial colex (`src/colex.zig`, layer-offset + combinatorial subset + colour bits) |
| M3 consumer: `gtp.zig` (`colex.Indexer`) | combinatorial colex |
| M4a harness: `oracle_v2_accept.zig` `flipColex` | combinatorial colex |
| **M2b builder: `oracle_v2_build.zig`** (`gh.colex = board` from exp6's compact walk) | **exp6's base-3 rank (`exp6_solve.zig` `rank_board`)** |

The two bijections over the same 3^n space agree **only at index 0** (the
empty goban). Example: the position B@A3 (one black stone at cell 0 of a 3×3)
is key 729 in exp6's base-3 encoding and key **2** in the engine's colex.
The engine's lookup therefore lands on a different board's entry (silent
substitution) or on nothing (area-score fallback).

### 3.2 End-to-end falsification (the trace)

GTP run: `printf 'boardsize 3\nclear_board\ngenmove b\ngenmove w\nquit\n' |
weizigo-oracle untracked/oracle-v2/oracle-3x3-v2.wzo2`:

```
oracle: b -> A3  child-value=9 stored-v0=9 [L=9,H=9] dtt=0
oracle: w -> A1  child-value=-4 stored-v0=9 (HISTORY-DIVERGED) [L=0,H=0] dtt=4
```

Instrumented rebuild of `gtp.zig` (copy at `untracked/dbg/`, deleted after;
repo file untouched) — every child of the empty board evaluated by chooseV2,
vs the fixpoint's true value of that position (read from the artifact under
exp6 keys, cross-checked against the fixpoint tables):

| B plays | position (W to move) | engine colex | engine reads | TRUE (fixpoint) | verdict |
|---|---|---|---|---|---|
| A3 (cell 0) | B@0 | 2 | fallback (9,9) | **(-9,-9)** | WRONG |
| B3 (cell 1) | B@1 | 4 | (3,9) | (3,9) | coincides |
| C3 (cell 2) | B@2 | 6 | fallback (9,9) | **(-9,-9)** | WRONG |
| A2 (cell 3) | B@3 | 8 | fallback (9,9) | (3,9) | WRONG |
| B2 (cell 4) | B@4 | 10 | (-9,-9) | **(9,9)** | WRONG |
| C2 (cell 5) | B@5 | 12 | (3,9) | (3,9) | coincides |
| A1 (cell 6) | B@6 | 14 | (-1,9) | **(-9,-9)** | WRONG |
| B1 (cell 7) | B@7 | 16 | (-9,-9) | (3,9) | WRONG |
| C1 (cell 8) | B@8 | 18 | fallback (9,9) | **(-9,-9)** | WRONG |

**7 of 9 one-stone children are misread** — 4 miss (fallback to rules.zig area
score, which for a lone stone counts the whole board, hence the bogus 9) and 3
silently substitute another board's value. The engine's chosen opening move A3
is a blunder: it believes B@A3 is B+9; the fixpoint says B−9 (the winning
first move is the centre, which the engine reads as B−9 when it is B+9).

The false-positive coincidence for cells 1 and 5 is incidental — the rows at
those keys are other boards' entries; a probe confirming the substitution is
in `check33f_tmp.zig` output (B@cell1: artifact key 3 = true (−9−9-adjacent
row) vs engine key 4 = two-stone board's row).

### 3.3 Why the format-level checks could not catch this

- A5 (round-trip), A6 (corruption), A9 (hash) never interpret the colex
  values — convention-agnostic.
- A3 (colour inversion) would catch it — `flipColex` is combinatorial — but
  A3 has never run: no WZO2 artifact existed.
- The empty-goban anchor passes in BOTH conventions (index 0), so the root
  value is not a detector. A 4×4 WZO2 built by the current builder would
  reproduce its committed root (+1, index 0) and silently misaddress every
  other state — the same trap.

### 3.4 Consequence for the 4×4 build

**The 4×4 WZO2 build must not run until the builder is fixed.** A ~1 h /
515 MB build carrying this defect would pass its headline root value and fail
everywhere else, burning a wall-clock session for a known-bad artifact.

### 3.5 Where the fix belongs (not T178's file)

`src/oracle_v2_build.zig` (M2b, O-5/T165 ownership): convert each exp6 board
rank to the engine colex before writing group headers
(`unrank_board4` → `colex.Indexer(4,4).colex_from_pos`). My harness
(`src/oracle_v2_consumer_load.zig`) mirrors the builder's keying by design and
must convert in lockstep. Per verify-then-promote, an independent seat should
confirm the fix (e.g. re-run this consumer-load test + the A3 colour-inversion
check on a 3×3 artifact whose keys use the engine colex).

## 4. What this run establishes

1. The WZO2 **consumer load path works** (header validation, group index,
   sparse-prefix lookup, SHA-256) — the engine loads a genuine WZO2 in
   milliseconds and answers the empty-goban queries correctly.
2. The committed anchors reproduce through a genuine WZO2 round-trip at 3×3:
   +9 / −9 with L==H (fresh-start, basic-ko, TIE=0), census 73,758, 16
   sweeps.
3. **The M2b builder encodes goban addresses in the wrong colex convention**
   — a CRITICAL defect that survives every format-level check and falsifies
   the consumer path at the first non-empty position (7/9 measured at 3×3).
4. The 4×4 consumer-load query (the brief's literal ask) is blocked on the
   absent artifact; running the build with the current builder is
   contraindicated by finding 3.

## 5. What could not be established

- The 4×4 empty-goban query through the consumer (blocked on the artifact).
- Whether the fix is a builder-only change or the M3 engine is also involved:
  the engine's convention matches the contract and v1, so the builder is the
  sole offender as read; confirmation by the fix seat is required.
- Any claim beyond the fresh-start anchor: no L/H bracket semantics were
  re-derived here beyond the 3×3 root.

## 6. Repro

```sh
tools/runner -- zig run -O ReleaseFast src/oracle_v2_consumer_load.zig   # build 3x3 WZO2 + load + query
printf 'boardsize 3\nclear_board\ngenmove b\ngenmove w\nquit\n' | \
  /tmp/weizigo/weizigo-oracle-v2 untracked/oracle-v2/oracle-3x3-v2.wzo2  # the consumer trace
```

Artifact: `untracked/oracle-v2/oracle-3x3-v2.wzo2`, SHA-256
`91e215a3b9dc8018a705486097121162be74314a5c3189dcead601bff4e5f6cd`
(committed-evidence copy of the run's stdout above).
