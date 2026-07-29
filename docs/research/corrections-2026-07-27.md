# Corrections — statements committed to this repo that are wrong or imprecise

**Date:** 2026-07-27. An errata ledger, in the spirit of the "Falsifications
(dead-ends, recorded to not repeat)" sections of the epistemic trees: a
recorded falsification is cheaper than a repeated investigation.

Each entry: **what was claimed** (quoted, with its location) · **why it is
wrong** (the measurement) · **corrected statement** · **status** · **what to
change** (and who owns that file — this note's author owns only this file) ·
**remediation** (whether the change was applied in the repo, and at what
commit; added 2026-07-29 evidence-integrity sweep).

Evidence base for Group A and C: `bin/weizigo-chainability`
(source `src/chainability.zig`), run 2026-07-27, exhaustive on
2×2/3×2/3×3/4×3 and `--sample 37` on `data/oracle-4x4.checkpoint.wzo`
(657,566 positions, 1,313,248 slots). Full table in
`docs/research/ko-sensitive-chainability.md`.

---

## A-1 — wrong causal attribution: "the game's PSK history"

**Claimed** — commit `753584f` (2026-07-27 23:28) message, and
`regressions/README.md:21`:

> "but in the actual game — with PSK history from the capture/ko fight — `W A4`
> gave Black +16"

and in the commit message: "the fresh-start table said W wins 16, but with PSK
history from the capture/ko fight it gave B +16."

**Why it is wrong.** A depth-1 probe replaying both 4×4 regression games against
the artifact compared the best child value over all legal children with the best
over children surviving the game's *actual* positional-superko ban set
(Measurement 2, `docs/research/ko-sensitive-chainability.md`):

| game | plies | plies where a PSK ban fired | plies where a ban changed the best value |
|---|---|---|---|
| `4x4-black-win-after-ko` | 19 | 1 (ply 14) | **0** |
| `4x4-history-blunder`    | 19 | 1 (ply 14) | **0** |

Exactly one ban fired per game, at ply 14, and it was never the best move. At
the ply-16 collapse node specifically, **zero** bans were active. The
accumulated history of the game removed nothing White wanted to play.

**Corrected statement.** The game's accumulated history did not remove White's
winning move. The cause is that the table is **unchainable** in the ko-sensitive
region: `Session.choose` takes an extremum over children's *independent
fresh-start* values, which do not satisfy the history-free Bellman identity
there, so the comparison is not an evaluation.

**Nuance to preserve.** Ko/PSK *is* ultimately why the table is unchainable —
the bans live deep inside each slot's own fresh-start subtree, which is why
`V0(P)` and `V0(child)` are priced under mutually inconsistent premises. What is
false is only the local claim that the *game's* history removed a move at that
node.

**Status:** the original claim is **FALSE-AS-SCOPED** (these two games, this
artifact). The correction is **PROVEN** for these two games.

**What to change:** `regressions/README.md` (owned by another agent; the
Diagnosis section added 2026-07-27 already states the corrected version — the
bullet at line 21 still carries the old wording). The commit message is
immutable; this entry is its erratum.

**Remediation:** ✅ **APPLIED** by 2026-07-28 — `regressions/README.md` now
carries the corrected wording (verified 2026-07-28; `CLAIMS.md` §6-D17). The
stale line-21 citation is resolved.

## A-2 — category error: the blunder is not "C2 in action"

**Claimed** — commit `753584f` message and `regressions/README.md:24`:

> "**Epistemic status:** the blunder is the C2 falsification in action
> (fresh-start ≠ real-game; falsified at 3×2, see AGENTS.md foreclosures)."

**Why it is wrong.** C2 is scoped to the single-score region — "Single-score
(L==H) positions are history-independent" (`docs/status/leak-crisis.md:25`).
Every blundering node in these games carries the `KO_SENSITIVE` flag, i.e.
L < H, which is entirely **outside** C2's scope. C2 cannot be "in action" at a
node it does not talk about.

Moreover the sweep is **positive** for C2's region: zero minimax-identity
violations outside the flag at every size tested — 2×2, 3×2, 3×3, 4×3
exhaustive and 4×4 at 1:37 — and every violation carries the flag
(16/16, 72/72, 688/688, 6,092/6,092, 11,402/11,402).

**Corrected statement.** The applicable committed claim is **C4** ("Fresh-start
score == real-game score", FALSE for both regions; `leak-crisis.md:27`) as it
applies to the ko-sensitive region, plus the new unchainability finding
(`docs/research/ko-sensitive-chainability.md`, Measurement 1). C2 remains
falsified at 3×2 by T13, but that falsification is not what these games
exhibit.

**Status:** the original attribution is **FALSE-AS-SCOPED**. The
outside-the-flag chainability result is **PROVEN** at each size listed, on the
audited artifact.

**What to change:** `regressions/README.md` (another agent owns it).

**Remediation:** ✅ **APPLIED** — the corrected attribution (C4 + unchainability)
is stated in `CLAIMS.md`'s `4x4.A-2` row and in the corrections ledger itself.
`regressions/README.md` was updated as part of the same pass as A-1.

---

## A-3 — "fresh-start perfect" overstates what the player is

**Claimed** — commit `753584f` message and `regressions/README.md:26`:

> "The engine is *fresh-start perfect*, not *history perfect*, and logs
> `HISTORY-DIVERGED` honestly."

The same phrase is in the header comment of `src/gtp.zig:37`: "ko-fight play is
'fresh-start perfect', not 'history perfect'."

**Why it is wrong.** From the engine's own transcript,
`regressions/4x4-black-win-after-ko.txt:74`:

```
oracle: W -> D1  child-value=-16 stored-v0=-3 (HISTORY-DIVERGED) KO_SENSITIVE dtt=255
```

The node's own fresh-start value is **−3**. The player chose a child valued
**−16**. A player that were fresh-start-perfect at that node would achieve −3.
It did not, and the engine printed both numbers while doing so.

**Corrected statement.** The *table* is fresh-start-exact per slot (claim C1
level). The *player* is **not** fresh-start-perfect in the ko-sensitive region:
chaining per-slot fresh-start values is not itself a fresh-start strategy, since
each slot's value is conditioned on a different (empty-history) premise. Outside
the flag, where the table is chainable, the greedy player's choice is a
well-defined one-ply minimax.

**Status:** the original claim is **FALSE-AS-SCOPED** (4×4, ko-sensitive region;
single counter-example sufficient). The per-slot C1 statement is unaffected.

**What to change:** `regressions/README.md` (another agent owns it); the
`src/gtp.zig:37` header comment carries the same overstatement and should be
narrowed when the file next has a single writer.

**Remediation:** ✅ **PARTIALLY APPLIED** — `src/gtp.zig:42` now reads "the
player is neither history-perfect NOR fresh-start-perfect" (verified
2026-07-28; `CLAIMS.md` §6-D17). `regressions/README.md:72,81` carries the
correction. The old `src/gtp.zig:37` citation is stale (the text moved) but
was corrected. **Not verified as complete:** the `regressions/README.md`
change is recorded but not independently confirmed in this sweep.

---

## B-1 — ADR-0013: the GTP player does not share the finisher's machinery

**Claimed** — `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md:129-130`,
Consequences section:

> "The history-perfect genmove (GTP player) shares this machinery; it inherits
> the fix automatically once the finisher config is corrected."

**Why it is wrong.** Verified by reading the source on 2026-07-27:

- `Session.choose` (`src/gtp.zig:154-196`) enumerates empty points, builds each
  child with `R.pos_from_move`, filters positional-superko repeats with
  `s.seen`, and reads `s.v0(&child, -side)` — a **table lookup**
  (`src/gtp.zig:90-93`: index by colex, return `vb[i]` or `vw[i]`). There is no
  recursion, no alpha-beta, no call into `retro.zig`. The only other evaluation
  path, `v1_from_table` (`src/gtp.zig:121-132`), is one further ply of the same
  lookups.
- The player has no bracket tables to cut on even in principle: the WZO1 format
  (`src/artifact.zig:23-53`) is six frozen columns — `vb | vw | fb | fw | db |
  dw` — with `column_count = 6` in the header and payload length
  `HEADER_LEN + 6 * t` (`src/artifact.zig:140,181`). No `lo`/`hi` columns exist
  in the artifact, so no shipped player can read a bracket.

**Corrected statement.** The GTP player does **not** share the finisher's search
machinery and will **not** inherit any finisher fix. Correcting the finisher
config changes what a regenerated artifact contains; it does not change how
`src/gtp.zig` selects a move. Any soundness improvement to play-time behavior is
a separate change to the player (see the fork in
`docs/research/ko-sensitive-chainability.md`, "What a fix costs").

**Status:** the ADR sentence is **FALSE** as of the code at 2026-07-27.

**What to change:** nothing in ADR-0013 — ADRs are append-only in this project
(`docs/about-this-document.md`, "decisions/ — append-only history; never
rewritten"). A **superseding ADR or an explicit correction note** is needed to
retire that Consequences bullet. This entry is the interim record.

**Remediation:** ❌ **NOT APPLIED.** ADR-0013 is append-only; no superseding
ADR has been written as of 2026-07-29. The `GLOBAL.B-1` register row records
the falsification. The Consequences bullet at `0013:129-130` remains in the
ADR as a historical record of what was claimed.

---

## C-1 — a correction made mid-investigation: "bug" read where the answer was "definition"

**Claimed** (transiently, during the 2026-07-27 investigation; never committed
as a finding, recorded here because the failure mode is reusable): the
chainability violations in the committed 4×4 artifact were first read as the
ADR-0013 `ko_ref >= d` GHI bug resurfacing in the committed generation.

**Why it is wrong.** Calibration killed it. The same sweep was run on
`artifacts/oracle-2x2.wzo` and `artifacts/oracle-3x2.wzo` — the PROVEN,
Track-A-regenerated artifacts, which the suspected bug never touched — and they
produced violations of exactly the same character: **19.51%** and **19.05%**
misprice within the ko-sensitive region, zero violations outside it. A bug
present in the clean artifacts is not a bug.

**Corrected statement.** The violations are **definitional**, not a generation
error: a ko-sensitive slot stores an independent fresh-start solve, so it is
under no obligation to agree with its parent across a history-free edge. This
is the C2 falsification restated per slot.

**Status:** the transient reading was **FALSE**; the definitional reading is
**PROVEN** on the artifacts swept.

**Lesson worth keeping.** A self-consistency check with no *passing* calibration
case cannot distinguish "bug" from "definition" — every input looks guilty.
Always calibrate an auditor against a known-good artifact before quoting its
verdict. (Here the calibration also gave the auditor its scope: it judges only
the region outside the `KO_SENSITIVE` flag, where it does pass.)

**Remediation:** ✅ **APPLIED by construction.** This is a methodological
finding, not a source-code correction. The lesson ("self-consistency check
with no passing calibration case cannot distinguish bug from definition") is
now recorded as `GLOBAL.CALIB-LESSON` (PROVEN) in `CLAIMS.md` §2.9 and is
applied in the calibrations for EXP-3 and the #2 auditor.

---

Source finding for Group A and C: `docs/research/ko-sensitive-chainability.md`.
