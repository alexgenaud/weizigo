<!--managent set=B-->
# T127 — `PROGRESS.md` and `CURRENT.md` are a full wave behind

**Type:** ANALYSIS + doc edit · **Holds:** `docs/epistemic/PROGRESS.md`,
`docs/status/CURRENT.md` · **Needs:** T123 T124 T125 T126 (cite the register
after it is correct, not before)

## The defect

Twenty tasks (T100–T119) completed on 2026-07-30. `bin/managent status`
recorded them, `model-perf.md` absorbed them, and **neither narrative store
mentions a single one**.

- `docs/epistemic/PROGRESS.md` — header still reads
  `Task: NARRATIVE-LAYER · … · Date: 2026-07-29`.
- `docs/status/CURRENT.md` — top block still reads
  `STATE AS OF 2026-07-29 18:35 CEST — Opus/Orcha`, and that block declares it
  "supersedes every dated section below".

So the file that claims to be authoritative is the stalest thing in the tree. A
fresh session following the documented recovery path
(`STATE.md → managent status → handover → CURRENT.md`) now reads a state one
full wave out of date, and `managent status` no longer carries the wave either,
because T120 purged it.

## What is missing from the narrative

| finding | source |
|---|---|
| 4×4 root V=+1 (bracket [+1,+16]), H=+16 verified genuine | EXP-6, T104 |
| T13 reproduced; 154/508 (30.3%) history-sensitive, not 12 | T110 |
| ADR-0006 not falsified; 3 corrections; new self-eye-fill hazard class | T114 |
| 4×4 ko-sensitive region 99.997% single-ko | T117 |
| brute-force corroboration withdrawn across EXP-4→EXP-7 | T102 |
| all five T101A evidence-free PROVEN rows closed | T105/106/107/111/112 |
| `.wzo` artifact written, 258 MB | T113 |

## Task

Bring `PROGRESS.md` up to date as the cite-tagged through-line it is designed
to be — every load-bearing sentence carrying `[ID:STATUS]`, verified by
claimlint C6. Then rewrite `CURRENT.md`'s top block for the live state.

`CURRENT.md` is explicitly ephemeral. Do not grow it: **replace** the
superseded block rather than adding a seventh dated section on top of six. If
the accumulated blocks below are all superseded, say so once and delete them.

## Deliverable

Both files current, `bin/weizigo-claimlint` C6 clean.
