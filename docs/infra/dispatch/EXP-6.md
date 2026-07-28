# EXP-6 — 4×4 under the new rule: +2, and a root that can say so

**Closes:** the 4×4 result under the new rule; answers the complaint behind
`QA-016`; corroborates `QA-026` at 4×4. **Blocks:** EXP-7 and EXP-8 (EXP-8's
*harness* can be built before this lands — see EXP-8). **Blocked by: EXP-5**
(itself blocked by EXP-4, itself blocked by EXP-2). **Informed by EXP-3** — read
its addressing numbers before you allocate anything.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`docs/epistemic/roadmap-2026-07-28.md` §3 (EXP-6) and §4 **P4**, then
`docs/infra/dispatch/EXP-5.md` and its output, then EXP-3's census
(`docs/research/kostate-census-2026-07-28.md`), then
`docs/research/ruleset-options.md` §RETRO_BRACKET and
`docs/research/retrograde-4x4.md` — the near-misses.

This is the long run. Retrograde builds at 4×4 are minutes to hours and produce
258 MB-scale artifacts. **Start it in a persistent session, watch the
heartbeat, do not restart** (README, "Long runs need a persistent session").

---

## The question

Under the rule EXP-2 pinned down and EXP-4/EXP-5 validated — area scoring,
komi 0, basic ko, fixed-value long-cycle verdict — what is the value of the
empty 4×4 board?

## Acceptance criterion — both halves, no substitutes

**1. The value is +2** (Black, empty board, central first move), matching van
der Werf & Winands (`retrograde-3x3.md:224-245`; `QA-025`).

**2. The root is FILLED.** `vb[empty] ≠ -128`. Read the byte and print it.

Not a formality. `roadmap-2026-07-28.md:231-232`: *two of the three current 4×4
artifacts cannot state the 4×4 answer.* `QA-016` records the verified instance —
`data/oracle-4x4-parallel.checkpoint.wzo` has `vb[empty] = -128` (UNDEF) by byte
inspection, and was nonetheless reported as **"99.8% complete"** (`CLAIMS.md`
`4x4.PARALLEL`: 99.8% filled, 83K UNDEF slots, mostly 2-ko+). **Verify the
three-artifact claim yourself by byte inspection rather than repeating it** —
then make sure your own artifact is not the fourth.

> **"Percentage complete" is not an acceptance criterion.** The deliverable
> line is exactly three answers: **root filled? anchor matched? gate passed?**
> (roadmap §4 **P4**.) If you catch yourself writing "99.x%", you have written
> the metric that hid `QA-016`.

Also required, all reported explicitly:

- **The full gate chain re-run from the binary that produced the 4×4 table:**
  2×2 = 0, 3×2 = 0 (EXP-4's falsifier — the only check in the chain that can
  catch a silent drift back to PSK), 3×3 = +9 (EXP-5). Paste the output.
- **Zero UNDEF on any legal slot**, not just the root. Exhaustive count.
- **Colour-inversion symmetry**, exhaustive: `value(-pos,-side) ==
  -value(pos,side)` (`AGENTS.md`).
- **Tie census.** 4×4 has 16 points, so with komi 0 the area score is **even**
  and a tie value of 0 collides with a genuine score of 0 — the opposite of the
  3×3 situation. **Report the tie count as a distinct symbol, not as a 0**, and
  state whether the root is a tie. If the root is a tie, the answer is not +2.
- **An honest cost report:** wall time, peak RSS, artifact bytes, sweeps to
  convergence, addressing scheme used, and how it compares to EXP-3's predicted
  size.

## Prior attempts this must distinguish itself from

Four. All produced a "+2" or a "4×4 solved" of some kind, and none of them meet
the criterion above.

1. **`4x4.COMPLETE-2026-07-21` — "the complete, validated 4×4 oracle."**
   `data/oracle-4x4.wzo`, 258,280,358 B, sha256 `b42c3371…655f`. **Status:
   FALSE-AS-SCOPED** (`CLAIMS.md:292`), retracted by `PROGRESS.md:267-270`,
   ADR-0013:126-128 and `AGENTS.md:54-57`. Do not use it as a baseline of
   truth; use it as a differential only.
2. **RETRO_BRACKET's "✓ in-bracket" +2.** The 4×4 empty bracket is **[−6, +16]**
   — width 22 of a 32-point range — and it contains +2 (`ruleset-options.md:213`).
   The same document says the single-number question is "emphatically not
   answered" (`:219-221`) and that a 3,702,442-slot spike sits at the *full*
   width-32 bracket. **Containment is not computation.** A bracket is not an
   acceptable output; if EXP-2's algorithm is producing one, re-read A4.
3. **`data/oracle-4x4-parallel.checkpoint.wzo` at "99.8% complete"** — `QA-016`,
   above. The missing 0.2% included the root.
4. **`untracked/oracle-4x4-writesoff-checkpoint.wzo`** — `4x4.WRITESOFF`,
   `CLAIMS.md:282`: exists, **build completion NOT confirmed**, uncommitted,
   differs from the committed artifact by 2,394 filled slots at stride 37. A
   file existing is not a build finishing. Do not cite it.

And the structural point that is the *reason* this experiment is worth running:
every shipped 4×4 ko-sensitive value rests on `QA-018` (the bracket-guided
finisher, ORPHANED — it derives from `GLOBAL.C3`, FALSE-AS-SCOPED at 3×3), and
`QA-019` says Track A does **not** escape it because `saveArtifact` hardcodes
`bracketed = true` (`src/retro.zig:2407`). The new rule is supposed to **delete**
the finisher and the bracket cuts, not fix them (roadmap §2). **If your build
still runs a bracket-guided finisher it has inherited `QA-018` and the result is
not clean.** State explicitly whether a finisher ran.

## Method

1. Use the EXP-5 solver, extended to 4×4. New file, new binary
   `weizigo-exp6-<console-id>`, `ZIG_LOCAL_CACHE_DIR` / `ZIG_GLOBAL_CACHE_DIR`
   under `/tmp/weizigo-zigcache`. Declare file ownership in
   `docs/status/CURRENT.md` before you start and clear it when done.
2. **Read EXP-3's 4×4 numbers first** and allocate accordingly. Reference
   points: the current PSK artifact is `32 + 6 × 3^16` = **258,280,358** B
   (`open-hypotheses-2026-07-27.md:78-80`); naive dense augmented addressing is
   `3^16 × 17` = **731,794,257** addresses × 6 B = **4.39 GB**
   (`CLAIMS.md` `GLOBAL.H1-CENSUS`). The budget placeholder is **≤ 32 GB and
   unconfirmed with the user** (`4x4.D3`) — if you are going to exceed it, ask
   before running, not after.
3. Run the gate chain (2×2, 3×2, 3×3) **before** launching the 4×4 build. A
   multi-hour run of a drifted binary is the most expensive way to learn this.
4. Build. Checkpoint. Watch the heartbeat.
5. Exhaustive UNDEF sweep, exhaustive symmetry sweep, tie census, root read.
6. **Differential against the PSK artifact**
   (`data/oracle-4x4.checkpoint.wzo`, sha256 prefix `a2174fedd6a0591d`,
   `reachable-kosensitivity-2026-07-28.md:137-140`): how many slots differ, the
   magnitude distribution, and whether differences concentrate in the
   10,367,922 slots the PSK table flags KO_SENSITIVE
   (`ruleset-options.md:213`). Report as a **finding**, not a correctness claim
   in either direction — different games are *allowed* to differ.
7. Artifact goes to a **new** path tagged `(size, ruleset)`, e.g.
   `data/oracle-4x4-basicko-tie-area.wzo`. Record its sha256 in the write-up.
   **Never overwrite anything under `data/` or `artifacts/`.**

## Calibration requirement (mandatory — dispatch README, done #4)

- **Known-good:** the full gate chain from this binary — 2×2 = 0, 3×2 = 0,
  3×3 = +9 — plus the exhaustive symmetry sweep passing at 4×4.
- **Known-bad, two cases:** (1) run your UNDEF/root checker against
  `data/oracle-4x4-parallel.checkpoint.wzo` and show it **reports the unfilled
  root** (`QA-016`) — a free, documented, known-bad artifact already on disk; a
  root checker that passes it is not a root checker. (2) Perturb one non-root
  slot of your own output and show the consistency sweep names it.

Both runs committed.

## Deliverables

- `docs/evidence/QA-026/4x4/` (or the per-board ID the `CLAIMS.md` owner
  assigns) — solver source, the raw build log including the heartbeat, the gate
  chain output, the UNDEF/symmetry/tie sweeps, the root byte read, both
  calibration runs, and `PROVENANCE.md` per `docs/evidence/README.md`.
- `docs/research/newrule-4x4-2026-07-28.md` — the value, the three-answer
  fitness line, the cost report, the PSK differential, whether a finisher ran,
  every claim tagged.
- The artifact at a new tagged path, with its sha256 recorded in git even though
  the bytes are not (`data/` is git-ignored, `.gitignore:4`).
- One-line status for the `CLAIMS.md` owner. **Do not edit `CLAIMS.md`.**

## Do NOT

- Do **not** touch `src/retro.zig`, `src/oracle.zig`, `src/rules.zig`,
  `src/solve.zig` without declaring exclusive ownership in
  `docs/status/CURRENT.md` first. On a run this long, an unannounced concurrent
  edit silently corrupts hours of work (`GLOBAL.ONEWRITER`).
- Do **not** overwrite `data/oracle-4x4*.wzo`, `artifacts/*`, or
  `artifacts/SHA256SUMS`.
- Do **not** report a percentage complete. Three answers: root filled? anchor
  matched? gate passed?
- Do **not** report a bracket or "in-bracket" as meeting the criterion.
- Do **not** claim 4×4 from 3×3, or let 4×4 evidence anything at 5×5
  (`AGENTS.md`, per-board epistemic independence). 5×5 is explicitly Phase 3
  and explicitly not now.
- Do **not** start EXP-7 or EXP-8's measurement from a partial checkpoint. Both
  need the finished table; EXP-7 in particular would read UNDEF slots and
  produce a meaningless number.
- Do **not** restart a long run to "try something". Escalate instead.
