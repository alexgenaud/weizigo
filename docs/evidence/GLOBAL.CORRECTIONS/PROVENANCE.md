# PROVENANCE — GLOBAL.CORRECTIONS / EXP-14

**Claim ID(s):** no standing row in `docs/epistemic/CLAIMS.md` under this ID;
the directory is named by the EXP-14 brief. Bears on the errata ledger named
in `docs/status/CURRENT.md`'s uncommitted-work table
(`docs/research/corrections-2026-07-27.md`).

**Task / worker / model:** EXP-14, executed by a console session.
**Model: GLM-5.2** (stated at dispatch).

**Date:** 2026-07-28.

**Commit (audit "now"):** `eebe3c2` (2026-07-29 01:02:55 +0200), named by the
brief. All source reads use `git show eebe3c2:<path>` / `git log -- <path>`;
working-tree HEAD at run time is `4fca047` (later) but is not used for any
verdict. `git diff eebe3c2..HEAD -- <each cited source>` is empty for every
cited source except none — i.e. every cited source is identical at HEAD and at
`eebe3c2`, so the verdicts hold identically at HEAD. (The post-`eebe3c2`
commits `495ef48`/`650b4f0`/`db689d0`/`2d872b3`/`4fca047` are EXP-11/EXP-16
work and touch none of the cited files.)

**Subject:** the five corrections in
`docs/research/corrections-2026-07-27.md` (A-1, A-2, A-3, B-1, C-1).

**Method (ANALYSIS — no probe binary; the artefacts are the sources
themselves):**

- Read `AGENTS.md` (foreclosures) and `docs/research/corrections-2026-07-27.md`
  in full.
- For each correction, located the cited source-of-truth and read it at
  `eebe3c2` via `git show eebe3c2:<path>`; verified every quoted string
  verbatim and every line citation.
- Cross-checked the corrections' analysis against
  `docs/research/ko-sensitive-chainability.md` (Measurements 1–3) and
  `docs/epistemic/GLOSSARY.md` (chainable term) at `eebe3c2`.
- Identified the "fixes since" window: commits between the corrections' write
  date (2026-07-27) and `eebe3c2` (2026-07-29). Sweept `git log --oneline
  --topo-order eebe3c2` and `git log -- <each cited path>`; exactly one commit
  (`7a0946a`) touches any cited source.
- Verified the calibration artifacts exist on disk (`ls artifacts/`):
  `oracle-2x2.wzo`, `oracle-3x2.wzo` both present (2026-07-27 18:49–18:50).
- Re-derived B-1 from the source code: `src/gtp.zig` imports
  (`:54–58`), `v0` (`:102`), `v1_from_table` (`:137`), `choose` (`:184–226`),
  `pick`, `countColor`, `applyMove`, and the `genmove` handler; `grep -n
  "@import|retro" src/gtp.zig` confirms no `retro.zig`. `src/artifact.zig`
  schema (`:23–53`), `column_count = 6`, payload `HEADER_LEN + 6 * t` at
  `:140`/`:181`.
- Re-derived A-1 from `ko-sensitive-chainability.md:195–210` (Measurement 2
  ban table) and A-3's transcript counter-example at
  `regressions/4x4-black-win-after-ko.txt:74`.
- Re-derived C-1's calibration numbers from
  `ko-sensitive-chainability.md` Measurement 1 (2×2: 19.51% / 0 outside; 3×2:
  19.05% / 0 outside) and confirmed both cited artifacts exist.

**Acceptance criterion (from the brief):** one file
`docs/evidence/GLOBAL.CORRECTIONS/cross-check-2026-07-28.md` containing the
per-correction table, the counts, the "fixes since 2026-07-27" section, the
"wrong corrections" section, the "partial corrections" section, the mandatory
calibration, and the two-most-consequential + one-to-retract prose. All
present in the sibling file. **Verdicts delivered: verified=2 (B-1, C-1),
partial=3 (A-1, A-2, A-3), stale=0 (standalone), wrong=0.**

**Calibration case (per brief):** the audit's sensitivity was demonstrated by
finding non-trivial staleness — three `regressions/README.md` / `src/gtp.zig`
file-line targets fixed by `7a0946a` (so this is not a zero-finding audit), plus
the B-1 `src/gtp.zig` line-number drift (citations shifted by `7a0946a`'s
comment-only rewrite, substance unchanged), plus the corrections-doc-preamble
staleness (the 1:37-sample 4×4 figure superseded by the exhaustive 21.33%
run). Three corrections (A-1, B-1, C-1) were hand-re-derived from primary
sources, not from the correction's own wording.

**Cited source files — last-touched commit at `eebe3c2` (and at HEAD):**

| source file | last commit @ `eebe3c2` (= last commit @ HEAD) | date | note |
|---|---|---|---|
| `docs/research/corrections-2026-07-27.md` | `7c71fe5` | 2026-07-28 11:49:30 +0200 | the corrections doc itself; added in this commit |
| `docs/research/ko-sensitive-chainability.md` | `7c71fe5` | 2026-07-28 11:49:30 +0200 | source-of-truth for A-1/C-1 numbers |
| `regressions/README.md` | `7a0946a` | 2026-07-28 11:49:30 +0200 | **fixed by `7a0946a`** — A-1/A-2/A-3 file targets mooted |
| `regressions/4x4-black-win-after-ko.txt` | `753584f` | 2026-07-27 23:28:18 +0200 | transcript; A-3's `:74` quote still exact |
| `src/gtp.zig` | `7a0946a` | 2026-07-28 11:49:30 +0200 | **comment-only rewrite by `7a0946a`** — A-3 `:37` target mooted; B-1 line citations shifted, substance unchanged |
| `src/artifact.zig` | `58a4dac` | 2026-07-27 18:49:54 +0200 | B-1 `:140`/`:181` citations still exact |
| `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md` | `4d4a9a1` | 2026-07-27 18:50:03 +0200 | B-1's `:129–130` target unchanged since before the corrections were written; still FALSE |
| `docs/epistemic/GLOSSARY.md` | `7a0946a` | 2026-07-28 11:49:30 +0200 | "chainable" term; corroborates A-2/A-3 corrected statements |
| `artifacts/oracle-2x2.wzo` | (disk, 2026-07-27 18:49) | — | C-1 calibration artifact; exists |
| `artifacts/oracle-3x2.wzo` | (disk, 2026-07-27 18:50) | — | C-1 calibration artifact; exists |

**No engine file was modified**; this task held no file ownership. The cited
sources were read-only per the brief ("Do NOT edit … This is an audit; the
fixes are separate.").