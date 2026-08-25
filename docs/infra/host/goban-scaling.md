# Goban scaling — measured resource cost per board size

**Ledger:** `docs/infra/host/goban-scaling.jsonl` (append-only, one row per solve).
**Capture:** `tools/goban-scaling-capture.sh <rows> <cols> <regime> <task> -- <command>`.

Every row is **measured**. A field that could not be read is `null`, never estimated — the
claims register carries 85 PROSE-ONLY rows because guesses were written down as facts.

## Why this exists

Asked on 2026-08-25 how RAM, cores, time and disk scale from 2×2 through 5×5, the honest
answer was: **state counts and disk scale predictably and are known; time and solve-RAM have
never been recorded anywhere.** This ledger closes that gap by capturing the cost of each
solve as it happens, so the next answer is measured rather than interpolated.

## Known before this ledger (not from it)

Legal-position counts, `src/enumerate.zig:207` (Tromp A094777); 3×2 re-measured by T912.

| board | points | colex slots 3^p | legal positions | legal % | WZO1 file |
|---|---|---|---|---|---|
| 2×2 | 4 | 81 | 57 | 70.4% | 518 B |
| 3×2 | 6 | 729 | 489 | 67.1% | 4,406 B |
| 3×3 | 9 | 19,683 | 12,675 | 64.4% | 118,130 B |
| 4×3 | 12 | 531,441 | 321,689 | 60.5% | 3.04 MB |
| 4×4 | 16 | 43,046,721 | 24,318,165 | 56.5% | 246 MB |
| 5×4 | 20 | 3,486,784,401 | ? | ? | **19.5 GB** |
| 5×5 | 25 | 847,288,609,443 | 414,295,148,741 | 48.9% | **4.62 TB** |

**WZO1 size is exactly `6 × 3^(w·h) + 32` bytes** — verified byte-for-byte against all four
committed artifacts (518 / 4,406 / 118,130 / 3,188,678). It is **dense over the raw colex space,
not over legal positions**: every slot costs 6 bytes whether the position is legal or not.

The six bytes are **three quantities × two sides to move**, stored struct-of-arrays as six
columns each `3^(w·h)` long (`src/artifact.zig:32-61`): value (`vb`,`vw`), flags (`fb`,`fw` —
KO_SENSITIVE, FROM_FORWARD), and distance-to-terminal (`db`,`dw`, 255 = FAR).

**A correction on record:** an earlier reading of "~9-10 bytes per legal position" was this
number divided by the wrong denominator. It agreed with 3×3 and 4×3 only because legal density
is ~60% there and 6/0.6 ≈ 10. The rate is 6 bytes per *slot*, and it does not vary.

**Solve RAM, one real data point:** T912 measured the history-exact solver at 3×2 — 74 bytes/node,
**0.541 new states per node, flat across five doublings with no plateau** (the memo barely reuses,
because nearly every path is a distinct ban set). Extrapolating 400 M nodes gave ~29.6 GB.

**Cores: 18 (6P + 12E), and the retrograde solve is single-threaded.** Threading exists in
`arena.zig`, `differential.zig`, `exp6_solve.zig` — harness and differential tooling, not the
solve. Any wall recorded here is a one-core wall until that changes.

**Build cost is separate and must not be confused with solve cost** (T921, this host):
cold Debug `zig build test` peaks **11,237 MB**, warm **1,821 MB**. A build can land on the same
host as a solve, and the admission arbiter does not track builds.

## Regimes

Record which one produced the row — they are not comparable:

- `writes-off` — no search results written to the transposition table; the regime T912 vindicated
  and the one `4x4.D3` asks about.
- `memo-reuse` — cross-branch reuse; **known unsound under superko** (differs from writes-off on
  170 of 378 ko-sensitive 3×2 pairs).
- `deps-guarded` — Kishimoto–Müller dependency fingerprints (Track B).
- `history-exact` — ground truth; completes on only 68 of 600 roots at 3×2.

## Reading the ledger

    python3 -c "import json;[print(json.loads(l)) for l in open('docs/infra/host/goban-scaling.jsonl')]"

Compare only within a regime, and state the core count and whether the solve was threaded.

**T927 sleep fields (2026-08-25):** every row carries `sleep_prevented`
(true|false - was a `caffeinate -i` assertion held for the solve?) and
`sleeps_during_run` (N - host "Entering Sleep" events in the run window, or
`null` when pmset was unavailable / the window was not recorded). A wall
figure taken across a sleep is silently wrong, so the capture script holds
the assertion and counts sleeps either way; a run that slept is MARKED, not
discarded. The 8 rows captured by T924 pre-date the guard and carry
`sleep_prevented=false` with `sleeps_during_run=null` - no `start_epoch`
was recorded, so whether any spanned a sleep is unknowable (see
findings/T927-sleep-unprotected-runs.json).

## WZO1 vs WZO2 — the two artifact formats

Both are committed and both are live. They are not versions of one thing; they answer different
questions, and the difference decides the 5×N frontier.

| | **WZO1** (`src/artifact.zig`) | **WZO2** (`src/artifact2.zig`) |
|---|---|---|
| layout | dense, struct-of-arrays, 6 columns | sparse, grouped inline, segregated |
| size | `6 × 3^(w·h) + 32` | `128 + n_groups × 5 + n_entries × 4` |
| cost model | every colex slot pays, legal or not | only stored entries pay |
| key | (colex, side) | (colex, side, **ko_point**, **passes**, terminal), packed in one key byte |
| value | one value + flags + DTT | **L and H separately** + DTT |
| access | O(1) byte-addressable | mmap + group index (`vb_scc_4x4.zig:831`) |
| RAM to write | one contiguous `6 × 3^(w·h)` allocation (`artifact.zig:160`) | entry stream |
| RAM to read | six more arrays of `3^(w·h)` (`artifact.zig:218-224`) | pages on demand |
| provenance | — | SHA-256 in header at offset 40 |
| frozen | — | at G2, oracle-v2 M1 design (T165) |

**The difference is semantic before it is a size difference.** WZO1's own header says it: *"the
key has no room for a ko point, so a stored value never knows a ko is pending"* — its payload is
only the `ko == NONE, passes == 0` slice of a solve (`artifact.zig:44-54`, ADR-0020). WZO2 carries
the ko point in the key and stores the `[L,H]` bracket rather than a collapsed value, which is
what makes it able to represent the unsettled ko-sensitive region at all.

### What this means per board

- **4×4** — WZO1 at 246 MB is comfortable. Nothing to change.
- **5×4** — WZO1 needs a single **20.9 GB contiguous allocation to write** and another to read.
  On a 48 GB host that is a hard RAM wall, and it binds *before* disk does. Compressing the file
  afterwards does not help, because the wall is during the run.
- **5×5** — 4.62 TB dense. Out of reach in WZO1 in any form, on any disk this project has.

### Compression: what helps when

- **After the run** — gzip wraps the file; the format stays byte-addressable once decompressed
  (`artifact.zig:64`). Helps storage only. Does nothing for the allocation wall.
- **During/before** — only structural change helps, and each is a `colex_layout` version bump:
  legal-only fold (~1.8× at 4×4, ~2× at 5×5), canonical-only under the dihedral group (up to 8×
  square, 4× rectangular), dropping unused columns (up to 3× if only values are needed), and
  sub-byte packing. Combined these are ~40×, which is the difference between 4.62 TB and ~100 GB.
- **Or use WZO2**, which is already the sparse mmapped design and already frozen.

**Open question, not answered here:** why the 4×4 path still writes WZO1 when WZO2 exists. The
differential tests key against the committed WZO1 goldens (`differential.zig:1469`), so there may
be a sound reason. Nobody should cost 5×4 before that is settled.
