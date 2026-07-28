# EXP-4 — 2×2 and 3×2 under the new rule: THE falsification gate

**Closes:** `QA-026` as scoped to 2×2 and 3×2 (the L/H-machinery-reuse claim);
produces the first per-board result rows under the new rule. **Blocks:** EXP-5,
and therefore EXP-6, EXP-7, EXP-8. **Blocked by: EXP-2.** Do not start the
build until EXP-2 has passed and its adversarial proof review is recorded. If
EXP-2 failed, stop — the whole line is dead and a workaround is not wanted.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`docs/epistemic/roadmap-2026-07-28.md` §2 and §3 (EXP-4), then
`docs/infra/dispatch/EXP-2.md` **and EXP-2's actual output**
(`docs/evidence/QA-023/proof.md`, `docs/research/qa023-basicko-markovian-2026-07-28.md`)
— the algorithm and the value domain are decided there, not here. Then
`docs/research/retrograde-3x3.md:224-245` — the anchor table and the ruleset
delta. Then `docs/research/ruleset-options.md` §RETRO_PLY and §kill-X%, the two
near-misses below.

**Naming:** the published literature says "2×3"; this repo says **3×2**. Same
6-point board, `artifacts/oracle-3x2.wzo`. Use the repo name in code and say so
once in the write-up.

---

## The question, stated precisely

Under **area scoring, komi 0, basic ko, and a fixed-value verdict for long
cycles** — the rule EXP-2 pinned down — what is the game-theoretic value of the
empty board at 2×2 and at 3×2?

## The acceptance criterion

**Both boards must return 0.**

| board | published (MIGOS II, this ruleset) | weizigo's PSK value | source |
|---|---|---|---|
| 2×2 | **0** | **+1** | `retrograde-3x3.md:224-245` |
| 3×2 (published "2×3") | **0** | **+1** | `retrograde-3x3.md:224-245` |

These two rulesets **provably disagree** on exactly these two boards
(`critique-2026-07-28.md` §3). That is what makes this the cheapest correctness
gate in the project:

> **A build that returns +1 has implemented PSK by accident.**

Not "is approximately right", not "is in the bracket" — **0, exactly, on both
boards, or the build is wrong.** Check it before you check anything else, and
before you write a line of the 3×3 driver.

Secondary acceptance, both boards:

- **Every** state's value is defined. No UNDEF (`-128`) anywhere, including the
  root. Report `root filled? anchor matched? gate passed?`, not a fill
  percentage (roadmap §4 **P4**; `QA-016` is the cautionary tale).
- The value domain behaves as EXP-2's A5 specified. On 2×2 (4 points, even) and
  3×2 (6 points, even) a 0 area score is *inside* the natural value set, so the
  tie value and a genuine 0 are **indistinguishable by the number alone**.
  **You must report, separately, whether the empty-board 0 is a scored 0 or the
  long-cycle tie.** If EXP-2's domain makes them the same symbol, say so and
  explain what that costs; the distinction matters at 3×3 (odd board, EXP-5).
- Colour-inversion symmetry holds: `value(-pos, -side) == -value(pos, side)`
  (`AGENTS.md`). Exhaustive at these sizes; it is free.

## Prior attempts this must distinguish itself from

Three near-misses, all in `docs/research/ruleset-options.md`. Read them; each
one is a way to get a plausible-looking number that is not this experiment.

1. **RETRO_PLY at N=1 is basic ko — and it blew the budget at 2×2 and 3×2**
   (`ruleset-options.md:53-71`). *Every* N, including N=1, hit the 200M-node
   cap with no score. **Why you are not repeating it:** RETRO_PLY was a
   *forward* exact search with a **score-on-cycle** terminal, so the full ban
   set stayed in the memo key. You are running a **retrograde fixpoint** with a
   **constant** cycle verdict. If you find yourself carrying a ban set, or
   detecting cycles at runtime, you have rebuilt RETRO_PLY and it will fail the
   same way. Stop and re-read EXP-2's Part A.
2. **kill-50% at 2×2 returns +1 in 4,795 nodes** (`ruleset-options.md:91-98`).
   That is a *different rule* that removes the cycle pathology while preserving
   the PSK answer. If your build returns +1, do **not** reach for this as
   corroboration — it is the opposite: it is the documented signature of a rule
   in which the cycles that should tie do not.
3. **The RETRO_BRACKET deliverable is not an answer.** The existing 2×2/3×2
   fresh-start empty-board score is **+1** at both sizes, finisher-produced and
   inside its bracket (`retrograde-3x3.md:215-220`). It is PSK, it is
   fresh-start-only, and `AGENTS.md` forbids quoting it as a real-game value.
   Do not compare against it as if it were ground truth; compare against it as
   the *falsifier* — you expect to differ.

## Method

1. **Implement the rule from EXP-2's Part A**, in a new standalone file (e.g.
   `src/newrule_solve.zig`), built as `weizigo-exp4-<console-id>`. EXP-2 has
   already produced a working 2×2 implementation plus an independent
   brute-force reference under `docs/evidence/QA-023/` — **start from those**.
   Re-deriving the semantics is how the two consoles end up solving two
   different games.
2. **2×2 first.** Reproduce EXP-2's 2×2 result exactly, state for state, before
   extending. If you cannot reproduce it, that disagreement is the finding —
   report it, do not paper over it (README, Escalation).
3. **Then 3×2.** New board, new measurement, no inheritance.
4. **Independent cross-check at both sizes.** These boards are small enough for
   a full-history brute-force game-tree evaluation under the *same* rule. Run
   it and compare **every state**, not just the root. EXP-2 built this
   reference for 2×2; extend it to 3×2.
5. Artifacts, if you write any, go to **new** paths tagged by `(size, ruleset)`
   — e.g. `data/oracle-2x2-basicko-tie-area.wzo`. Never overwrite
   `artifacts/oracle-2x2.wzo` or `artifacts/oracle-3x2.wzo`.

## Calibration requirement (mandatory — dispatch README, done #4)

The comparison harness must ship with both:

- **Known-good:** it passes on 2×2 against EXP-2's committed reference output —
  state agreement on every state, and root = 0.
- **Known-bad, two cases, because there are two distinct failure modes:**
  1. Perturb one non-root state's value and confirm the state-by-state
     comparison fails and names that state. (A root-only check would miss it —
     that is the point.)
  2. Run your harness against the **PSK** solver on 2×2 and confirm it reports
     a mismatch at the root (+1 vs 0). This is the calibration that proves your
     gate can actually tell the two rulesets apart. **A gate that cannot
     distinguish PSK from the new rule cannot certify that you implemented the
     new rule.**

Both runs are committed deliverables.

## Deliverables

- `docs/evidence/QA-026/` — solver source, brute-force reference source, raw
  output for 2×2 and 3×2, both calibration runs, and a `PROVENANCE.md` per
  `docs/evidence/README.md` (claim IDs, acceptance criterion, date, run
  commands, calibration cases).
- `docs/research/newrule-2x2-3x2-2026-07-28.md` — the two values, the
  scored-0-vs-tie determination, the symmetry check, the brute-force agreement,
  and every claim tagged. Per-board sections; no shared conclusions.
- One-line status per board for the `CLAIMS.md` owner. Propose per-board IDs
  (e.g. `2x2.BASICKO-TIE`, `3x2.BASICKO-TIE`); let the owner assign them.
  **Do not edit `CLAIMS.md`.**

## Do NOT

- Do **not** touch `src/retro.zig`, `src/oracle.zig`, `src/rules.zig`,
  `src/solve.zig` without declaring exclusive ownership in
  `docs/status/CURRENT.md`. Prefer a new file. Read-only imports are fine.
- Do **not** overwrite anything in `data/` or `artifacts/`. New rule → new
  file → new name, tagged by `(size, ruleset)` (`ruleset-options.md:38-40`).
- Do **not** proceed to 3×3. That is EXP-5 and it is gated on this returning 0
  on both boards.
- Do **not** report "+1, but the ruleset difference explains it." It does not.
  +1 **is** the PSK answer and returning it means you solved PSK. Escalate.
- Do **not** infer 3×2 from 2×2, in either direction, for any quantity.
- Do **not** relitigate the PSK, score-on-cycle or kill-X% foreclosures. They
  are correct. Your job is to show this rule is *different*.
- Do **not** report a fill percentage in place of the acceptance criterion.
