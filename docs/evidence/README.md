# `docs/evidence/` — the durable evidence store

**Created:** 2026-07-28, by a triage-and-rescue sweep over git-ignored
`untracked/`.

## The rule

From `docs/epistemic/roadmap-2026-07-28.md` §4 **P1 — Evidence must be in git,
or the claim is not proven**:

> A claim may be marked **PROVEN** only if its **probe source and output** are
> committed under `docs/evidence/<claim-id>/`. `untracked/` is for drafts that
> nobody will ever cite. This is not bureaucracy — it is the difference between
> proven and remembered.

And the roadmap's definition of done for any task: the claim ID it closes, the
evidence committed here, the acceptance criterion met *or* an honest negative
result recorded, and `docs/epistemic/CLAIMS.md` updated.

## Why this directory exists

`untracked/` is git-ignored (`.gitignore:8`). On 2026-07-27 a cleanup bundle
(B44 S3) deleted 57 "folded-done" scratch files from it. Among them was the
primary evidence for the project's most load-bearing claims — `3x2.T13` (the C2
falsification the entire strategy rests on), `2x2.B1`/`3x2.B1`/`3x3.B1` (which
is what removed the re-converge check from `4x4.FP1` acceptance), the T07 audit
that rewrote the 4×4 epistemic tree, and B05 (the reframe scope). None of it was
ever in git; `git log --all --diff-filter=A` finds zero commits for any of those
paths, and there is no stash. It is gone.

`docs/research/arena-4x4-undef.md:10-18` already documents this exact failure
mode happening once and draws the right lesson — "prefer writing durable
findings to git `docs/research/` directly". This directory is that lesson made
structural.

**A claim whose evidence cannot be retrieved is not proven; it is remembered.**

**Update 2026-07-30 (T110/T119):** T13's probe source has been independently
re-implemented and committed here (`docs/evidence/T13/`). The committed engine
(`src/retro.zig`) was never lost — only the convenience driver was. A systematic
recoverability audit of every CONFIRMED LOST item is at
`docs/evidence/ADR0006-FALSIFY/recoverability-audit-2026-07-30.md`.
Three of the seven load-bearing losses are RECOVERABLE from committed code;
four are LOST (reasoning/discussion, not code).

## Scope of the 2026-07-28 sweep

This sweep **copied and recorded only**. Nothing in `untracked/` was modified or
deleted, and no lost experiment was re-derived or re-run (that is a separate,
larger decision — see `docs/epistemic/CLAIMS.md` §7).

Inventory of `untracked/` as of 2026-07-28: **33 top-level entries, 112 files.**

| class | top-level entries | files | disposition |
|---|---|---|---|
| EVIDENCE | 9 | 40 (10 loose + `sgf/`'s 30) | copied here |
| PROCESS | 20 | 68 | left in place, listed below |
| BULK (`.wzo`) | 4 | 4 (516.6 MB) | **not copied**; hashes recorded below |

No file over 1 MB was copied; the largest rescued file is
`arena-4x4-undef/4x4-postfix.txt` at 26 KB, and `docs/evidence/` totals 384 KB.

---

## Rescued items

| file (here) | what it evidences | claim ID(s) | original location |
|---|---|---|---|
| `arena-4x4-undef/B43-arena-undef.md` | The B43 arena UNDEF-guard fix and re-measure: **3.4% clean leak** (123/3600 games), max 32 pts, 1,170/3,600 (32.5%) games touched ≥1 UNDEF slot. Retracts B39's 45.3% / max 144 pts as a measurement artifact. | `4x4.B43`, `4x4.B43-DIV`, `4x4.B39`, `CODE.UNDEF` | `untracked/B43-arena-undef.md` |
| `arena-4x4-undef/3x3-prefix.txt` | Raw arena stdout, 3×3, **pre**-guard (calibration: 3×3 has no UNDEF slots) | `4x4.B43` (calibration) | `untracked/B43-baselines/3x3-prefix.txt` |
| `arena-4x4-undef/3x3-postfix.txt` | Raw arena stdout, 3×3, **post**-guard | `4x4.B43` (calibration) | `untracked/B43-baselines/3x3-postfix.txt` |
| `arena-4x4-undef/4x4-postfix.txt` | Raw arena stdout, 4×4, post-guard — the run the 3.4% figure is computed from; per-game `promise`/`final` (Black-positive) and full move sequences | `4x4.B43`, `4x4.B43-DIV` | `untracked/B43-baselines/4x4-postfix.txt` |
| `b1-least-fixpoint/b1-spec.md` | The **specification** of the `RETRO_B1_LOFIX` least-fixpoint probe (V0+V1 Bellman checks, the T02.1 `oppV0[child]` correction). **Method only — the results file is lost.** | `2x2.B1`, `3x2.B1`, `3x3.B1`, `GLOBAL.B1-MULTIFIX`, `GLOBAL.B1-AUDIT` | `untracked/b1-spec.md` |
| `c2-3x2/plan4x4-master.md` | The C2-probe design and the per-goban-size isolated-epistemic-tree principle | `3x2.T13` (design), `GLOBAL.C2`, `4x4.C2`, `4x4.C3` | `untracked/plan4x4-master.md` |
| `c2-3x2/B10-minimax.md` | 3×2 C2-divergence empirics (H1 supported, **H2 falsified** — divergence magnitude is *not* bounded by bracket width, H3 inconclusive, H4 falsified). **UNCITED** — see caveat below. | corroboration for `GLOBAL.C2` / `3x2.T13`; cites no claim yet | `untracked/B10-minimax.md` |
| `c2-katago-live-play/katago-match.py` + `.cfg` + `sgf/` (30 files) | Probe source and raw game records for the B22 weizigo-vs-KataGo live-play run. **UNCITED** — see caveat below. | none | `untracked/katago-match.{py,cfg}`, `untracked/sgf/` |
| `dispatch-registry/SUBAGENTS.md` | The dispatch registry: the **only surviving record** of the one-line results of T04/T09/T10/T11/**T12**/**T13**/T14.1/T15/T16, and the file `PROGRESS.md:239` points at for the UD-1/2/3 decisions | `GLOBAL.UD-1`, `GLOBAL.UD-2`, `GLOBAL.UD-3`, `GLOBAL.T14.1`; secondary record for `2x2.T12`, `3x2.T13` | `untracked/SUBAGENTS.md` |

Every rescued markdown file carries an inline provenance header (original path,
original mtime, rescue date, original sha256, claims supported, citing
document). Non-markdown files are byte-identical to the original; their
provenance is in the sibling `PROVENANCE.md`.

### Caveat: two rescued items are UNCITED

`c2-3x2/B10-minimax.md` and everything in `c2-katago-live-play/` are cited by
**no committed document**. By the classification rule they are PROCESS. They
were copied anyway, deliberately and against the letter of the rule, for one
reason: both are measurement records bearing on `GLOBAL.C2`, the claim whose own
evidence has already been destroyed once, and both would be swept next time.

They are **not evidence for any current claim** and must not be cited as such.
To promote either, someone must write a durable note that names a claim ID and
states an acceptance criterion. Until then they are raw material. If a reviewer
disagrees with rescuing them, deleting these two paths costs nothing.

---

## CONFIRMED LOST

Checked 2026-07-28. For every row: the file is absent from disk, and
`git log --all --diff-filter=A -- '*<name>*'` returns **zero** commits — these
were never in git at any point, so they are not recoverable from history, and
`git stash list` is empty. **Unrecoverable** is the correct word.

### Load-bearing (the seven)

| lost file | what cited it | durable summary in git? |
|---|---|---|
| `untracked/T13-minimax.md` | `docs/status/leak-crisis.md:25,108`; `docs/research/c2-falsification-3x2.md:4,134`; `docs/infra/model-perf.md:207` | **Yes — RECOVERED (T110, 2026-07-30).** `docs/research/c2-falsification-3x2.md` holds the method, the ban-set distribution, all 12 contradiction lines and the 0/540 fresh-start sanity result; the raw output is regenerated under `docs/evidence/T13/`. See the T13 note below. T128 triage §1: re-pointed. |
| `untracked/c2pilot_3x2.zig` (the C2-probe source) | `docs/research/c2-falsification-3x2.md:21,127,133` | **RECOVERED by re-implementation (T110):** `docs/evidence/T13/t13_probe.py`, `docs/evidence/T13/zig_t13_replay.zig` — strict supersets of the original. NOTE: this literal path is `weizigo-claimlint`'s known-bad C2 calibration fixture; its citation in `c2-falsification-3x2.md` is deliberately left in place (T128 trap flagged 2026-07-31). |
| `untracked/T12-minimax.md` (C2-pilot-2×2) | `docs/epistemic/boards/4x4/EPISTEMIC.md:287-288`; `docs/infra/model-perf.md:206` | **One line only** — "C2-pilot-2×2 PARTIAL/tautological, no non-root cycles" in the rescued `dispatch-registry/SUBAGENTS.md`, plus the `2x2.T12` row in `CLAIMS.md:159`. |
| `untracked/T02-minimax.md` (B1 least-fixpoint results) | `docs/status/leak-crisis.md:103,180` | **RECOVERABLE** — method survives at `b1-least-fixpoint/b1-spec.md`; numbers at `leak-crisis.md:86-101` need regeneration. T128 triage §3. |
| `untracked/T02-audit-kimi.md` (the Kimi audit convicting the (a′) variation) | `docs/status/leak-crisis.md:104,180` | **LOST** — two-line paraphrase at `leak-crisis.md:99-101` and `CLAIMS.md:132` (`GLOBAL.B1-AUDIT`). Decision survives; audit reasoning does not. T128 triage §4. |
| `untracked/T07-audit-hypotheses.md` (~42 KB, the eight findings that rewrote the 4×4 tree) | `docs/epistemic/boards/4x4/EPISTEMIC.md:13`; `docs/infra/model-perf.md:118` | **LOST** — product is `4x4/EPISTEMIC.md` (the rewritten tree); the eight itemised findings are gone. T128 triage §5. |
| `untracked/B05-glm.md` (the reframe scope) | `docs/epistemic/PROGRESS.md:277`; `docs/status/leak-crisis.md:146,151`; `docs/epistemic/boards/4x4/EPISTEMIC.md:330`; `docs/epistemic/boards/CONCEPTS.md:104` | **LOST** (durable summary exists) — decision fully documented at `GLOBAL.REFRAME` and `leak-crisis.md:146`. The discussion that shaped it is gone. T128 triage §6. |

**T13, specifically.** Its numbers survive at `docs/research/c2-falsification-3x2.md`,
and the probe was independently re-implemented 2026-07-30 (T110) in both Python
(`docs/evidence/T13/t13_probe.py`) and Zig (`docs/evidence/T13/zig_t13_replay.zig`)
against the committed `src/retro.zig`. All 12 recorded contradiction lines
re-execute exactly; all census numbers match. The original probe source
`untracked/c2pilot_3x2.zig` was deleted in the B44 sweep, but the committed
engine (`retro.ab_solve`, the L/H tables, the move/capture/suicide kernel) was
never lost — only the driver was. The original reproduction block at
`c2-falsification-3x2.md:138-141` is kept as a historical record of the lost
command; the T110 re-implementations at `docs/evidence/T13/` are the current
re-executable probes (T128 triage, 2026-07-31).

### Also cited-but-missing (found during this sweep)

| lost file | what cited it | durable summary in git? |
|---|---|---|
| `untracked/B09-kimi.md` | `docs/research/auditor-sensitivity.md:3` (**Source:**) | Yes — `auditor-sensitivity.md` is the promoted finding (`GLOBAL.AUDITOR` blindness to L/H construction bugs). |
| `untracked/B23-kocensus.md` | `docs/research/ko-census.md:3` (**Source:**) | Yes — `ko-census.md` (65/33/2/0.0025% multi-ko frequency, `innovations.md` I8). |
| `untracked/B39-arena4x4.md` | `docs/research/arena-4x4-undef.md:11-14`, which records its own deletion by B44 | Yes — `arena-4x4-undef.md:27-44` (`4x4.B39`, now retracted). |
| `untracked/c2pilot_2x2.zig` (T12 probe source) | `docs/infra/model-perf.md:320` | **No.** **Recoverable** — the committed engine (`src/retro.zig`) + parameterisation to 2×2 suffices; same primitives as T13, simpler goban. See `docs/evidence/ADR0006-FALSIFY/recoverability-audit-2026-07-30.md`. |
| `untracked/T15-kimi.md` (capture-all design), `untracked/T15-review-kimi.md` (defer verdict) | `docs/infra/model-perf.md:272`; `untracked/T15-impl-minimax.md` | **No.** T15 was deferred, so nothing depends on them today. |
| `untracked/T16-glm.md` | `docs/infra/model-perf.md:207` | Product only — the EPISTEMIC/CONCEPTS rewrite itself. |
| `untracked/delegation-prompts-2026-07-26.md` | `docs/infra/model-perf.md:236,305` | **No.** Process only. |
| `untracked/B01`–`B14` bundles (all except `B10-minimax.md`) | `docs/infra/delegation.md:14-27`; `docs/infra/agents/boss-role.md:267,271` | Process dispatch citations. B05 and B09 are the evidence-bearing members and are listed above. |
| B29 / B30 / B31 / B32 bundles (cited by ID, not path) | `docs/epistemic/innovations.md:15-22` — the sources for **I1** (single-ko formula), **I2** (writes-off parallel finisher), **I3** (ko decomposition), **I7** (99.5% sign-crossing) | Summary rows only in `innovations.md`. The underlying runs are gone; `I1` in particular is "tested, not proven" with the test now unretrievable. |
| `untracked/discussion.md`, `untracked/idea-heap.md` | `AGENTS.md:170-171` | Partly — 2026-07-25 snapshots survive at `untracked/archive/`, **still git-ignored**. Classified PROCESS, not rescued. |
| `untracked/model-perf.md` | `docs/infra/agents/boss-role.md:212` | **Not lost** — B44 S2 promoted it verbatim to `docs/infra/model-perf.md` (32,565 B). Listed here only because the old path is still cited. |
| `untracked/task-minimax.md` | `b1-least-fixpoint/b1-spec.md:4` (the rescued file's own header) | **No.** Process. |

Two dangling pointers that are not files:

- `docs/epistemic/boards/CONCEPTS.md:77` — "Task outputs in `untracked/` for the
  exact evidence at each size" now points at a mostly-empty directory.
- `docs/infra/model-perf.md:165` cites `untracked/T99-tripleko.md`, but that is
  an *example* dispatch prompt, not a real file. Not lost; never existed.

---

## Artifacts not committed (BULK)

`.wzo` artifacts were **not** copied — they are large and `data/` is git-ignored
(`.gitignore:4`). Recorded here so the bytes behind published numbers can be
identified if the files still exist on someone's disk. All four are in
`untracked/`, git-ignored, and one cleanup sweep away from gone.

| file | mtime | bytes | sha256 |
|---|---|---|---|
| `untracked/oracle-4x4-writesoff-bracket.wzo` | 2026-07-26T04:08:26 | 258,280,358 | `73b9c27e97eb27e2f197eaaf3ec46f8a50f06caa6025c4ab399b8c5898f92232` |
| `untracked/oracle-4x4-writesoff-checkpoint.wzo` | 2026-07-27T11:31:26 | 258,280,358 | `28afa11bf095554ed313a400a3a5eb871cc49c4bfdefe07e1f2e8f3037f3fc4a` |
| `untracked/oracle-3x2-regen.wzo` | 2026-07-26T21:06:51 | 4,406 | `d4d22c0d9f1d771bfcb1d99fc43a4f19f652205113ff599123b189097b3bb523` |
| `untracked/oracle-2x2-regen.wzo` | 2026-07-26T21:06:51 | 518 | `1ed06e648561995005a16489dcf6c4205c5aa11f427da81cceca40d3cab62abf` |

Notes:

- The **bracket** artifact is the `GLOBAL.T14.1` output.
  `docs/infra/model-perf.md:253-254` says its "sha256 [was] recorded" — the hash
  itself appears nowhere in git. The row above is the first durable record of it.
- The **checkpoint** artifact is what `4x4/EPISTEMIC.md:123,219,250,293` and
  `docs/research/ko-sensitive-chainability.md:170-183,395-407` measure. Both
  documents already flag it as uncommitted.
- The two `*-regen.wzo` files are tiny (518 B and 4.4 KB) and are cited by
  nothing. They are small enough to commit if anyone wants a durable 2×2/3×2
  reference artifact; that is a decision for the artifact owner, not this sweep.

---

## PROCESS — left in `untracked/`, deliberately

Historically interesting, not evidence. Left in place; they will be lost at the
next cleanup and that is acceptable.

Task bundles and agent scratch: `B25-finisher.md`, `B34-innovations-audit.md`,
`B35-proof-I1.md`, `B36-priorities.md`, `B38-claims.md`, `B40-undef.md`,
`B41-consolidate.md`, `B42-score-report.md`, `B44-cleanup.md`,
`B45-doc-hygiene.md`, `T14-minimax.md`, `T15-impl-minimax.md`,
`T17-impl-glm.md`, `doc-hygiene.md`, `heap.md`, `managent/tasks.json{,.bak-*}`,
`archive/{discussion,idea-heap,relay}-2026-07-25.md`.

Superseded by a committed copy: `epistemic-tree-4x4.md` — the durable version is
`docs/epistemic/boards/4x4/EPISTEMIC.md`. Not copied.

Third-party / uncited outputs: `katago-logs/` (13 files, 312 KB — KataGo's own
search logs, not weizigo measurements), `regressions/` (35 `.reg` files, ~270 KB
— cited by nothing; note this is **not** the repo-root `regressions/` directory
that `docs/research/ko-sensitive-chainability.md:10-11` and
`open-hypotheses-2026-07-27.md:192-193` cite, which is a different, separately
owned tree).

One PROCESS file is worth reading before it goes: `untracked/B41-consolidate.md`
maps sprint bundles B15–B40 to the `docs/` files their findings were promoted
to. It is the provenance index for several committed research notes, and it is
git-ignored.

---

## How to add evidence

1. **Name the claim first.** Find or create the claim ID in
   `docs/epistemic/CLAIMS.md`. If your experiment does not close a claim, it is
   not evidence — put it in `untracked/`.
2. **Make a directory:** `docs/evidence/<claim-id>/`, lowercased
   (e.g. `docs/evidence/3x2.t13/`). Topic-named directories exist here for
   rescued material that predates the rule; new work uses claim IDs.
3. **Commit the probe source.** The actual `.zig`/`.py`/shell file that produced
   the number, not a description of it. This is the part that was lost in every
   case above.
4. **Commit the raw output**, unedited, exactly as the run emitted it. Include
   the command line, goban size, flags, artifact path and artifact sha256.
5. **Commit a `PROVENANCE.md`** naming: the claim ID(s), the acceptance
   criterion, the date, the run command, and — per P3 — the checker's
   **calibration case**: one known-good input it passes and one known-bad input
   it catches.
6. **Ship a calibration case with every checker.** An auditor with no passing
   case cannot distinguish "bug" from "definition"
   (`GLOBAL.CALIB-LESSON`, `docs/research/corrections-2026-07-27.md:197-201`).
7. **Then** update `CLAIMS.md`, citing `docs/evidence/<claim-id>/` in the
   evidence column, and cite the claim ID in the commit message.
8. **Never** point a committed document at a path under `untracked/`. That is
   the mechanism that produced this file.

Conventions used here, kept for consistency: rescued markdown carries an inline
provenance header and the body stays verbatim; non-markdown stays byte-identical
with provenance in a sibling `PROVENANCE.md`; scores are Black-positive; dates
are absolute; numbers cite their run.

`.gitignore` ends with an explicit `!docs/evidence/` + `!docs/evidence/**`
negation, placed last so no earlier rule can ever reach this tree. Do not move
it.
