# EXP-3 — the `(board, side, ko_point)` reachable-state census

**Closes:** `GLOBAL.H1-CENSUS` (at 4×4 — it is scoped to 4×4 and UNTESTED,
`CLAIMS.md:316`); informs `GLOBAL.H1` / `QA-011`. **Blocks:** the addressing
decision for EXP-6 (and therefore any 4×4 build under the new rule).
**Blocked by: NOTHING.** Counting, not semantics. **Run it today, in parallel
with EXP-2** — `README.md` draws EXP-3 beside EXP-2, not under it. If EXP-2
fails this census is still worth having: it prices the representation either
way.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`docs/epistemic/roadmap-2026-07-28.md` §3 (EXP-3), then
`docs/research/open-hypotheses-2026-07-27.md` §H1 (lines 62-118 — effectively
the spec, and more detailed than the roadmap), then
`docs/research/ruleset-options.md:76-81`, the sparsity constraint that is the
whole reason this experiment exists.

---

## The question, stated precisely

For each board **independently** — 3×3, 4×3, 4×4 — count:

- **(a)** the exact number of **reachable** `(board, side_to_move, ko_point)`
  triples, where `ko_point ∈ {none} ∪ {the n points}`;
- **(b)** the exact number of distinct `(board, ko_point)` **addresses** — this
  is what a *dense* artifact must index, and it is the number that decides the
  addressing question;
- **(c)** the implied artifact size at **6 columns of 1 byte** per address;
- **(d)** the **sparse/dense ratio** — (b) divided by the naive dense address
  count `3^(w·h) × (n+1)`.

Reachable means: arising after some sequence of legal basic-ko moves from the
empty board. `ko_point = none` for every position reachable by a non-ko move or
as a root; `ko_point = p` exactly when the immediately preceding move captured
exactly one stone and the capturing stone then has exactly one liberty, the
vacated cell `p` — the basic-ko shape `src/ko_census.zig` already detects.

**Also report, as a secondary number:** the same counts with the `passes ∈
{0,1}` component included (`passes = 2` is terminal). EXP-2 Part A works with
`(board, side, ko_point, passes)`, and EXP-6 must allocate for whatever the
solver keys on, so both figures need to be on the table.

## The constraint that makes this non-trivial

`docs/research/ruleset-options.md:76-81`, from the RETRO_PLY post-mortem: *that
augmented state space is **sparse** (reachable (board, window) pairs only) — the
dense colex addressing the current engine relies on does not extend to windows.*

The engine's whole storage model is a dense colex index over `3^(w·h)`
(`GLOBAL.S1`, `CODE.ADR0011-FMT`). If the augmented space is sparse, dense
addressing either wastes most of the file or must be replaced by a perfect-hash
/ sorted-key scheme. **The census must report reachable-vs-dense explicitly so
that decision rests on a number.** Do not recommend a scheme — report the
numbers and what each option costs.

## Reference points (cite these; do not re-derive them silently)

| quantity | value | source |
|---|---|---|
| current PSK 4×4 artifact on disk | `32 + 6 × 3^16` = **258,280,358** B | `open-hypotheses-2026-07-27.md:78-80`, verified 2026-07-27 |
| naive dense 4×4 augmented addresses | `3^16 × 17` = **731,794,257** | `open-hypotheses-2026-07-27.md:79-81`; `CLAIMS.md:316` |
| … × 6 B | **4.39 GB** = 17× the current artifact | same |
| `(position, side)` slots, all legal | 3×3 **25,350** · 4×3 **643,378** · 4×4 **48,636,330** | `ruleset-options.md:209-213` |
| reachability bitset cost at 4×4 | `3^16 × 17 × 2` bits = **183 MB** | `open-hypotheses-2026-07-27.md:110` |
| 4×3 sweep speed reference | 531,441 colex slots in **0.84 s** CPU | `open-hypotheses-2026-07-27.md:107-109` |

The prior expectation on record is that (a) is a *small* multiple of the
`(position, side)` slot count. That is an expectation, not a result. Measure it.

## Prior work this must distinguish itself from

1. **`src/ko_census.zig` (B23) is a different census.** It counts *independent
   ko clusters* on **ko-sensitive** positions of a loaded artifact
   (`docs/research/ko-census.md`, the 65/33/2/0.0025% multi-ko frequencies) —
   "how many simultaneous kos", not "how many reachable states". Reuse its
   **shape detector**; do not reuse its denominators or present its numbers as
   this census's numbers.
2. **`GLOBAL.H1-CENSUS` has never been run** (UNTESTED, `CLAIMS.md:316`). No
   earlier attempt to contradict — but `git log` the file you create before
   assuming you are first.
3. **RETRO_PLY is not a precedent for a NO-GO here.** It died because a
   *score-on-cycle terminal* needs full history, not because of state-space
   size (`ruleset-options.md:53-71`). Its sparsity remark applies to you; its
   intractability verdict does not.

## Method

Instrumentation only. **New file** — suggested `src/kostate_census.zig`, built
as `weizigo-exp3-<console-id>`, caches under `/tmp/weizigo-zigcache`.
`src/settled_census.zig` models a single-pass census harness;
`src/enumerate.zig` gives the legal-position odometer;
`src/ko_census.zig:isKoCapture` gives the ko-shape test.

1. Enumerate legal positions with the base-3 odometer (`src/enumerate.zig`;
   validation targets 3×3 = 12,675 and 4×4 = 24,318,165, OEIS A094777 — check
   you reproduce them before trusting anything downstream).
2. For every legal position `Q` and every basic-ko-legal move by either colour:
   compute the child `P`, decide whether the move left a basic-ko shape, and
   mark `(P, side, ko_point)` reachable in a bitset. Mark `(P, side, none)` for
   every position reachable by a non-ko move, and for the empty board as a root.
3. Iterate to a fixpoint if your marking is not single-pass — reachability is
   over the *legal-move graph* and captures create back-edges
   (`GLOBAL.ADR0007-BACKEDGE`). **Do not assume one sweep suffices.** State how
   many sweeps you needed and how you knew you had converged.
4. Report (a)–(d) **per board, separately**. Run 3×3, then 4×3, then 4×4 —
   three independent measurements.

## Acceptance criterion

For **each** of 3×3, 4×3 and 4×4, all four numbers, exact (no estimates, no
sampling, no extrapolation between boards):

- (a) reachable triples — an exact integer;
- (b) distinct `(board, ko_point)` addresses — an exact integer;
- (c) implied artifact size at 6 × 1 B/address — an exact byte count, stated
  alongside the 258,280,358 B reference;
- (d) sparse/dense ratio (b) ÷ `3^(w·h) × (n+1)` — to 4 significant figures,
  with both operands printed.

Plus a **GO/NO-GO on dense addressing at 4×4**: dense costs X bytes, sparse
costs Y bytes under scheme Z, budget is B. The D3 budget placeholder is **≤ 32
GB and still marked "confirm with user"**
(`docs/epistemic/boards/4x4/EPISTEMIC.md` `[T07-9]`, `CLAIMS.md` `4x4.D3`) —
report against it and flag that it is a placeholder. A NO-GO is a full
deliverable: it closes the last named tractable generation candidate.

## Calibration requirement (mandatory — dispatch README, done #4)

- **Known-good, two parts:** the enumerator reproduces the published
  legal-position counts 1×1 = 1, 2×2 = 57, 3×3 = 12,675, 4×4 = 24,318,165
  (`src/enumerate.zig` header, OEIS A094777); **and** with the ko dimension
  disabled (every state forced to `ko_point = none`) the reachable count
  collapses to exactly the known `(position, side)` slot counts — 25,350 /
  643,378 / 48,636,330 (`ruleset-options.md:209-213`). If it does not, the
  reachability walk is wrong and the ko numbers are worthless.
- **Known-bad:** feed it a deliberately broken ko detector — e.g. mark *every*
  capture as leaving a ko point, not only single-stone captures with the
  one-liberty follow-up — and show the count moves, in the direction and rough
  magnitude you predicted *before* running it. A counter that returns the same
  number for a right and a wrong detector is measuring nothing.

Both calibration runs are committed deliverables, not notes.

## Deliverables

- `docs/evidence/GLOBAL.H1-CENSUS/` — census source, raw stdout of every run
  (command, board, flags, build mode), both calibration runs, and a
  `PROVENANCE.md` per `docs/evidence/README.md` (claim IDs, acceptance
  criterion, date, run commands, calibration cases).
- `docs/research/kostate-census-2026-07-28.md` — the four numbers per board,
  the addressing GO/NO-GO, every claim tagged.
- One-line status per board for the `CLAIMS.md` owner. `GLOBAL.H1-CENSUS` is
  scoped to 4×4; 3×3 and 4×3 need **their own rows** under per-board
  independence — propose IDs (e.g. `3x3.H1-CENSUS`, `4x3.H1-CENSUS`) and let
  the owner assign them. **Do not edit `CLAIMS.md`.**

## Do NOT

- Do **not** touch `src/retro.zig`, `src/oracle.zig`, `src/rules.zig`,
  `src/solve.zig` without declaring exclusive ownership in
  `docs/status/CURRENT.md` first. You need none of them; write a new file.
  Read-only imports are fine.
- Do **not** write to `data/` or `artifacts/`. This produces no artifact.
- Do **not** infer one board's count from another's (`AGENTS.md`, per-board
  epistemic independence).
- Do **not** recommend or implement an addressing scheme. Report each option's
  cost; the choice is an ADR and belongs to the user.
- Do **not** solve anything. No values, no L/H, no scores. This is a count.
- Do **not** report a sampled or strided estimate. Every number here is exact
  or it is not a deliverable.
