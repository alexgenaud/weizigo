# EXP-14 — cross-check of `docs/research/corrections-2026-07-27.md` at `eebe3c2`

**Task / worker / model:** EXP-14, executed by a console session.
**Model: GLM-5.2** (stated at dispatch).

**Date:** 2026-07-28. **Audit "now":** commit `eebe3c2`
(2026-07-29 01:02:55 +0200), named by the brief. Working-tree HEAD at run
time is `4fca047` (later); all source reads below use `git show eebe3c2:<path>`
so the verdicts are pinned to the audit commit, not to HEAD.

**KIND:** ANALYSIS, no `holds`. Reads only. Writes this file + a sibling
`PROVENANCE.md`. No cited source was edited.

**Subject:** the five corrections in
`docs/research/corrections-2026-07-27.md` (added in commit `7c71fe5`,
2026-07-28 11:49:30 +0200; the doc is internally dated 2026-07-27 and was
written during the 2026-07-27 evening chainability session). For each, the
question per the brief: *is the correction's claim that the cited source is
wrong actually true at `eebe3c2`?* — verified / stale / wrong / partial.

**The one commit that matters.** Between the corrections' write date
(2026-07-27) and the audit "now" (`eebe3c2`, 2026-07-29), exactly one commit
touched any cited source: **`7a0946a`** (2026-07-28 11:49:30 +0200, "docs: 4x3
epistemic tree, … regressions-README updates, gtp.zig comment scope"). It
rewrote `regressions/README.md` and the `HONESTY` header comment of
`src/gtp.zig`, folding the A-corrections' corrected statements into the files
themselves. It does **not** touch the ADR, the artifact format, the
chainability research note, or the regression transcript. So `7a0946a` is the
sole "fixes since" commit for this audit.

---

## Per-correction table

| correction-id | file:line in corrections | source file:line (cited) | what the correction says | what the source actually says at `eebe3c2` | verdict | remediation |
|---|---|---|---|---|---|---|
| **A-1** | `corrections-2026-07-27.md:19–64` | commit `753584f` message (immutable) + `regressions/README.md:21` | The "PSK history from the capture/ko fight gave B +16" causal claim is wrong; the game's accumulated history removed no move White wanted (1 ban fired, at ply 14, never best; 0 of 19 plies changed by a ban). | **Commit `753584f` message** still reads "with PSK history from the capture/ko fight it gave B +16" (immutable, exactly as quoted). **`regressions/README.md` at `eebe3c2`** no longer carries the phrase — `7a0946a` replaced it with "The game's accumulated history did not remove White's winning move" + "Ko/PSK *is* ultimately why the region is unchainable … What is false is the narrower claim that the *game's* history removed a move at that node." The corrected statement is now in the file. Measurement 2 of `docs/research/ko-sensitive-chainability.md:202–206` confirms 1 ban/game at ply 14, 0 changed-best, PROVEN. | **PARTIAL** | Commit-message erratum **stands** (verified — the commit is immutable, this entry is its permanent erratum). The `regressions/README.md:21` target is **stale** — fixed by `7a0946a`. The correction could be narrowed to point only at the commit message. |
| **A-2** | `corrections-2026-07-27.md:66–97` | commit `753584f` message (immutable) + `regressions/README.md:24` | "The blunder is the C2 falsification in action" is a category error: C2 is scoped to the L==H region; every blundering node is `KO_SENSITIVE` (L<H), outside C2's scope. The applicable claim is C4 + unchainability. | **Commit `753584f` message** still reads "The blunder itself is the C2 falsification in action" (immutable, verbatim). **`regressions/README.md` at `eebe3c2`** now reads "The applicable claim is **C4** (fresh-start ≠ real-game on ko-sensitive positions), plus the unchainability finding above — **not** C2." — the corrected statement. `GLOSSARY.md:170–178` and `ko-sensitive-chainability.md` confirm 0 violations outside the flag at every size, violations exactly co-extensive with the flag. | **PARTIAL** | Commit-message erratum **stands** (verified). The `regressions/README.md:24` target is **stale** — fixed by `7a0946a`. |
| **A-3** | `corrections-2026-07-27.md:99–134` | commit `753584f` message (immutable) + `regressions/README.md:26` + `src/gtp.zig:37` header comment | "The engine is *fresh-start perfect*" overstates: the player chose a child valued −16 at a node whose own fresh-start value is −3 (`4x4-black-win-after-ko.txt:74`), so the player is not fresh-start-perfect in the ko-sensitive region. | **Commit `753584f` message** still reads "the engine is fresh-start-perfect, not history-perfect" (immutable). **`regressions/README.md` at `eebe3c2`** now reads "The *player* is **not** fresh-start-perfect in the ko-sensitive region". **`src/gtp.zig` at `eebe3c2`** has a fully rewritten `HONESTY` block (now lines 28–49): "the player is neither history-perfect NOR fresh-start-perfect" — the old `:37` phrase "fresh-start perfect, not history perfect" is gone. The cited transcript line is still present and exact: `regressions/4x4-black-win-after-ko.txt:74` = `oracle: W -> D1  child-value=-16 stored-v0=-3 (HISTORY-DIVERGED) KO_SENSITIVE dtt=255`. | **PARTIAL** | Commit-message erratum **stands** (verified). Both file targets (`regressions/README.md:26`, `src/gtp.zig:37`) are **stale** — fixed by `7a0946a`. The transcript evidence is verified (still present, supports the corrected statement). |
| **B-1** | `corrections-2026-07-27.md:136–173` | `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md:129–130` (+ `src/gtp.zig:154-196`, `:90-93`, `:121-132`; `src/artifact.zig:23-53`, `:140`, `:181`) | The ADR Consequences bullet "The history-perfect genmove (GTP player) shares this machinery; it inherits the fix automatically" is FALSE: `Session.choose` is a one-ply table-lookup extremum (no recursion, no retro.zig), and the WZO1 artifact has six columns `vb\|vw\|fb\|fw\|db\|dw` with no `lo`/`hi` bracket, so no shipped player can read a bracket. | **ADR-0013 at `eebe3c2`** unchanged since `4d4a9a1` (2026-07-27 18:50, before the corrections were written). Lines 129–130 still read exactly "The history-perfect genmove (GTP player) shares this machinery; it inherits / the fix automatically once the finisher config is corrected." — the claim is still FALSE. Substantive code check at `eebe3c2`: `src/gtp.zig:54–58` imports `std, rules, colex, artifact, score` — **no `retro.zig`**; `choose` enumerates empties, builds children via `R.pos_from_move`, filters PSK via `s.seen`, reads `s.v0(&child, -side)` (a colex-indexed `vb[i]`/`vw[i]` lookup); no recursion, no alpha-beta. `src/artifact.zig:23–53` is the six-column schema; `column_count = 6` in the header; payload `HEADER_LEN + 6 * t` at `:140` (encode) and `:181` (decode). All confirmed. **Caveat (line-number drift, not substance):** `7a0946a`'s comment-only rewrite of `src/gtp.zig` shifted the cited line numbers — `choose` is now at `:184` (was `:154-196`), `v0` at `:102` (was `:90-93`), `v1_from_table` at `:137` (was `:121-132`). The code is unchanged in substance; only the line citations moved. `src/artifact.zig:140`/`:181` are unchanged (artifact.zig last touched `58a4dac`, pre-corrections). | **VERIFIED** | None. The ADR is append-only (`docs/about-this-document.md`); a superseding ADR or explicit correction note is still needed to retire the bullet, exactly as the correction says. The correction's `src/gtp.zig` line numbers are now stale pointers but the cited code is still there at new lines — not a defect of the correction's claim. |
| **C-1** | `corrections-2026-07-27.md:175–end` | `artifacts/oracle-2x2.wzo`, `artifacts/oracle-3x2.wzo` (calibration artifacts) + `docs/research/ko-sensitive-chainability.md` | The chainability violations in the committed 4×4 artifact were first (transiently) misread as the ADR-0013 `ko_ref >= d` GHI bug resurfacing. Calibration killed that: the same sweep on the PROVEN Track-A 2×2/3×2 artifacts produced violations of the same character (19.51% / 19.05% misprice within ko-sensitive, 0 outside). A bug present in the clean artifacts is not a bug — the violations are definitional. | Both calibration artifacts exist on disk (`artifacts/oracle-2x2.wzo`, `artifacts/oracle-3x2.wzo`; `ls` confirms, both dated 2026-07-27 18:49–18:50). `docs/research/ko-sensitive-chainability.md` at `eebe3c2` Measurement 1 table records exactly: 2×2 77.36% ko-sensitive / **19.51%** misprice within / max\|Δ\|=2 / **0** outside; 3×2 41.18% / **19.05%** / 12 / **0** — matching the correction's numbers verbatim. (Note: the 4×4 share in that table is now the **exhaustive** 21.33%, updated 2026-07-28; the corrections doc's preamble still carries the superseded 1:37-sample figure "21.27%" / "657,566 positions, 1,313,248 slots". That preamble staleness is a property of the corrections doc itself, not of the C-1 claim, which is about 2×2/3×2 and is unaffected.) | **VERIFIED** | None. This is a self-contained "lesson worth keeping" with no repo source flagged as wrong; its calibration claim holds at `eebe3c2`. |

---

## Counts

| verdict | count | corrections |
|---|---|---|
| **verified** | 2 | B-1, C-1 |
| **partial** | 3 | A-1, A-2, A-3 (each: commit-message erratum verified, file-line target stale) |
| **stale** (standalone) | 0 | — |
| **wrong** | 0 | — |
| **total** | 5 | — |

The three PARTIAL verdicts each carry one **stale sub-part** (the `regressions/README.md` /
`src/gtp.zig` file target, fixed by `7a0946a`) and one **verified sub-part** (the
immutable commit-message erratum, which remains the permanent record of the
`753584f` message's wrong claims). No correction is *wrong* — none misread its
source; every quoted string matches the source verbatim at the cited commit.

---

## Calibration (mandatory, per brief)

The brief requires hand-verification of at least three of the corrections the
doc's preamble frames as "recorded to not repeat / not re-derive". Three were
re-derived from primary sources, not from the correction's own wording:

1. **A-1 — re-derived Measurement 2.** Read
   `docs/research/ko-sensitive-chainability.md:195–210` at `eebe3c2`: the
   per-game ban table is `19 plies / 1 ban fired (ply 14) / 0 changed-best` for
   *both* games, PROVEN. This is exactly A-1's "Why it is wrong" — the game's
   history removed no move White wanted. The ply-16 collapse node has zero
   active bans (the only ban is at ply 14). The correction's analysis is sound;
   only its `regressions/README.md:21` *target* has been superseded by `7a0946a`.

2. **B-1 — re-derived from the source code.** Read `src/gtp.zig` (imports
   `:54–58`; `v0` `:102–106`; `v1_from_table` `:137–152`; `choose` `:184–226`)
   and `src/artifact.zig` (schema `:23–53`; `column_count = 6`; payload
   `HEADER_LEN + 6 * t` at `:140` and `:181`) at `eebe3c2`. No `retro.zig` import;
   `choose` is a one-ply table-lookup extremum over PSK-legal children with a
   pass fallback through `v1_from_table`; no recursion; no bracket columns in
   the format. The ADR-0013 `:129–130` sentence is still present and still
   false. B-1's claim holds in full. (This is the same question EXP-16 / Kimi-k3
   answered for `Session.choose` in
   `docs/evidence/GLOBAL.SESSION-CHOOSE/audit-2026-07-28.md`, verdict VERIFIED —
   independent corroboration.)

3. **C-1 — re-derived the calibration.** Confirmed both calibration artifacts
   exist (`artifacts/oracle-2x2.wzo`, `artifacts/oracle-3x2.wzo`) and that
   `ko-sensitive-chainability.md` Measurement 1 records 19.51% / 19.05%
   misprice-within-ko-sensitive and 0 violations outside on exactly those
   PROVEN Track-A artifacts. The "bug" reading was correctly killed by its own
   calibration; the definitional reading stands.

The sweep found non-trivial staleness (three file-line targets fixed by
`7a0946a`) and one line-number drift (B-1's `src/gtp.zig` pointers), so this is
not a zero-finding audit.

---

## Fixes since 2026-07-27

Corrections (or sub-parts) that became stale because a later commit fixed the
source:

| correction | stale target | fixing commit | fixing commit date | what the fix did |
|---|---|---|---|---|
| A-1 | `regressions/README.md:21` ("PSK history from the capture/ko fight gave B +16") | `7a0946a` | 2026-07-28 11:49:30 +0200 | Rewrote the fixture's "Why White lost" section: "The game's accumulated history did not remove White's winning move"; attributed the cause to unchainability, not the game's PSK history. |
| A-2 | `regressions/README.md:24` ("the blunder is the C2 falsification in action") | `7a0946a` | 2026-07-28 11:49:30 +0200 | New "Epistemic status" subsection: "The applicable claim is **C4** … — **not** C2." |
| A-3 | `regressions/README.md:26` ("The engine is *fresh-start perfect*, not *history perfect*") | `7a0946a` | 2026-07-28 11:49:30 +0200 | Replaced with "The *player* is **not** fresh-start-perfect in the ko-sensitive region" + the `4x4-black-win-after-ko.txt:74` counter-example. |
| A-3 | `src/gtp.zig:37` header comment ("ko-fight play is 'fresh-start perfect', not 'history perfect'") | `7a0946a` | 2026-07-28 11:49:30 +0200 | Comments-only rewrite of the `HONESTY` block (now `:28–49`): "the player is neither history-perfect NOR fresh-start-perfect" in the ko-sensitive region; added `v1_from_table`/`choose` scope caveats. **No behaviour change** (commit message: "57/57 tests pass"). |

`7a0946a` is the only commit between the corrections' write date and `eebe3c2`
that touches any cited source. The ADR (last `4d4a9a1`, 2026-07-27 18:50,
pre-corrections), `src/artifact.zig` (last `58a4dac`, pre-corrections), the
chainability research note (last `7c71fe5`, the corrections' own commit), and
the regression transcript (last `753584f`) were all untouched in the window.

**Not fixed (and the correction's erratum therefore still stands):** the
`753584f` **commit message**, quoted verbatim by A-1, A-2, and A-3. Commit
messages are immutable in this project; the corrections doc itself says so
("The commit message is immutable; this entry is its erratum"). Those three
errata remain the permanent record of the commit's wrong claims.

---

## Wrong corrections

**None.** No correction misreads its source. Every quoted string was checked
against the cited commit and matches verbatim:

- A-1's `regressions/README.md:21` quote matches the file at `753584f` exactly;
  its Measurement-2 numbers match `ko-sensitive-chainability.md:202–206`.
- A-2's `regressions/README.md:24` quote matches `753584f` exactly; its C2-scope
  claim matches `docs/status/leak-crisis.md` and the GLOSSARY's chainable
  definition.
- A-3's `src/gtp.zig:37` quote matches `753584f` exactly; its transcript quote
  matches `regressions/4x4-black-win-after-ko.txt:74` exactly (still present at
  `eebe3c2`).
- B-1's ADR quote matches `eebe3c2:docs/decisions/0013-…:129–130` exactly; its
  code claims match the source at `eebe3c2`.
- C-1's calibration numbers match `ko-sensitive-chainability.md` Measurement 1
  exactly, and both cited artifacts exist on disk.

There is no correction whose claim is "not supported by the source."

---

## Partial corrections

Three corrections are half-right by target, not by analysis — the analysis is
sound in all three, but one of the two cited sources has been fixed since:

- **A-1 — PARTIAL.** *Verified half:* the `753584f` commit-message erratum
  stands (immutable; the "PSK history gave B +16" causal claim is still in the
  commit message, still wrong, and Measurement 2 still proves it wrong).
  *Stale half:* `regressions/README.md:21` no longer carries the wrong claim —
  `7a0946a` replaced it with the corrected statement. The correction's
  `regressions/README.md` target is moot; only the commit-message target
  remains.

- **A-2 — PARTIAL.** *Verified half:* the `753584f` commit-message erratum
  stands (the "C2 falsification in action" attribution is still in the commit
  message, still a category error — the sweep's outside-the-flag result is
  positive at every size, GLOSSARY-confirmed). *Stale half:*
  `regressions/README.md:24` was replaced by `7a0946a` with the corrected
  "C4, not C2" framing.

- **A-3 — PARTIAL.** *Verified half:* the `753584f` commit-message erratum
  stands, and the transcript counter-example
  (`4x4-black-win-after-ko.txt:74`, `child-value=-16 stored-v0=-3`) is still
  present at `eebe3c2` and still proves the player is not fresh-start-perfect in
  the ko-sensitive region. *Stale half:* both file targets —
  `regressions/README.md:26` and the `src/gtp.zig:37` header comment — were
  rewritten by `7a0946a` to state the corrected version.

In all three, the **verified half** is the immutable commit-message erratum and
the **stale half** is the file-line target fixed by `7a0946a`. The corrections
doc could be narrowed (not retracted) to point only at the commit messages.

---

## Two most consequential corrections (plain prose)

1. **B-1 is the most consequential.** It bears on the division of labour between
   Track A (regenerate the artifact with a corrected finisher config) and the
   separate play-time fix (EXP-9 / H5a). ADR-0013's Consequences bullet says the
   GTP player "shares this machinery; it inherits the fix automatically once the
   finisher config is corrected." B-1 shows that is false: `Session.choose` is a
   one-ply table-lookup extremum with no recursion into `retro.zig`, and the
   WZO1 artifact ships six columns with no `lo`/`hi` bracket — so no shipped
   player can read a bracket even in principle. If B-1 were wrong, readers
   would believe the finisher correction *alone* fixes play-time ko behaviour
   and would stop scheduling the separate player work; the ko-fight losses
   would persist silently after Track A completes. The bullet sits in an ADR
   (the highest-authority doc class in this repo) and is the only one of the
   five corrections whose source is **still wrong at `eebe3c2`** — it is the
   one that still needs acting on (a superseding ADR or explicit correction
   note, per the project's append-only rule).

2. **A-2 is the second most consequential.** It guards the epistemic framing of
   the 4×4 regression games. The regression is the most-cited example in the
   chainability finding, and "the blunder is the C2 falsification in action" is
   the misframing a casual reader would walk away with. If A-2 were wrong, the
   regression would be (mis)read as evidence that the single-score L==H region
   is unsound in real games — but A-2's substance is that the blundering nodes
   are all `KO_SENSITIVE` (L<H), entirely *outside* C2's scope, and the sweep is
   *positive* news for C2's region (0 violations outside the flag at every size,
   violations exactly co-extensive with the flag). The wrong framing would
   undermine the auditor's calibration anchor (the outside-the-flag clean
   region) and mislead anyone quoting the regression as a C2 demonstration. The
   commit message still carries the wrong framing; the README no longer does
   (fixed by `7a0946a`).

## One correction that should be retracted

**None should be retracted.** No correction is wrong (none misread its source)
and none is fully stale (every correction still has at least one verified
target — for A-1/A-2/A-3 the immutable commit-message erratum; for B-1 the
still-wrong ADR bullet; for C-1 the calibration that still holds). The right
action on the three PARTIAL corrections is to **annotate** them — narrowing the
cited source list to the commit message (and dropping the now-fixed
`regressions/README.md` / `src/gtp.zig` line targets) — not to retract them.

---

## Side observations (not corrections, not verdicts)

- **The corrections doc's own preamble is now partly stale.** It cites
  `--sample 37 on data/oracle-4x4.checkpoint.wzo (657,566 positions, 1,313,248
  slots)` and the README at `eebe3c2` carries the matching "21.27%" figure. The
  chainability research note was updated to the **exhaustive** 4×4 run on
  2026-07-28 (21.33%, 48,599,962 non-settled slots checked), superseding the
  1:37 sample. This does not affect any of the five corrections (C-1 is about
  2×2/3×2; A-1/A-2/A-3 are about causal/epistemic attribution, not the 4×4
  percentage), but anyone quoting the corrections doc's preamble numbers
  should pull the exhaustive figure from `ko-sensitive-chainability.md`
  instead.
- **B-1's `src/gtp.zig` line numbers are now stale pointers** (shifted by
  `7a0946a`'s comment-only rewrite: `choose` `:154-196`→`:184`, `v0`
  `:90-93`→`:102`, `v1_from_table` `:121-132`→`:137`). The cited code is
  unchanged in substance; `src/artifact.zig:140`/`:181` are unchanged. This is
  a citation-drift caveat on an otherwise-verified correction, not a defect of
  the claim.