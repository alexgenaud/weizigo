# Provenance — `c2-katago-live-play/` (B22 external-engine match run)

Added 2026-07-28 by the `docs/evidence/` rescue sweep. Files are **verbatim and
unmodified**; provenance lives here so the run outputs stay byte-identical.

## ⚠ Status: UNCITED — rescued, not promoted

**No committed document cites any file in this directory.** The only record
that this run means anything is `untracked/B41-consolidate.md:13`, itself
git-ignored, which says:

> | C2 confirmed in live play vs Katago | B22 | Corroborates T13 |

The B22 bundle (`untracked/B22-*.md`) is **gone** — see the CONFIRMED LOST
table in `docs/evidence/README.md`. What survives is the probe source and the
raw game records, with no analysis and no stated acceptance criterion.

Consequences, stated plainly:

- This directory is **not** evidence for `GLOBAL.C2`, `3x2.T13`, `4x4.C2`, or
  anything else, and must not be cited as such.
- It is rescued because it is a probe source plus its run output for a
  load-bearing question, and it would otherwise be swept.
- To make it evidence, someone must re-derive the analysis from the logs and
  commit a durable note that names a claim ID. Until then it is raw material.

## What the run was

`katago-match.py` alternates colours between `bin/weizigo-oracle` (the GTP
oracle player) and KataGo over N games on a small board, writing one SGF plus
two stderr transcripts per game. The weizigo-side stderr transcripts contain the
engine's own per-move diagnostics (including the `HISTORY-DIVERGED` line added
for the UNDEF/divergence work), which is where a live-play C2 divergence would
be visible.

Reproduction needs a KataGo binary, a KataGo network, and a `.wzo` artifact —
none of which are in git. See `docs/evidence/README.md` §"Artifacts not
committed".

## Files

| file | original path | original mtime | bytes | sha256 (first 16) |
|---|---|---|---|---|
| `katago-match.py` | `untracked/katago-match.py` | 2026-07-26T22:29:46 | 12,683 | `f83ab10172e47d70` |
| `katago-match.cfg` | `untracked/katago-match.cfg` | 2026-07-26T22:29:50 | 824 | `11a19ac5fc0f17b1` |
| `sgf/` (30 files, 220 KB) | `untracked/sgf/` | 2026-07-26T22:30 | — | per-file below |

`sgf/` per-file sha256 (first 16), all mtime 2026-07-26T22:30:

| file | sha256 |
|---|---|
| `g00-weizigo-vs-katago-black-stderr.log` | `41ba8413a7e594b2` |
| `g00-weizigo-vs-katago-white-stderr.log` | `fe8050a2044948b8` |
| `g00-weizigo-vs-katago.sgf` | `26ef9a1bdd190992` |
| `g01-katago-vs-weizigo-black-stderr.log` | `a6448458fac94f57` |
| `g01-katago-vs-weizigo-white-stderr.log` | `becfebfa6e2e4c36` |
| `g01-katago-vs-weizigo.sgf` | `ba4e52ea66d5461a` |
| `g02-weizigo-vs-katago-black-stderr.log` | `98f64bc0ea76b768` |
| `g02-weizigo-vs-katago-white-stderr.log` | `b7d0cc035a7db8df` |
| `g02-weizigo-vs-katago.sgf` | `af41a2be9e44799a` |
| `g03-katago-vs-weizigo-black-stderr.log` | `bba85319873d7753` |
| `g03-katago-vs-weizigo-white-stderr.log` | `0c669aed63a93a0c` |
| `g03-katago-vs-weizigo.sgf` | `f8d95d96225c9cfd` |
| `g04-weizigo-vs-katago-black-stderr.log` | `d90aa81f898fda4b` |
| `g04-weizigo-vs-katago-white-stderr.log` | `01987d6715272fc4` |
| `g04-weizigo-vs-katago.sgf` | `b837e4b348b58705` |
| `g05-katago-vs-weizigo-black-stderr.log` | `18e1f4887f529678` |
| `g05-katago-vs-weizigo-white-stderr.log` | `481c175c0a640103` |
| `g05-katago-vs-weizigo.sgf` | `f1535cd0b25f9534` |
| `g06-weizigo-vs-katago-black-stderr.log` | `03b56d598461f3f3` |
| `g06-weizigo-vs-katago-white-stderr.log` | `e59ef13760337b35` |
| `g06-weizigo-vs-katago.sgf` | `022458c55117861a` |
| `g07-katago-vs-weizigo-black-stderr.log` | `5d72ceecf2a1aef5` |
| `g07-katago-vs-weizigo-white-stderr.log` | `46d84454af917d6c` |
| `g07-katago-vs-weizigo.sgf` | `ab353afe8e885c84` |
| `g08-weizigo-vs-katago-black-stderr.log` | `ea8fbd5ba4bc6931` |
| `g08-weizigo-vs-katago-white-stderr.log` | `d6421b1115a451f1` |
| `g08-weizigo-vs-katago.sgf` | `75b2d3a42c63bf0f` |
| `g09-katago-vs-weizigo-black-stderr.log` | `f4cdb4d8af2ccf8c` |
| `g09-katago-vs-weizigo-white-stderr.log` | `a231c4bcf3ab073b` |
| `g09-katago-vs-weizigo.sgf` | `22553da53a2fc821` |

## Left behind deliberately

`untracked/katago-logs/` (13 files, 312 KB) — KataGo's own engine logs
(third-party search output, not weizigo measurements). Recorded in
`docs/evidence/README.md` as PROCESS; not copied.
