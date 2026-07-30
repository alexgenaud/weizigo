<!--managent set=I needs=T113-->

# EXP-7 4×4 re-run — certified fraction against `data/oracle-4x4-basicko-tie-area.wzo`

**Closes:** the 4×4 half of `QA-027` and `QA-020` re-tested under the new rule
at 4×4. **Blocks:** nothing. **Blocked by: T113** — it needs the serialized 4×4
.wzo artifact. T113 is `untracked/T113-exp6-wzo.md` (mechanical serialization
of EXP-6's in-memory fixpoint to `data/oracle-4x4-basicko-tie-area.wzo`).

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`docs/infra/dispatch/EXP-7.md` (the original brief — this re-run inherits its
design constraints and acceptance criterion, scoped to 4×4 only), then
`docs/research/newrule-certified-fraction-2026-07-30.md` (EXP-7's 3×3 result),
then `docs/research/newrule-4x4-2026-07-28.md` (EXP-6's 4×4 result — the table
this run measures).

---

## What changed since the original EXP-7

The original EXP-7 ran at 3×3 only (100.00% certified fraction, 0 violations
over 8,000 decision nodes, 2,000 oracle games, seed 20260728). 4×4 and 4×3 were
blocked: no .wzo artifact existed. EXP-6 computed the 4×4 fixpoint in-memory
(V=+1, bracket [L=+1, H=+16], 31 sweeps, converged) but did not serialize.
T113 now produces `data/oracle-4x4-basicko-tie-area.wzo` — the first on-disk
4×4 new-rule table. This re-run closes the 4×4 half.

The original tool (`src/exp7_census.zig`) embeds the fixpoint in-memory and does
not read .wzo files. **You will need to either: (a) extend it to read the .wzo
file, or (b) write a new tool that reads the .wzo and runs the playout +
Bellman-identity check.** Route (a) is the fast path — the playout engine,
Bellman checker, and rule implementation already exist; only the fixpoint-load
path differs. Route (b) is cleaner for a read-only experiment. **Whichever you
choose, it must NOT embed the fixpoint — it must read from T113's artifact and
verify its sha256 on load.**

4×3 remains not tested (no new-rule table exists at that size) — the original
EXP-7 brief's requirement for 4×3 is out of scope for this re-run. 3×3 is
already done and is not re-run.

---

## The question

Under the new rule (basic ko + TIE=0 long-cycle verdict, area scoring, komi 0),
on the 4×4 table at `data/oracle-4x4-basicko-tie-area.wzo`: what is the
certified fraction — the proportion of visited decision nodes in self-play where
the one-ply Bellman identity holds directly?

The knowns going in:

- EXP-6's fixpoint root is **V=+1** (not the +2 anchor), bracket-valued
  [L=+1, H=+16]. The root is NOT in the single-score (L==H) region.
- The 3×3 table was single-valued at the root (L==H==9) and returned 100.00%
  certified. The 4×4 root being bracket-valued is exactly where the V-domain
  Bellman identity could fail even though the L/H fixpoint converged.
- This is the substance of the falsification test. `QA-027` says 100% by
  construction; if the bracket-valued root produces Bellman violations in
  self-play, the table is not chainable and the Markovian claim is wrong at 4×4.

---

## The traps — all inherited from the original EXP-7 brief, all mandatory

Read `docs/infra/dispatch/EXP-7.md` in full. The four traps are reproduced here
because they are the substance of the measurement:

### 1. The vacuity trap

The original `bin/weizigo-reachcensus` reads bit 0 of the flag column (L < H).
Under the new rule there is no bracket, so the flag column will plausibly be all
zero. That measurement would be vacuous. **Measure the direct one-ply Bellman
identity at every visited decision node.** Certified = identity holds. Report
the direct-identity fraction as the headline; report any flag-read fraction
alongside it only for comparison, with an explicit statement that it is
degenerate.

### 2. Legality must be the new rule's

The PSK reachcensus enforces positional superko. Walking PSK-legal playouts over
a basic-ko table measures a game neither rule plays. **Switch playout legality
to basic ko + TIE=0 cycle verdict, and state this in the header of every run.**

### 3. Long cycles must terminate the playout

Under basic ko a self-play line can cycle forever. The playout must use the
rule's own cycle verdict: detect (board, side, ko) repetition for placement
moves (passes excluded from cycle detection), terminate the game, score as TIE.
**Report cycle-terminated games as their own category, with a count**, and state
how the TIE value is scored into the Bellman identity and the certified fraction
(both per `EXP-7.md`, definitional trap 2).

### 4. The TIE value in the Bellman identity

Value domain is `ℤ ∪ {TIE}` with TIE between −1 and +1 (EXP-2 A5). The
max/min in the Bellman identity must respect that ordering. Black (maximizing):
TIE beats any negative value, loses to any positive. White (minimizing): TIE
beats any positive, loses to any negative. A checker that silently coerces TIE
to an integer will produce violations that are artefacts, or hide real ones.

### One new trap specific to this re-run

The .wzo file format (WZO1) stores L/H value columns for every dense colex
slot. The V value is derived: V = median(L, TIE=0, H). **The Bellman identity
check must use V, not L or H individually.** The original `weizigo-chainability`
checked L=Φ(L) and H=Φ(H) separately, which is the PSK-bracket form of the
identity and is not the measurement described here. The new-rule measurement
checks V(state) == best_child({V(child)}).

---

## Acceptance criterion (4×4 only)

For the 4×4 table at `data/oracle-4x4-basicko-tie-area.wzo`:

- **Direct-identity certified fraction = 100.00%**, i.e. **zero** Bellman-identity
  violations over all visited decision nodes, under both `oracle` and
  `oracle-rt` policies, at ≥ 2,000 games per policy with the seed and game count
  printed. If 2,000 games produce too few distinct lines due to deterministic
  play in a small state space, **state that** and use `mixed` to supplement —
  but `oracle` and `oracle-rt` are the acceptance policies.
- The **denominator is stated** with every percentage (nodes, and games).
- **Zero UNDEF decision nodes.** The table must be fully filled; any UNDEF means
  the artifact is incomplete. Report the count; do not silently exclude.
- Also report `random` and `mixed` for continuity. Not part of the criterion,
  but 100% under `oracle` with a low figure under `random` is suspicious and
  must be explained.
- **Cycle-terminated games reported as their own category** with a count and
  their handling stated.
- **Flag-read fraction reported alongside**, with the explicit statement that
  the flag column is degenerate (all-zero) under this rule, so the flag-read
  fraction measures nothing.

**Any violation ⇒ `QA-027` is false at 4×4 ⇒ STOP and escalate.** Record the
violating node, its stored V value, and the child V values — exactly what the
original brief demands.

---

## Method

1. **Verify the artifact.** `sha256sum data/oracle-4x4-basicko-tie-area.wzo`
   before running. Record it in the output header.
2. **Build the tool.** Extend `src/exp7_census.zig` or write a new standalone.
   It reads the WZO1 file (dense colex addressing, 3^16 slots × 2 bytes for L
   and H), derives V = median(L, TIE=0, H) on the fly, and runs the playout +
   Bellman check. **Do not embed the fixpoint** — this is a read-only experiment
   against T113's artifact. Build through `tools/runner` with the 4 GB RSS cap.
   Declare file ownership in `docs/status/CURRENT.md`.
3. **The playout engine uses the new rule's legality.** Basic ko: at most one
   ko-point prohibition (single-stone capture shape). No PSK. Suicide and
   occupancy checked. Long-cycle detection via (board, side, ko) repetition for
   placement moves; passes excluded.
4. **The Bellman check at each decision node:** compute the set of legal child
   states under the new rule, look up V(child) for each, compute best_child
   respecting TIE ordering, compare to V(state). MATCH, VIOLATION, TIE_CHILD,
   CYCLE (if the move itself cycles) — report each category.
5. **Run policies:** `oracle`, `oracle-rt`, `random`, `mixed`. Same seed
   convention as the original: `--seed 20260728`. If a policy produces a
   single deterministic line (as oracle did at 3×3), state it and report the
   line; the acceptance criterion still requires ≥ 2,000 games.
6. **Run calibration** (below) before reporting any result as certified.
7. **Build through `tools/runner`** with appropriate time ceiling. The WZO1
   read is O(1) per lookup; the playout is lightweight. The run should complete
   in minutes, not hours.

---

## Calibration requirement (mandatory — dispatch README, done #4)

- **Known-good:** the existing 3×3 result. Run your new/adapted tool against
  the 3×3 new-rule table (either recompute the 3×3 fixpoint or, if T113
  produces a 3×3 .wzo as well, read that) and reproduce the 100.00% certified
  fraction at 8,000 nodes, 2,000 games, seed 20260728. If your tool cannot
  reproduce the 3×3 result, it is measuring something different from the
  original.
- **Known-bad, case 1:** perturb one value in the 4×4 table (write a small
  script to flip one byte in the L or H column at a non-root slot) and confirm
  the Bellman check reports a violation and names the node. The perturbation
  must survive V-derivation (i.e., flip L such that V changes, or flip H such
  that V changes for a bracket-valued slot).
- **Known-bad, case 2:** run your Bellman check on the **PSK** 4×4 table
  (`data/oracle-4x4.checkpoint.wzo`, sha256 prefix `a2174fedd6a0591d`) under
  the **new rule's legality** and confirm it does **not** return 100%. This
  proves your checker is sensitive to the difference between the rules. **This
  was blocked in the original EXP-7 because the tool embedded the fixpoint.**
  With a .wzo-reader tool, this is now feasible — the WZO1 format is the same
  for both artifacts; the tool does not know which rule produced the table.

Both calibration runs committed.

---

## Deliverables

- `docs/evidence/QA-027/` — add the 4×4 runs: raw stdout of every run (command,
  artifact path + sha256, board, seed, games, policy, build mode), all
  calibration runs, and an update to `PROVENANCE.md` recording the 4×4 results.
  **Do not overwrite the 3×3 files.**
- `docs/research/newrule-certified-fraction-2026-07-30.md` — append the 4×4
  section (or, if the file has been promoted, write a new dated addendum). The
  fractions per board with denominators, the direct-identity vs flag-read
  comparison, the cycle-termination accounting, every claim tagged.
- One-line status for the `CLAIMS.md` owner (`QA-027` and `QA-020` at 4×4).
  **Do not edit `CLAIMS.md`.**

---

## Do NOT

- Do **not** embed the fixpoint. Read from T113's artifact.
- Do **not** touch `src/retro.zig`, `src/oracle.zig`, `src/rules.zig`,
  `src/solve.zig` without declaring exclusive ownership in
  `docs/status/CURRENT.md`. You should not need any of them.
- Do **not** write to `data/` or `artifacts/`. This experiment reads only.
- Do **not** ship the flag-read fraction as the headline. State explicitly that
  it is degenerate.
- Do **not** report 100% without the direct identity check, the denominator,
  the seed and the game count.
- Do **not** round a non-100% result up, re-tune, or re-seed.
- Do **not** claim the 4×4 result evidences anything at any other board.
- Do **not** treat 100% as confirming `QA-023`. It is consistent with it. The
  proof is EXP-2's job; this experiment can only falsify.
- Do **not** re-run 3×3. It is done. This re-run is 4×4 only.
- Do **not** reopen 4×3. No new-rule table exists at 4×3; it remains out of
  scope.
- Do **not** overwrite T113's artifact. Verify sha256; then read-only.
- Do **not** call the L==H region "proven core" or "certified core" in any
  real-game sense. The original brief's framing holds.
