# oracle-v2 SPEC — Audit

```
Auditor:  unknown/spec-audit (model not specified at dispatch)
Date:     2026-07-31
Target:   docs/infra/oracle-v2/spec.md (PROPOSED, Opus/Navigator, 2026-07-31)
Verdict:  NEEDS-FIX
```

## Verdict

**NEEDS-FIX.** The diagnosis in §1 is well-evidenced and the requirements
correctly target the root cause (projected key dimensions). But five findings
at **must** level or above block ratification, and one (F2 — R9 projection)
would falsify the sprint if left unverified. None of the defects are
architectural; all are spec-level omissions that can be resolved before
`design.md` begins. The structure is sound and the acceptance criteria are,
with the additions below, falsifiable.

---

## Findings

### F1 — BLOCKER: M2 has no access to a solver

The spec forbids M2 from touching `src/retro.zig`, `src/oracle.zig`,
`src/rules.zig`, `src/solve.zig` (§5), and assigns M2 to own
`src/oracle_v2_build.zig (new)`. But M2's job is "Compute DTT during the
fixpoint; serialise the full key with no projection." A fixpoint requires the
retrograde value-iteration algorithm, which lives in the forbidden files.

Two interpretations, both problematic:

1. **M2 re-implements the solver from scratch** in its new file. This
   duplicates the most complex code in the project (1588 lines of
   `exp6_solve.zig`, which is not on the forbidden list but handles the 32-bit
   encoding, not the 4×4 path), violates the "no re-solve" intent of §2's "out
   of scope," and is almost certain to hit R9's 4h wall budget.

2. **M2 calls into the existing solve modules without modifying them.** Then
   the forbid-list is the wrong mechanism — it should say "read-only" rather
   than "may not touch," and M2's `READS` should list the modules it depends
   on. The current language prevents even importing the existing fixpoint.

`exp6_solve.zig` already produces the full Markov key in memory (line 393:
`StateIdx32{ .board, .side, .ko, .passes }`). The defect is purely in the
*write path* (lines 1316–1339). If M2's real task is "use the existing solver's
in-memory result, add DTT, and write a different serialisation," the spec must
say so and must identify the exact public interface M2 imports.

**Required:** State which module provides the fixpoint to M2, and adjust the
forbid-list to "no mutation" rather than "no touch." If M2 is to re-solve from
scratch, that is a different sprint with a different budget.

### F2 — MUST: R9's 600 MB ceiling is a guess, not a derivation

The sizing note (§4) says EXP-3 projected 354 MB "with passes folded." But R1
requires passes NOT to be folded — the full Markov key has the passes dimension.
If the no-ko state count is 45,734,854 and ko adds ~12%, the full-key state
count is ~51.2M. At two i16 values (L, H) plus one u16 DTT per key, with a
4-component key encoding, the naive size is well above 354 MB.

The spec's own honesty is its best defence: "600 MB ceiling is set against
those numbers with headroom, not from first principles." But a sprint whose
budget is a guess can only be ratified on the condition that the guess is
verified in `design.md` before M2 begins. Otherwise R9-failure ("the full key
does not fit the budget") is discovered after the solve runs, wasting a
wall-clock session.

**Required:** Add an explicit gate: `design.md` must include a concrete byte
budget derived from the chosen key encoding and column schema, with the actual
state count from EXP-3, before M2 may begin. If the derived budget exceeds 600
MB, the sprint returns to the Orchestrator for re-scoping.

### F3 — MUST: R6 (legality enforcement) is underspecified for M3

R6 says "Legality enforcement is selectable at run time: `basic-ko` | `psk` |
`ssk`. Default and behaviour on mismatch with `rules_id` must be stated and
logged." This is stated as a requirement on the sprint, but it does not say
what the engine *does*:

- **On mismatch:** Does the engine refuse to load the artifact? Warn and
  downgrade? Silently enforce the declared rule?
- **On play-time PSK/SSK:** The artifact was generated under basic-ko. If the
  user selects PSK enforcement at play time, does the engine reject moves that
  repeat a position even though the oracle says they're legal under basic-ko?
  Or does it consult the oracle first and then apply the PSK filter? Either
  choice changes play strength.
- **Default:** Which rule is the default?

M3 cannot begin without these answers, and the spec is the sole upstream
document for M3's brief.

**Required:** Add a subsection to R6 stating (a) the default, (b) mismatch
behaviour, and (c) whether enforcement filters the oracle's move suggestions or
only rejects moves at the GTP layer.

### F4 — MUST: A1 script not pinned

A1 reads: "On a scripted 20-ply self-play opening, `UNCHAINABLE` refusals ≤
the old PSK artifact's rate on the same script." The old PSK artifact scored
0/6. But:

- The script is not specified. Different 20-ply openings traverse different
  regions of state space, and the ko-sensitive region's shape varies
  dramatically.
- The old PSK artifact was generated under positional superko; the new one
  under basic-ko. A move sequence legal under both rulesets exercises a
  different set of ko-pending states than one that exploits basic-ko's wider
  legality.
- "≤ the old PSK artifact's rate" — the denominator is 6. A single refusal in
  20 plies yields ~0.05. This is too coarse. The spec should state a denominator
  that is large enough to be meaningful.

**Required:** Either (a) pin the exact 20-ply script in an appendix, or (b)
redefine A1 as "0 refusals on an N-ply random self-play sample with
denominator ≥ 100, compared against the same sample run on the old PSK
artifact." State the seed.

### F5 — MUST: Solver cycle convention is unstated

R2 says the cycle convention is applied by the reader. But the solver's
fixpoint iteration *also* needs a convention — the retrograde algorithm
maintains separate L and H bounds, and when a cycle is detected, the bounds
must be updated according to some rule. The current solver uses a specific
convention (presumably TIE=0 pinning during the fixpoint, visible at
`exp6_solve.zig:1329`: `const V = @max(Lv, @min(TIE, Hv))`).

The spec must state what cycle convention the solver uses during the fixpoint,
even if the reader is free to override it at play time. Otherwise M2 cannot
know whether the L/H bounds it stores are compatible with the intended reader
conventions.

**Required:** Add a sentence to R2: "The solver's fixpoint uses convention X
(e.g. TIE=0 pinning) during value iteration; the L/H bounds stored are the
converged bounds under that convention, and the reader may select a different
V from the same bracket."

### F6 — MUST: passes=2 boundary condition not specified

The Markov key includes `passes ∈ {0, 1, 2}`. The state with `passes=2` is a
terminal (both players passed consecutively; the game ends and the score is
counted). R1 requires storing it. But:

- Is passes=2 terminal scored by area counting (dead stones removed, empty
  points counted) or is it a zero-value state whose score is the terminal
  reward of passing?
- Does the fixpoint treat passes=2 as absorbing (no children) and use the
  terminal score as its value? Or is the terminal score computed
  position-by-position from the board state?
- DTT for passes=2 states: is it 0 (terminal reached) or something else?

The current solver handles passes=2 specially (line 454: `if (passes == 2)
{ ... }`). M2 needs to know the contract.

**Required:** Add a requirement R10 specifying the passes=2 terminal semantics
and DTT value, or fold this into R3.

### F7 — SHOULD: M4's dependency on M2/M3 is a serialisation trap

The dependency graph shows M4 → M2, M3. But A1, A2, and A8 require BOTH the
solver's output (M2) and the engine's integration (M3). M4 cannot begin until
both are complete, which means the acceptance harness is on the critical path
*after* the two longest modules.

The spec acknowledges this in §5 ("M2 and M3 may run concurrently once M1's
design.md has passed audit") but does not address that M4 then blocks the
final gate. If M2 takes 4h (the R9 wall budget) and M3 takes 1h, M4 adds
another hour after both. This is a schedule risk, not a spec defect, but it
is worth noting.

**Suggested:** Consider splitting M4 into M4a (decoupled checks: A3, A5, A6,
A9) and M4b (integration checks: A1, A2, A8). M4a can begin alongside M2/M3.

### F8 — SHOULD: R8 ("verifier review") is underspecified

R8 requires that "any relaxation of a reader/verifier check is called out
explicitly in `design.md` and audited." But it does not say what constitutes a
"relaxation," nor what the baseline of checks is. M1's task includes "the R8
verifier review" but has no verifier spec to review against.

The `verify-battery` spec exists in parallel (`docs/infra/verify-battery/spec.md`)
but is PROPOSED and may not be ratified when M1 begins. M1 needs a concrete
list of checks that the format must support.

**Required:** Either (a) list the verifier checks that the format must preserve
in this spec, or (b) state that M1's verifier review gates on the
verify-battery spec being ratified first.

### F9 — COULD: Artifact naming and placement not specified

The spec says M1 owns the format and R7 requires one documented command to
regenerate. But the artifact's filename, extension, and placement (`data/`?
`untracked/`?) are not stated. The v1 artifact is `data/oracle-4x4.checkpoint.wzo`;
the old PSK artifact used a different naming scheme. Without a naming
convention, M2 and M3 may write to different paths.

**Suggested:** Add a short section or a note to R4 stating the filename
convention (e.g. `data/oracle-{goban}-v2.wzo2`).

---

## Responses to the spec's five audit questions

### Q1: Is A1 the right headline criterion?

**Yes, with the F4 caveat.** A1 measures user-visible regression, which is what
makes the sprint worth doing. A refusal-count metric is the right shape — it is
simple, mechanised, and hard to game. But A1 is a *smoke test*, not a
correctness criterion. The real soundness gate is A2 (Bellman residual after
round-trip). The spec should state this relationship: "A1 is the headline
because it is the user-visible symptom; A2 is the soundness gate. A2 passing
without A1 improving is implausible; A1 improving without A2 passing is a
false positive."

### Q2: Does R2 actually decouple this sprint from the pin rule?

**Yes, for the artifact.** Storing L and H means the artifact is
convention-agnostic — TIE=0, no-result, and score-on-cycle readers all consume
the same data. The decoupling holds.

**Partially, for the solver.** The solver still needs a convention during its
fixpoint (see F5). But that convention can be fixed (e.g. TIE=0) without
affecting the artifact, and the reader can override. So the decoupling holds
for the sprint's external dependencies, but the solver's internal convention
must be stated.

### Q3: Is the M1-blocks-M2/M3 serialisation necessary?

**Yes.** M1 defines the key encoding and column schema. M2 writes it; M3 reads
it. If M1 changes after M2 has serialised, M2's output is garbage. If M1
changes after M3 has integrated, M3 reads garbage. The format IS the interface,
and an interface that changes after implementation produces the EXP-4→7
failure mode the spec itself cites.

The cost is one format-design session on the critical path. Given that the
alternative is two wasted solve/engine sessions, the serialisation is cheap
insurance. If the schedule is tight, offload M1 to the fastest available agent
and give it a 30-minute time box.

### Q4: Are the "today's v1 scores" honest?

**Yes.** I spot-checked each against the codebase:

- A1's "10/10 refused": consistent with the known defect (48.5M of 99.1M
  states dropped, all ko-pending and one-pass states unreachable). Plausible.
- A8's "1 distinct value across 43M slots": confirmed at line 1311
  (`@memset(db, 255)`) — DTT is memset to 255 (FAR) and never written again.
  The count of 43,046,721 is not independently verified but the shape is
  correct.
- A5's "passes trivially": honest — round-trip on a no-ko, no-passes key is
  just array index identity, not a format test.

No criterion is padded or misrepresented. The spec's self-assessment is
credible.

### Q5: Is R9's budget projection load-bearing enough to verify before committing?

**No — this is F2.** The projection chains through three approximations:

1. EXP-3's state count (51.4M ko triples over 29.5M distinct addresses)
2. A 6 B/address encoding assumption (unstated encoding)
3. A "with passes folded" caveat that R1 contradicts

The first is empirical (EXP-3 ran). The second and third are guesses. A format
design that chooses, say, 16-bit L and 16-bit H per state (= 4 bytes of value
per address, not 6 bits) blows through 600 MB immediately. This must be pinned
before M2 starts.

---

## Summary

| Grade | Count | IDs |
|-------|-------|-----|
| BLOCKER | 1 | F1 |
| MUST | 5 | F2, F3, F4, F5, F6 |
| SHOULD | 2 | F7, F8 |
| COULD | 1 | F9 |

All six MUST+ findings are spec omissions, not structural flaws. The
requirements are correct and the acceptance criteria are falsifiable. The
module decomposition is the right shape. Resolve F1–F6 in a revision and this
spec is ready for ratification.
