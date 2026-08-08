Task: T423 · Role: worker · Model: glm-5.2 · Date: 2026-08-08

# `/tmp/weizigo` date-partition — archive of 2026-08-07 and earlier

**Landmark:** advances `L4 (the ledger is clean)` — fleet `/tmp` scratch is now
date-partitioned so this week's outputs are separable from next week's, and the
top level is no longer a 349-entry undifferentiated pile.

## What changed

`/tmp/weizigo` was **9.5 GB across 347 top-level entries** with no date
structure. It is now **5 top-level entries**: a date archive, an empty new-work
dir, one cache, and two compiled binaries.

| entry | what | size |
|---|---|---|
| `260707/` | archive of all dated task outputs from 2026-08-07 and earlier (342 items: 45 dirs + 297 files) | 9.4 GB |
| `260808/` | new-work partition for 2026-08-08 onward (empty) | 0 B |
| `zigcache-t395/` | zig cache — left in place | 69 MB |
| `t393-census` | compiled census binary (Mach-O), not cited, may still be useful — left in place | 548 KB |
| `weizigo-t393-census` | compiled census binary (Mach-O), not cited, may still be useful — left in place | 512 KB |

Total `du -sh /tmp/weizigo` is unchanged at **9.5 GB**: the operation was a
same-filesystem `mv` plus two zero-byte deletions, so no bytes were gained or
lost — only reorganized.

## What moved

All dated task outputs from this week (2026-08-05 through 2026-08-08 morning)
were moved into `260707/` with names preserved (`mv`, never copy-then-delete):

- **45 per-row directories**, including the per-row worktrees and scratch dirs:
  `t328-base/`, `t350-proto/`, `t366/`, `t368-*`, `t370-*`, `T371/`, `t372/`,
  `t375/`, `t375-verify/`, `t376-*`, `t380/`, `t381/`, `t382-run/`, `t385/`,
  `t386/`, `t387/`, `t389/`, `t392-worktree/` (7.1 GB worktree + its internal
  `.zig-cache`/`zig-out`), `t395-runs/`, `t401/`, `t402/`, `t403-prefix/`,
  `t406red2/`, `t407/`, `t408/`, `t409/`, `t411-*`, `t412/`, `t414/`, `t416/`,
  `t418/`, `t419/`, `t420/`, plus the non-row scratch dirs `nl/` (managent
  regression fixture) and `repro/` (23 MB repro scaffold).
- **297 loose files**: all row-prefixed files (`t3xx-*`, `T3xx-*`, `t4xx-*`,
  `T4xx-*`) and the non-row scratch outputs (`claimlint-*.txt`, `c2-*.txt`,
  `c4-*.txt`, `e*.txt`, `o*.txt`, `out-*`, `oracle-*.smd1*`, `repro*.log`,
  `reg*.out`, `rep*.log`, `s*.log`, `drive*.py`, `fmt*.zig`, `gtp.zig.mine`,
  `main-mixed.*`, `TREEMAP*`, `CLAIMS*`, `table.md`, `zigtest.out`,
  `zig-build-test-T400.log`, `verify-packets.py`, `split-diff.py`, etc.).

**Interpretation note.** The brief's step 2 named "per-row directories and loose
per-row files." I applied the operator's broader intent — *"move artifacts from
`/tmp/weizigo/` … cleaning up"* — to the non-row-prefixed loose scratch files
too, because leaving ~200 of them (`claimlint-after.txt`, `c2-main.txt`, …)
at the top level would defeat the partition. Moving is low-risk (same-FS `mv`,
nothing open), and none of these are caches or binaries. If the Orchestrator
disagrees, the items are trivially movable back; the archive preserves names
1:1.

## What stayed and why

- `zigcache-t395/` (69 MB) — explicit cache. Brief: leave caches.
- `t393-census`, `weizigo-t393-census` (two Mach-O binaries, ~1 MB total) —
  compiled census binaries, not cited in any doc, regenerable from source. The
  operator's carve-out — *"output binaries, etc are still useful, then can
  remain where they are"* — is permissive; I left them rather than move a
  binary something might still invoke. Cost of leaving: ~1 MB at top level.
- The two archive dirs `260707/` and `260808/` created by this task.

Caches that lived *inside* a per-row directory (`t366/cache`, `t372/cache`,
`t375-verify/cache`, `t392-worktree/.zig-cache`, etc.) moved *with* their row
directory. The brief's "per-row directories" move instruction takes precedence
for the top-level dir; an internal cache subdir is part of the row's artifact
set, not a standalone top-level cache.

## What was deleted

Only **two zero-byte files** — both unambiguous empty/failed-run remnants, none
cited in any doc:

| file | size | reason |
|---|---|---|
| `sum2.log` | 0 B | empty file |
| `repro-stdout.log` | 0 B | empty stdout capture (failed-run remnant) |

**Total bytes deleted: 0.** No non-zero file was deleted. The `repro*.log`
flood (19 files, 898–1194 B each) was *not* deleted: although all are
899-byte failed-run logs, their md5sums differ — they are distinct runs, not
duplicates, and the brief's rule is *"if a file's purpose is unclear, it is not
obvious — leave it."* They moved to `260707/` instead.

## Safety verification performed

1. **No live process had files open under `/tmp/weizigo`.** `lsof +D
   /tmp/weizigo` returned nothing before the move. A `zig build test` was
   running under `tools/runner` in the main repo, but it uses the repo's
   `.zig-cache` and `~/.cache/zig`, not `/tmp/weizigo`; `lsof` confirmed no
   `/tmp/weizigo` handles. The move therefore did not move files under a live
   process. (That suite finished during the task with exit 1 — the known
   red-on-fresh-clone state from the uninstalled pre-commit gate, unrelated to
   this task.)
2. **Every cited file is already rescued.** Independently verified: 288 files
   under `docs/evidence/RESCUED-tmp-2026-08-08/` and
   `docs/evidence/4x4-THIRD-PARTY/runs-2026-08-08/`. The single exception named
   in the brief — `/tmp/weizigo/t420/t381-evse`, a 666 KB Mach-O binary
   regenerable from committed source — was confirmed present and moved into
   `260707/t420/t381-evse`.
3. **`mv` within the same filesystem only.** No copy-then-delete cycles.
4. **Nothing inside the repository was modified** except this doc and its
   findings file. `docs/evidence/RESCUED-tmp-2026-08-08/` was not touched.

## C10 VOLATILE census — before / after

`bin/weizigo-claimlint` C10 VOLATILE counts (C10 reports citation *strings* in
committed docs, not file existence):

| | total C10 | under `/tmp/weizigo` |
|---|---|---|
| before | 120 | 55 |
| after | 120 | 55 |

**Unchanged** — C10 is a census of citation strings, and I edited no docs. The
on-disk effect of the move, measured against the 55 unique cited
`/tmp/weizigo` paths:

- **26** moved into `260707/` (their cited path no longer resolves at the old
  location, but content is rescued per §"Safety verification" — these are
  `*/cache` and `*/global` subdirs inside row dirs, regenerable caches, not
  evidence).
- **3** still resolve at the cited location (the three stay-items:
  `zigcache-t395`, `t393-census`, `weizigo-t393-census`).
- **26** were already missing before this task (pre-existing volatile paths,
  e.g. `/tmp/weizigo-zigcache` at `/tmp/`, `/tmp/weizigo-eyeprune-falsify`,
  bare `/tmp/weizigo` dir refs).

This is the accepted outcome the brief anticipated: *"the content is
committed … but report the C10 census before and after so the change is
visible rather than discovered later."*

## Convention for future rows

**New disposable scratch goes in `/tmp/weizigo/YYMMDD/`** (e.g. `/tmp/weizigo/260808/`
for 2026-08-08). A row that produces scratch creates or reuses that day's
partition. Caches and compiled binaries that outlive a single day may stay at
the top level or under their owning row dir; date-partitioning applies to
run outputs and scratch, not to long-lived caches.