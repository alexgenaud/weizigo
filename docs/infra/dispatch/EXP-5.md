# EXP-5 — 3×3 under the new rule: the first legitimate anchor comparison

**Closes:** the 3×3 result under the new rule; corroborates `QA-025` and
`QA-026` at 3×3. **Blocks:** EXP-6. **Blocked by: EXP-4** (which is blocked by
EXP-2). Do not start until EXP-4 has returned **0 at both 2×2 and 3×2**. If it
returned +1, the build is PSK and 3×3 would be meaningless.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`docs/epistemic/roadmap-2026-07-28.md` §1 (the MIGOS II section) and §3
(EXP-5), then `docs/infra/dispatch/EXP-4.md` and EXP-4's output
(`docs/research/newrule-2x2-3x2-2026-07-28.md`,
`docs/evidence/QA-026/`), then `docs/research/retrograde-3x3.md:224-245`, then
`docs/research/ruleset-options.md` §RETRO_BRACKET (the near-miss).

---

## The question

Under the same rule EXP-2 pinned down and EXP-4 validated — area scoring, komi
0, basic ko, fixed-value long-cycle verdict — what is the value of the empty
3×3 board?

## Acceptance criterion

**+9**, exactly, for Black on the empty board, plus:

- **Root filled.** No UNDEF (`-128`) at the root or anywhere. Report
  `root filled? anchor matched? gate passed?` — not a fill percentage (roadmap
  §4 **P4**).
- **Colour-inversion symmetry** exhaustive over all 25,350 `(position, side)`
  slots: `value(-pos, -side) == -value(pos, side)` (`AGENTS.md`). Free at this
  size; run it.
- **The 2×2/3×2 gate still passes** from the same binary. Re-run EXP-4's two
  boards after any change to the solver and paste the output. A 3×3 run from a
  binary that has silently drifted back toward PSK would go undetected —
  +9 is an *agreeing* anchor, so it cannot catch drift the way 0-vs-+1 can.
- **Tie-vs-score disambiguation.** 3×3 has 9 points; with komi 0 the area score
  is always **odd**, so a tie value of 0 lies **outside** the natural value set
  (`roadmap-2026-07-28.md` §2, "The known complication"). This is a gift:
  at 3×3 a tie is unambiguously identifiable. **Report how many reachable
  states take the tie value, and whether the root is one of them.** If the root
  is a tie, +9 is not the answer and something is wrong.

## Why this comparison is finally legitimate — say this in the write-up

Every previous anchor comparison this project made was **weak evidence
presented as strong**. `critique-2026-07-28.md` §3, verbatim in substance:
weizigo plays PSK, MIGOS II plays basic ko + long-cycle ties, these are
*different games*, they happen to agree at 3×3 and 4×4, and they **provably
disagree at 2×2 and 2×3**. So "3×3 = +9 matches the published anchor" has,
until now, been agreement between two different games on a board where the
difference does not bite.

**EXP-5 is different in kind, not in degree.** If EXP-2 and EXP-4 hold, we
would be solving *the same game the anchor was computed under* — van der Werf &
Winands' MIGOS II ruleset, quoted at `retrograde-3x3.md:224-245`: Chinese/area
scoring, "since superko is not used", balanced long-cycle repetition scored as
a long-cycle tie (`QA-025`, PROVEN). Matching +9 then means what an anchor
match is supposed to mean.

Two honesty constraints on that framing, both of which must appear in the
write-up:

1. It is legitimate **only if** EXP-2's ruleset formalisation actually is MIGOS
   II's. Cite EXP-2's A2 (basic-ko definition) and A5 (value domain) decisions
   explicitly and note that the published description is a sentence, not a
   specification. Where you had to choose, say what you chose.
2. An anchor match is **one number**. It confirms the root, not the table.
   Do not upgrade "matched +9" into "the 3×3 table is correct."

## Prior attempts this must distinguish itself from

1. **RETRO_BRACKET already "matched" +9 at 3×3 — by containment, not
   computation.** `ruleset-options.md:209-213`: 3×3 empty-board bracket
   **[2, 9]**, width 7, marked "✓ in-bracket" against the +9 anchor. That is a
   bracket 7 wide out of a 25-point range containing the anchor; `ruleset-
   options.md:223-227` states outright that the empty-board bracket is WIDE and
   that the L/H method "says little about *it specifically*". **Containing +9
   is not computing +9.** If your run produces a bracket rather than a value,
   you have not met the acceptance criterion.
2. **The existing 3×3 artifact is PSK and fresh-start-only.**
   `artifacts/oracle-3x3.wzo` — 65.7% single-score, 8,698 ko-sensitive slots
   (`ruleset-options.md:209-213`). Its values are **not** a reference for this
   experiment; the two rules may legitimately differ per-state even where the
   roots agree. Use it only as a *differential*: report how many slots differ
   and by how much, as a finding, with no presumption which is "right" for its
   own rule.
3. **`GLOBAL.C3` / E2 do not apply and must not be invoked.** The bracket
   apparatus is what the new rule deletes (roadmap §2). If you are shipping a
   bracket at all, re-read EXP-2's A4.

## Method

1. Take EXP-4's solver unchanged if it is board-size-generic; otherwise extend
   it minimally. New file, new binary `weizigo-exp5-<console-id>`, caches under
   `/tmp/weizigo-zigcache` (README, build isolation).
2. Run the 2×2 and 3×2 gate first, from the binary you are about to use for
   3×3. Paste the output.
3. Solve 3×3. 25,350 `(position, side)` slots over 12,675 legal positions
   (`ruleset-options.md:209-213`; `src/enumerate.zig` for the 12,675 target);
   with the ko dimension the address count is whatever EXP-3 measured — read
   EXP-3's number rather than guessing, and if EXP-3 has not landed, allocate
   densely and say so.
4. Exhaustive symmetry check. Exhaustive UNDEF check.
5. Cross-check as deep as is affordable: a full-history brute-force under the
   same rule is *not* expected to be feasible from the empty 3×3 board — say so
   explicitly rather than quietly skipping it — but it **is** feasible from
   late positions with few empty points. Do that, on a stated sample, and
   report the sample size.

## Calibration requirement (mandatory — dispatch README, done #4)

- **Known-good:** the 2×2 = 0 and 3×2 = 0 gate, re-run from this binary, plus
  EXP-4's committed state-by-state 2×2 agreement.
- **Known-bad:** two cases.
  1. Perturb one non-root 3×3 state and show the symmetry/consistency checker
     names it. A root-only check is not a checker.
  2. Point the same checker at the **PSK** 3×3 artifact
     (`artifacts/oracle-3x3.wzo`) and show it flags disagreement somewhere.
     Both roots are +9, so a root-only comparison would pass — the checker must
     be able to tell the two tables apart *below* the root, or it cannot certify
     that you solved the new rule rather than the old one. **This is the
     calibration case that matters at 3×3**, precisely because the anchor
     agrees.

## Deliverables

- `docs/evidence/QA-026/3x3/` (or a per-board ID directory once the `CLAIMS.md`
  owner assigns one) — solver source, raw run output with command/flags/build
  mode, the re-run 2×2/3×2 gate output, the symmetry and UNDEF sweeps, both
  calibration runs, `PROVENANCE.md` per `docs/evidence/README.md`.
- `docs/research/newrule-3x3-2026-07-28.md` — the value, the tie census, the
  differential against the PSK artifact, the legitimacy argument above with its
  two honesty constraints, every claim tagged.
- Any artifact written goes to a **new** path tagged by `(size, ruleset)`, e.g.
  `data/oracle-3x3-basicko-tie-area.wzo`.
- One-line status for the `CLAIMS.md` owner. **Do not edit `CLAIMS.md`.**

## Do NOT

- Do **not** touch `src/retro.zig`, `src/oracle.zig`, `src/rules.zig`,
  `src/solve.zig` without declaring exclusive ownership in
  `docs/status/CURRENT.md`. Read-only imports are fine.
- Do **not** overwrite `artifacts/oracle-3x3.wzo` or anything else in
  `artifacts/` or `data/`.
- Do **not** proceed to 4×4. That is EXP-6.
- Do **not** infer 3×3 from 2×2/3×2, or claim 3×3 evidences anything at 4×4
  (`AGENTS.md`, per-board epistemic independence).
- Do **not** report a bracket, a range, or "in-bracket" as satisfying the
  acceptance criterion. The criterion is the number +9.
- Do **not** report a fill percentage in place of `root filled? anchor matched?
  gate passed?`.
- Do **not** claim "the anchor comparison is now legitimate" without citing
  EXP-2's A2/A5 decisions. The legitimacy is inherited from EXP-2, not asserted
  here.
