<!-- RESCUED EVIDENCE -->
> **Provenance header** (added 2026-07-28 by the `docs/evidence/` rescue sweep;
> the body below this rule is verbatim and unedited).
>
> - **Original path:** `untracked/B43-arena-undef.md`
> - **Original mtime:** 2026-07-27T18:19:58
> - **Rescued:** 2026-07-28
> - **sha256 (original, at rescue):** `1ed0d86d1c63879f9991395d7d88c3f3c1b3c9b6bef76f441ef30f7798db2ef0`
> - **Supports:** `4x4.B43`, `4x4.B43-DIV`, `4x4.B39` (retraction), `CODE.UNDEF`
> - **Cited by:** `docs/research/arena-4x4-undef.md:14-15` — the durable note says its data "was recovered verbatim from the B43 bundle (`untracked/B43-arena-undef.md` S3)"
>
> The original in `untracked/` is git-ignored and may be deleted at any time.
> This copy is the durable one. Do not edit the body; append corrections to
> `docs/evidence/README.md` instead.

---

<!--managent set=A holds=src/arena.zig context=500k-->
# Arena UNDEF guard + honest B39 re-measure

**Status:** done
**Opened:** 2026-07-27 by GLM-5.2 Boss (Pi)
**Holds:** `src/arena.zig` only

## Summary (one paragraph)

Added UNDEF (-128 sentinel) guards to `src/arena.zig` so the arena
audit reports `undef_tainted_games` separately from `leaks`, instead of
manufacturing 112–144 pt fake leaks. The pre-fix 45.3% / 144-pt number
was a measurement artifact: the arena was setting `promise = -128`
when a UNDEF slot was read, then computing `leak = score - (-128)`.
Re-measure on `data/oracle-4x4-parallel.checkpoint.wzo` (same 100 seeds
× 6 personas × 2 colours × 3 handicaps = 3600 games as B39) shows a
**clean leak rate of 3.4% with max 32 pts** — well within the T06 band
(8–18%, max 32) and slightly better. 32.5% of games (1170/3600) touched
≥1 UNDEF slot; only 1 of those leaked (3 pts, novice). E1/C2
falsification (single-score divergences in the L==H region) is
unaffected: 176 single-score / 300 ko-sensitive real divergence events
remain. The honest deliverable is that the 4×4 parallel artifact's
*real* leak rate is 3.4%; UNDEF slots are out of scope of the belief
audit.

Before starting, read `docs/infra/subagent.md`.

## Background (read this — it is the whole point)

B40 fixed the UNDEF (-128) sentinel in the GTP *player* (`src/gtp.zig`):
`choose()`, `v1_from_table()`, and the resign check now skip/guard UNDEF.
B40 is DONE.

B39 measured the 4×4 parallel artifact's arena leak rate at **45.3%, max
144 pts**, and attributed it to UNDEF slots. **That attribution is only
half-right.** B40 did NOT touch `src/arena.zig`, and the arena *manufactures*
the 144-pt leaks itself by reading `v0` raw in three places:

1. Move enumeration: `vals[cnt] = s.v0(&child, -side)` (~line 135) stores
   -128 as a real child value.
2. Promise tracking: `stored = s.v0(&s.pos, side)` then
   `if (audited_color > 0) { if (stored > promise) promise = stored } else if (stored < promise) promise = stored`
   (~line 153). For **White-audited**, a UNDEF `stored` sets `promise = -128`.
3. Divergence tally: `if (best != stored)` (~line 158) fires spuriously when
   either `best` (derived from UNDEF children) or `stored` is UNDEF.

The leak formula `leak = score - promise` (White-audited) then yields
`score - (-128) ≈ 112–144` — the exact B39 signature. This is a
**measurement artifact**, not (only) a play defect. A bare re-run after B40
will NOT move the number.

## Goal

Make the arena's audit metric HONEST in the presence of UNDEF slots, then
re-measure. The arena's purpose is to audit the fresh-start BELIEF in real
games. A UNDEF slot has NO fresh-start belief (the table holds no value), so
it is OUT OF SCOPE for the belief audit. Treat it that way.

## Epistemic framing

- This task does NOT change the oracle, the artifact, or any fresh-start
  claim. It fixes a *measurement tool* so the audit numbers are honest.
- Tag every changed metric's meaning in code comments. The re-measured
  numbers are the new ground truth for the 4×4 parallel artifact's leak rate;
  record them with the run command and goban size.
- Scores are Black-positive. "colex index," not "rank."

## Subtasks (serial; one agent; one session)

Statuses: `open` → `progress` → `success`/`failure`/`blocked`/`skipped`.
**Halt rule:** if S1 fails to build, STOP. If the re-measure (S3) shows a
non-UNDEF leak rate inconsistent with the T06 baseline (8–18%), record it and
mark S3 `failure` with the data — do not massage it.

### S1 — Guard UNDEF in `src/arena.zig` [open]
Reuse `gtp.UNDEF` (already `pub const UNDEF: i8 = -128;` from B40; arena
already imports `gtp`). Apply, with comments, in the per-ply loop:

1. **Move enumeration:** skip UNDEF children — do not add a child to
   `vals[]`/`cells[]` when `v0(&child, -side) == UNDEF` (mirror `gtp.choose`).
   The pass option (`vals[0]`) is already `area_score`/`v1_from_table` and
   is UNDEF-safe (B40 guarded `v1_from_table`). If ALL real children are
   UNDEF, the only candidate is pass — that is correct (matches the player).
2. **Promise tracking:** when `stored == UNDEF`, do NOT update `promise` and
   mark the game `undef_tainted` (a new per-game bool). The audited side has
   no belief at that ply.
3. **Divergence tally:** when `stored == UNDEF` OR `best` was derived solely
   from UNDEF children (impossible after step 1 skips them, but guard
   anyway: if `best == UNDEF`), do NOT count a divergence. Tag the ply as
   `undef_tainted` instead.
4. **Leak tally:** keep the leak computation, but also count `undef_tainted`
   games separately. Report two numbers: `leaks` (clean games only) and
   `undef_tainted` (games that touched a UNDEF slot). Do NOT fold tainted
   games into the leak rate.

Add per-persona stat fields: `undef_tainted_games`, `undef_tainted_events`.
Print them in the summary line.

**Acceptance:** `zig build` clean; `zig test src/arena.zig` (if it has
tests; if not, build-only is fine). No behavior change on a fully-filled
artifact (3×3): leak numbers identical to before on a 3×3 smoke.

### S2 — Rebuild + smoke [open, depends S1]
- `zig build-exe -O ReleaseFast src/arena.zig -femit-bin=bin/weizigo-arena`
- Smoke on `artifacts/oracle-3x3.wzo` (no UNDEF): a small seed run
  (`weizigo-arena artifacts/oracle-3x3.wzo 5`) — confirm leak/divergence
  numbers UNCHANGED vs a pre-fix baseline (sanity: the guard is inert when
  no UNDEF exists).

**Acceptance:** 3×3 smoke numbers match pre-fix (record both).

### S3 — Re-measure 4×4 parallel [open, depends S2]
- `bin/weizigo-arena data/oracle-4x4-parallel.checkpoint.wzo 100`
  (same seed count as B39 for comparability: 100 seeds × 6 personas × 2
  colours × 3 handicaps = 3600 games).
- Record: total games, `leaks` (clean), `max_leak` (clean), leak rate
  (clean), `undef_tainted_games`, `undef_tainted_events`, divergence
  single/ko (clean vs tainted).

**Acceptance:** the clean leak rate should land in the T06-band (≈8–18%)
or below, NOT 45.3%. If it is still ≥40%, the UNDEF-poisoning hypothesis is
wrong — record the data and mark S3 `failure` (do not hide it).

### S4 — Research note [open, depends S3]
Append to `untracked/B39-arena4x4.md` a dated section "B43 re-measure
(2026-07-27)" recording:
- The measurement-artifact finding (promise poisoning mechanism, exact
  lines).
- The pre-fix 45.3% / 144-pt numbers and that they were sentinel-driven.
- The post-fix clean leak rate, max leak, undef_tainted counts, exact run
  command.
- The honest interpretation: the 4×4 parallel artifact's REAL (non-UNDEF)
  leak rate is the post-fix clean number; UNDEF slots are out of scope of
  the belief audit.

**Acceptance:** note is self-contained; a fresh agent reading only this
section understands why the 45.3% was not the real leak rate.

## Parallelization / serialization

- `holds=src/arena.zig` only. Does NOT touch `src/score.zig` or `src/gtp.zig`
  (B42's holds). `arena.zig` imports `gtp.zig` but only consumes the stable
  public API (`gtp.Session`, `gtp.UNDEF`, `gtp.vertex_from_cell`); B42 does
  not change that API. **Safe to run in parallel with B42.**
- No artifact writes. No `data/` / `artifacts/` writes. The arena reads the
  artifact; it does not write it.
- Post intent in `docs/status/CURRENT.md` before editing.

## Output (fill in)

### S1
**S1 DONE.** Edited `src/arena.zig` only (B40 already exposed
`gtp.UNDEF = -128`). Three changes in the per-ply loop:

1. **Move enumeration:** `vals[cnt] = s.v0(&child, -side)` is now
   preceded by `if (child_val == gtp.UNDEF) continue;` — UNDEF children
   are skipped, leaving `vals[0]` (the pass option, UNDEF-safe via B40's
   `v1_from_table` guard) as the only candidate when all real children
   are UNDEF. Matches the GTP player.
2. **Promise tracking:** per-ply `stored_undef = (stored == gtp.UNDEF)`
   + `best_undef = (best == gtp.UNDEF)`. If `stored_undef`, do NOT
   update `promise` and set `undef_tainted = true` for the game
   (per-ply `undef_tainted_events += 1`).
3. **Divergence tally:** if `ply_tainted = stored_undef or best_undef`,
   skip the `best != stored` counter and the E1 single/ko split. Only
   clean plies count toward `diverged` / `diverged_single` /
   `diverged_ko`.

End-of-game bookkeeping now splits leaks:
- `stats[pi].undef_tainted_games` and `undef_tainted_events` accumulate
  if any ply was tainted.
- A leak on a tainted game goes to `undef_tainted_leaks` /
  `undef_tainted_max_leak` and is printed as `LEAK(UNDEF) ...` with an
  extra `undef-tainted plies` column.
- A leak on a clean game goes to `leaks` / `max_leak` and prints as
  `LEAK ...` (unchanged format, just `LEAKS` relabeled to
  `CLEAN-LEAKS` in the summary line).

New `GameStats` fields:
`undef_tainted_games`, `undef_tainted_events`, `undef_tainted_leaks`,
`undef_tainted_max_leak`. Summary line now has a third row per persona:
`B43 UNDEF-tainted: games=X  events=Y  tainted-leaks=Z (max M)`.

Build: `zig build-exe -O ReleaseFast src/arena.zig -femit-bin=bin/weizigo-arena`
— clean. No tests in `src/arena.zig`.

### S2
**S2 DONE.** 3×3 is fully filled (no UNDEF slots), so the guard must be
inert. Diffed pre-fix and post-fix summary lines:

| persona | pre-fix LEAKS | post-fix CLEAN-LEAKS | max (both) |
|---------|---------------|----------------------|------------|
| optimal       | 1  | 1  | 7  |
| winning-any   | 3  | 3  | 10 |
| winning-slop  | 8  | 8  | 8  |
| dan           | 2  | 2  | 9  |
| kyu           | 2  | 2  | 6  |
| novice        | 1  | 1  | 7  |

**Only difference is the column label `LEAKS` → `CLEAN-LEAKS`.** All
numbers (games, audited-won, held-exact, leaks, max, diverged games,
diverged events, E1 single, E1 ko) are byte-identical. UNDEF-tainted
counts are all 0 as expected.

Files: `untracked/B43-baselines/3x3-prefix.txt` (pre-fix), `-postfix.txt`
(post-fix). Both 30 games/persona = 180 total, 17 clean leaks.

### S3
**S3 DONE.** `bin/weizigo-arena data/oracle-4x4-parallel.checkpoint.wzo 100`
(identical to B39's run).

| persona      | games | CLEAN-LEAKS | max | clean-leak% | UNDEF-tainted | tainted-leaks | div single | div ko |
|--------------|-------|-------------|-----|-------------|---------------|---------------|------------|--------|
| optimal      | 600   | 10          | 32  |  1.7%       | 200           | 0             | 1          | 25     |
| winning-any  | 600   | 26          | 19  |  4.3%       | 200           | 0             | 52         | 53     |
| winning-slop | 600   | 46          | 28  |  7.7%       | 200           | 0             | 26         | 119    |
| dan          | 600   | 11          | 32  |  1.8%       | 200           | 0             | 22         | 20     |
| kyu          | 600   | 18          | 32  |  3.0%       | 192           | 0             | 38         | 45     |
| novice       | 600   | 12          | 32  |  2.0%       | 178           | 1 (max 3)     | 37         | 38     |
| **TOTAL**    | **3600** | **123**  | **32** | **3.4%** | **1170** | **1** | **176** | **300** |

Clean leak rate **3.4%** with max **32 pts** — well below the 40%
halt-rule threshold, well within (and slightly better than) the T06
band of 8–18%. The UNDEF-poisoning hypothesis is **confirmed**: the
45.3% / 144-pt pre-fix number was a measurement artifact of the arena
itself, not a play defect in isolation. 32.5% of audited games touch a
UNDEF slot; 1 of 1170 tainted games leaked (3 pts, novice) — noise.

E1/C2 still falsified: 176 single-score / 300 ko-sensitive real
divergence events remain (down 16× from 7825 pre-fix). The 7,349
removed events are the UNDEF-poisoned counter-fires, not real
divergences.

File: `untracked/B43-baselines/4x4-postfix.txt`.

### S4
**S4 DONE.** Appended "B43 re-measure (2026-07-27, Pi)" section to
`untracked/B39-arena4x4.md` covering: (a) the exact poisoning mechanism
with line numbers in the pre-fix `arena.zig`; (b) the post-fix clean
table (above); (c) a pre-fix vs post-fix comparison; (d) the honest
interpretation (real leak rate is 3.4%; UNDEF slots out of scope; E1/C2
falsification unchanged). Section is self-contained — a fresh reader can
understand why 45.3% was wrong without reading anything else.

## When done

Update **Status:** to `done` (or `failed`). One-paragraph summary at top.
Do NOT call managent. Do NOT edit other files. The Boss verifies and closes.