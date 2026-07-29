<!--managent set=E needs=EXP-6-->

# EXP-7 — the certified fraction under the new rule: a falsification test

**Closes:** `QA-027` ("under a Markovian rule the certified fraction is 100% by
construction"). Re-tests `QA-020` (FALSE at 0%) under the new rule; a negative
result falsifies `QA-023` and therefore the roadmap. **Blocks:** nothing.
**Blocked by: EXP-6** — it needs the finished 4×4 table, root filled, gate
chain passed. It runs in parallel with EXP-8.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`docs/epistemic/roadmap-2026-07-28.md` §1 ("chainable and Markovian are the
same property seen from two sides") and §3 (EXP-7), then
`docs/research/reachable-kosensitivity-2026-07-28.md` **in full** — it is the
baseline you are re-running and it documents every definitional choice you must
either keep or consciously change. Then
`docs/research/ko-sensitive-chainability.md` Measurement 1 for the identity
check itself.

---

## Frame this correctly before you start

> **This is a falsification test, not a victory lap.**

`QA-027` says the answer is 100% *by construction*. That makes 100% almost
uninformative on its own and makes **anything else a major finding**: if the
certified fraction under the new rule is not 100%, the table is not chainable,
the state is not Markovian for the rule it was built under, and **`QA-023` is
false and the roadmap fails** — after EXP-2 said it would not. Report that
loudly and escalate (README, Escalation). Do not patch, do not re-tune, do not
report "99.7%, essentially 100%".

Because a by-construction claim is cheap to confirm accidentally, the design
constraint below is the substance of this task.

## The trap that makes the naive version worthless

`bin/weizigo-reachcensus` computes `certified fraction = 1 − (KO_SENSITIVE
fraction over reached decision nodes)` by reading **bit 0 of the `fb`/`fw` flag
columns** (L < H) (`reachable-kosensitivity-2026-07-28.md:20-27, 65-72`).

Under the new rule there is no bracket, so the flag column will plausibly be
**all zero**. Reading it would then return 100% for a table that is arbitrarily
wrong. **That measurement would be vacuous and must not be shipped.**

**Required instead:** measure the property the flag was a *proxy* for — verify
the **one-ply Bellman identity directly at every visited decision node**, the
way `bin/weizigo-chainability` does, against the new table's own values and the
new rule's own legal-move generator. Certified = identity holds. Report the
direct-identity fraction as **the headline**, the flag-read fraction alongside
it, and whether the flag column is degenerate. Disagreement between the two is
itself a finding.

## Three more definitional traps, all mandatory

1. **Legality must be the new rule's.** `src/reachcensus.zig` enforces
   **positional superko** against full game history
   (`reachable-kosensitivity-2026-07-28.md:73-77`). Walking PSK-legal playouts
   over a basic-ko table measures a game neither rule plays. Switch the playout
   legality to basic ko + the new rule's long-cycle handling, and **say so in
   the header of every run**.
2. **Long cycles must terminate the playout.** Under basic ko a self-play line
   can cycle forever. The playout needs the rule's own cycle verdict, not the
   256-ply cap standing in for it. Report cycle-terminated games as their own
   category, with a count, and state how the tie value is scored into the
   statistics.
3. **The tie value in the identity check.** The value domain is `ℤ ∪ {tie}`
   with the tie ordered between −1 and +1 (EXP-2 A5 — use EXP-2's actual
   decision, not this paraphrase). The max/min in the Bellman identity must
   respect that ordering. A checker that silently coerces the tie to an integer
   will produce violations that are artefacts, or hide real ones.

## The baseline you are measuring against

All from `reachable-kosensitivity-2026-07-28.md`, 2026-07-28, 2,000 games per
policy, master seed **20260728**, ply cap 256, settled-stop on. Denominator =
**decision nodes** *[project term]*, i.e. `(position, side-to-move)` observed
before the move is made — not table slots.

| board | policy | nodes | KO_SENS (node-wtd) | ⇒ certified today |
|---|---|---|---|---|
| 4×4 | `oracle` | 28,000 | 100.00% | **0%** |
| 4×4 | `oracle-rt` | 27,865 | 100.00% | **0%** |
| 4×3 | `oracle` | 22,000 | 100.00% | **0%** |
| 4×3 | `oracle-rt` | 22,000 | 100.00% | **0%** |
| 3×3 | `oracle` | 14,000 | 42.86% (6,000/14,000) | **57.14%** |
| 3×3 | `oracle-rt` | 16,306 | 41.38% (6,747/16,306) | **58.62%** |

Carry two things into the write-up. **The "0%" headline is 4×4 and 4×3 only** —
3×3 is already ~57%, so "0% → 100%" is the 4×4/4×3 story and quoting it for 3×3
is wrong (`QA-020` is scoped to 4×4 and 4×3). And the artifacts:
`data/oracle-4x4.checkpoint.wzo` (sha256 prefix `a2174fedd6a0591d`),
`artifacts/oracle-4x3.wzo` (`5316f428ad821c79`), `artifacts/oracle-3x3.wzo`
(`c1f8fe5edac9a427`).

## Acceptance criterion

For **each** board separately — 3×3, 4×3, 4×4 — on the new-rule tables from
EXP-5 and EXP-6:

- **Direct-identity certified fraction = 100.00%**, i.e. **zero** Bellman-identity
  violations over all visited decision nodes, under both `oracle` and
  `oracle-rt`, at ≥ 2,000 games per policy with the seed and game count printed.
- The **denominator is stated** with every percentage (nodes, and games).
  A mislabelled counter in `weizigo-chainability` already seeded a three-way
  percentage confusion across four documents (README, done #5).
- **Zero UNDEF decision nodes** — EXP-6 requires a fully filled table, so any
  UNDEF here means you loaded the wrong artifact. Report the count; do not
  silently exclude games as the PSK census had to.
- Also report `random` and `mixed` for continuity. Not part of the criterion,
  but 100% under `oracle` with a low figure under `random` is suspicious and
  must be explained.

**Any violation, at any board, under any policy ⇒ `QA-023`/`QA-027` are false
⇒ STOP and escalate.** Record the violating node, its stored value, and the
child values, exactly as `bin/weizigo-chainability` does for the PSK table.

## Prior attempts this must distinguish itself from

1. **The 2026-07-27/28 chainability sweep already found "zero violations outside
   the KO_SENSITIVE flag"** at every size, exhaustively at 4×4 (48,599,962
   slots, 422,990 violations, all flagged, zero outside — `QA-021`, PROVEN).
   That is a statement about a *PSK* table conditioned on a flag; it is not this
   measurement and must not be cited as a partial result for it.
2. **`QA-020` measured 0% and is FALSE.** It is the baseline, not a competitor.
3. **The 1:37 colex-stride sample (`4x4.M4`, 21.27%) is superseded** by the
   exhaustive 21.33% figure (reconciliation in `ko-sensitive-chainability.md`).
   Do not reintroduce a strided estimate here.

## Calibration requirement (mandatory — dispatch README, done #4)

- **Known-good:** point your instrument at the **existing PSK artifacts** in its
  original flag-reading mode and **reproduce the baseline table above exactly** —
  4×4 `oracle` 100.00% over 28,000 nodes at seed 20260728, 3×3 `oracle` 42.86%
  over 14,000 — byte-for-byte on the pre-existing statistics. If you cannot
  reproduce the old numbers, your changes altered the measurement and nothing
  you report about the new table is comparable to anything.
- **Known-bad, two cases:** (1) perturb one value in the new-rule table and
  confirm the direct-identity check reports a violation and names the node;
  (2) run the direct-identity check on the **PSK** 4×4 table under the **new
  rule's** legality and confirm it does **not** return 100%. A checker that
  returns 100% for both tables is measuring nothing — case (2) is what proves
  you avoided the vacuity failure above.

Both runs committed.

## Deliverables

- `docs/evidence/QA-027/` — the modified/new census source, the raw stdout of
  every run (command, artifact path + sha256, board, seed, games, policy,
  build mode), both calibration runs, and `PROVENANCE.md` per
  `docs/evidence/README.md`.
- `docs/research/newrule-certified-fraction-2026-07-28.md` — the fractions per
  board with denominators, the direct-identity vs flag-read comparison, the
  cycle-termination accounting, and every claim tagged. Per-board sections.
- One-line status per board for the `CLAIMS.md` owner (`QA-027`, and `QA-020`
  re-tested under the new rule). **Do not edit `CLAIMS.md`.**

## Do NOT

- Do **not** touch `src/retro.zig`, `src/oracle.zig`, `src/rules.zig`,
  `src/solve.zig` without declaring exclusive ownership in
  `docs/status/CURRENT.md`. You should not need them; `src/reachcensus.zig` and
  `src/chainability.zig` are the files in scope — and if EXP-8 runs
  concurrently, agree who owns `src/reachcensus.zig` **before** either edits it.
- Do **not** write to `data/` or `artifacts/`. This experiment reads only.
- Do **not** ship the flag-read fraction as the headline; it is very likely
  vacuous under this rule.
- Do **not** report 100% without the direct identity check, the denominator,
  the seed and the game count.
- Do **not** round a non-100% result up, re-tune, or re-seed until it passes.
  Re-seeding to change an answer is falsification laundering; if you re-seed,
  report **every** seed you ran (the baseline does: 20260728, 1, 999331).
- Do **not** claim a result at one board evidences another (`AGENTS.md`).
- Do **not** treat 100% as confirming `QA-023`. It is consistent with it. The
  proof is EXP-2's job; this experiment can only falsify.
