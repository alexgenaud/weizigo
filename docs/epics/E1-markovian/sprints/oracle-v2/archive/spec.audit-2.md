# oracle-v2 SPEC — Pass-1 Audit

```
Auditor:  DSPro/T135 · Role: worker · Model: DSPro · Date: 2026-07-31
Target:   docs/infra/oracle-v2/spec.md (PROPOSED pass 1, Fable/Navigator,
          2026-07-31). Pass-0 snapshot + audit: docs/design/oracle-v2/pass0/.
Verdict:  PASS
```

## Verdict

**PASS.** All six MUST+ findings from the pass-0 audit (BLOCKER F1, MUST
F2–F6) are discharged — each resolution is traceable to concrete spec text
and, where the claim touches code, independently verified against
`src/exp6_solve.zig`. The three SHOULD/COULD findings (F7–F9) are also
adopted. Four COULD-level observations below; none block ratification.

The pass-1 revision is a faithful repair of the pass-0 defects. The
structure, requirements, acceptance criteria, and module decomposition are
sound. The spec is ready for human ratification.

---

## F1–F9 resolution verification

### F1 (BLOCKER): M2 has no access to a solver — RESOLVED ✓

**Pass-0 audit:** The forbid-list said "may not touch" retro/oracle/rules/
solve, meaning M2 couldn't even import the fixpoint. Required: "no mutation"
not "no touch," and naming the exact interface M2 imports.

**Pass-1 resolution:**
1. Module M2 split into **M2a** (fixpoint interface exposure — `pub`-only
   refactor of `src/exp6_solve.zig`) and **M2b** (builder — imports M2a's
   interface, computes DTT, serialises).
2. Forbid-list changed to "imported but not mutated" (§5 heading:
   "Read-only, not untouchable").
3. M2a's scope stated: expose `StateIdx32`, rank/unrank, `moves32`/4×4
   analogue, reachability builder, fixpoint entry points.
4. M2a acceptance: v1 pipeline still builds; A7 gate chain reproduces; 3×3
   v1 artifact byte-identical.

**Code verification.** Confirmed at `src/exp6_solve.zig:266` — `StateIdx32`
is a `packed struct` with `board: u32, side: u8, ko: u16, passes: u8` and
`linear()`. The 3×3 `StateIdx` (line 556) shares the same layout. The 4×4
path uses `encodeState4`/`decode*4`/`genChildren4` (lines 887–976) — no
struct, a 40-bit packed u64. The spec's phrasing "moves32/4×4 analogue"
covers this difference. M2a's brief will need to be precise about which
types/functions per goban size; the spec is not the brief. **Finding passes.**

**Observation COULD-1 (see below) on naming detail.**

### F2 (MUST): R9's 600 MB ceiling is a guess — RESOLVED ✓

**Pass-0 audit:** Required a design gate: M1's `design.md` must derive a
concrete byte budget before M2b may begin; > 600 MB returns to Orcha.

**Pass-1 resolution:** New paragraph in §4 ("Byte-budget gate [F2]"):
"M1's `design.md` must derive a concrete byte budget from the chosen key
encoding, column schema, and the actual EXP-3 counts (passes NOT folded)
before M2b may begin. A derived budget > 600 MB returns the sprint to the
Orchestrator for re-scoping."

The gate is correctly positioned — it sits between G2 (format ratified) and
O-5 (M2b dispatch) in the strategy. **Finding passes.**

### F3 (MUST): R6 (legality enforcement) underspecified — RESOLVED ✓

**Pass-0 audit:** Default, mismatch behaviour, and filter semantics not
stated.

**Pass-1 resolution:** New §3.1 "R6 semantics [F3]" with four clauses:

| scenario | behaviour | verification |
|---|---|---|
| Default | = artifact's `rules_id` (basic-ko for this sprint) | Logged: `ENFORCEMENT <mode> (artifact rules_id <id>)` |
| Stricter than artifact | Permitted with warning. Optimality guarantee void. | Logged: `ENFORCEMENT-OVERRIDE: values are <rules_id>-optimal, play filtered by <mode>` |
| Weaker than artifact | Refuse load — reintroduces §1 defect | Logged: `RULES-MISMATCH-FATAL` |
| Filter mechanism | Both sides. Opponent: GTP layer. Oracle's own moves: filtered before play (next-best legal, else pass). Consult oracle first, then apply legality. | — |

**Completeness check.** The artifact this sprint produces is basic-ko.
(artifact × selected) matrix:

| artifact | selected | covered by |
|---|---|---|
| basic-ko | basic-ko | Default clause |
| basic-ko | psk | Stricter (psk forbids more) |
| basic-ko | ssk | Stricter (ssk forbids more) |

For future artifacts: the "stricter/weaker" test is "is every move legal
under selected also legal under artifact?" If yes → stricter (permit with
warning). If no → weaker (FATAL). The logic is well-defined for all pairs.

**ssk vs psk ordering.** Both are stricter than basic-ko. PSK is stricter
than SSK (PSK forbids repeated positions; SSK forbids repeated
state-tuples). The spec does not name this ordering explicitly. For this
sprint it is a non-issue — both are stricter than basic-ko and hit the same
clause. **Finding passes.** See COULD-2.

### F4 (MUST): A1 script not pinned — RESOLVED ✓

**Pass-0 audit:** The 20-ply scripted opening was not specified; denominator
of 6 too coarse.

**Pass-1 resolution:** A1 rewritten to "random self-play with a pinned seed
(recorded in the harness and in the evidence), denominator ≥ 100 oracle
queries: **0** `UNCHAINABLE` refusals. The old PSK artifact is run on the
identical sample and its rate reported as baseline."

The new form addresses both defects: ≥ 100 queries (vs. 6), pinned seed
recorded in evidence (vs. unspecified script). The RNG source is not
specified — this is an implementation concern for O-8's brief, not a spec
defect. **Finding passes.** See COULD-3.

### F5 (MUST): Solver cycle convention unstated — RESOLVED ✓

**Pass-0 audit:** Required stating the fixpoint convention. Even if the
reader overrides, the solver's internal convention determines the stored
L/H bounds.

**Pass-1 resolution:** New addendum below R10: "Solver fixpoint convention
[F5]." Claims:
1. Fixpoint maintains L/H as convention-free bracket bounds
2. Initialised to ±n; terminals pinned to L=H=area score (R10)
3. Minimax sweeps to convergence
4. **No pin rule enters the iteration**
5. TIE=0 pin (`V = @max(L, @min(0, H))`) is a projection applied only at
   v1's write path; v2 drops it

**Code verification against `exp6_solve.zig`.** Traced end-to-end:

| claim | 3×2 (lines 444–531) | 4×4 (lines 1096–1254) |
|---|---|---|
| L_init = -n, H_init = +n | `-@as(i8, @intCast(n32))` / `+n32` (line 447) | `-16` / `16` (lines 1133–1134) |
| Terminals = area score | `genericAreaScore(n32, &b, W32, H32)` (lines 461–462) | Computed on the fly in child lookup: `genericAreaScore(N4, &b, W4, H4)` (lines 1184, 1227) |
| No TIE pin in iteration | No `median()`, `@max`, or `TIE` constant in sweep loop | No `median()`, `@max`, or `TIE` constant in sweep loop |
| TIE pin in write path only | — | `const V = @max(Lv, @min(TIE, Hv))` at line 1329 (v1 serialisation); v2 drops it |

The 4×4 fixpoint uses two independent sweeps (L minimax, then H minimax),
propagating bounds without any pin rule. The TIE=0 constant (line 40:
`const TIE: i8 = 0`) appears only in `median()` (line 723) and the v1 write
path (line 1329). Neither is called during the 4×4 sweep loop.

**One structural note.** The 4×4 fixpoint excludes passes=2 from its compact
array (`if (passes == 2) continue;` at line 1104), computing terminal values
inline when they appear as children. This is equivalent to the 3×2/3×3
approach of pinning them in the array, just more memory-efficient. The
converged L_tab/H_tab for non-terminal states are the same either way.
M2b will need to generate DTT=0 entries for passes=2 states; R10 provides
the anchor.

**Finding passes.** The spec's characterisation is faithful to the code.

### F6 (MUST): passes=2 boundary condition not specified — RESOLVED ✓

**Pass-0 audit:** Required R10 specifying terminal semantics and DTT value.

**Pass-1 resolution:** New R10: "passes=2 terminal contract [F6]." States:
- Absorbing (no children generated)
- Value L = H = area score (`genericAreaScore`; captures resolved by move
  application, no separate dead-stone removal)
- DTT = 0
- References `exp6_solve.zig:454-460` as matching

**Code verification.** `exp6_solve.zig:456-462` (3×2 fixpoint):
```zig
if (passes == 2) {
    const b = unrank_board32(board_idx);
    L_tab[lin] = genericAreaScore(n32, &b, W32, H32);
    H_tab[lin] = genericAreaScore(n32, &b, W32, H32);
}
```
Matches R10 exactly: L=H=area score, no dead-stone removal step. The
`genChildren4` function (line 957: `if (passes == 2) return;`) confirms
passes=2 is absorbing — zero children. DTT=0 is the new contract for M2b;
it is consistent with the terminal status. **Finding passes.**

### F7 (SHOULD): M4 serialisation trap — ADOPTED ✓

M4 split into M4a (A3, A5, A6, A9 — decoupled, needs only format) and M4b
(A1, A2, A4, A8 — integration, needs M2b+M3). M4a runs concurrent with
M2b/M3. **Finding adopted and resolved.**

### F8 (SHOULD): R8 verifier review underspecified — ADOPTED ✓

R8 now includes: "Baseline inventory [F8]: the A1–A9 harness in §4 plus the
reader-side checks that M1's `design.md` enumerates (that enumeration is an
M1 deliverable)." Defines "relaxation" explicitly. **Finding adopted and
resolved.**

### F9 (COULD): Artifact naming not specified — ADOPTED ✓

New paragraph in §4: "Artifact naming [F9]." `data/oracle-{goban}-v2.wzo2`.
Sprint builds → `untracked/oracle-v2/`; SHA-256 of untracked build; `data/`
copy verified against it. **Finding adopted and resolved.**

---

## M2a/M2b split

The pass-1 spec replaces the single M2 module with two:

| module | role | owns | depends on |
|---|---|---|---|
| M2a | Expose `pub` in `exp6_solve.zig` — no behavioural change | `src/exp6_solve.zig` | Ratified spec only |
| M2b | Import fixpoint; compute DTT; serialise | `src/oracle_v2_build.zig` (new) | M1 design ratified + M2a reviewed |

**Assessment.** The split is correct and necessary. `exp6_solve.zig`'s sole
`pub` declaration is `pub fn main()` (confirmed at line 1535). M2a is a
pure refactoring pass — mark existing symbols `pub`, add no logic. M2b then
imports the exposed interface (read-only) and builds the artifact.

The split also removes M2a from M1's critical path — M2a runs concurrent
with format design, needing only the ratified spec. M2b gates on both M1
(format) and M2a review (fixpoint interface), which is the correct
dependency order.

M2a's acceptance criteria are well-chosen:
1. v1 pipeline still builds (Zig compiler won't silently break)
2. A7 gate chain reproduces (2×2=0, 3×2=0, 3×3=+9 — semantic equivalence)
3. 3×3 v1 artifact byte-identical (bitwise equivalence)

Together these prove "no behavioural change" by construction + verification.

**One COULD (see below):** the naming "StateIdx32 (line 266)" in §5 M2a
references the 3×2 type; the 4×4 analogue is `encodeState4`/`decode*4`/
`genChildren4` — a different encoding (packed u64, not a struct). The spec
acknowledges this with "moves32/4×4 analogue." The M2a brief will need to
enumerate the exact symbols per goban size.

---

## R6 semantics (§3.1)

**Coverage.** Every pair of (artifact rules_id, selected mode) is covered by
the three clauses (default, stricter, weaker), using the operational test
"every move legal under selected is also legal under artifact."

**Filter semantics.** The spec states:
- Enforcement filters **both** sides
- Opponent moves: checked at GTP layer → GTP error
- Oracle's own moves: filtered before play → next-best legal by reader's V,
  else pass
- *Consult oracle first, then apply legality — never the reverse*

This last point ("oracle first, then legality") is load-bearing: if the
filter rejected a move before consulting the oracle, the oracle's value for
it would never be evaluated, and a better move masked by illegality would
never be found. The stated order is correct.

**Logging.** All three branches produce distinct, greppable log messages.

**Verdict: complete and implementable for M3.**

---

## R10 passes=2 clause

Covered under F6 verification above. Additional confirmation:

- `genChildren4` (line 957): `if (passes == 2) return;` — absorbing ✓
- The 4×4 fixpoint computes terminal values inline via `genericAreaScore`
  (lines 1183–1184, 1226–1227) — area scoring, no dead-stone step ✓
- DTT=0 is a new contract, not present in v1 code (DTT was never computed).
  It is consistent with terminal semantics and anchors R3 ✓

---

## Spec's self-audit questions (§8)

### Q1: Is M2a's pub-exposure refactor genuinely behaviour-preserving?

**Yes.** Adding `pub` to existing file-private declarations changes only
visibility — the compiler rejects any semantic change that would alter
layout or calling convention. The three acceptance criteria (v1 builds, A7
chain, byte-identical 3×3 artifact) are individually sufficient and
collectively exhaustive.

**Is anything M2b needs missing from the exposed list?** The spec lists
"state encoding (StateIdx32, rank/unrank, moves32/4×4 analogue), the
reachability builder, and the fixpoint entry points." M2b also needs:
- The compact array + hash map (for 4×4) or the dense reach bitset (for
  3×2/3×3) to iterate states
- The converged L_tab/H_tab

The spec's "fixpoint entry points" covers returning L_tab/H_tab. The
reachability builder (census) returns the reach bitset or compact list.
This is covered. **No missing dependency identified.**

### Q2: Do the §3.1 mismatch rules cover every pair, and is ssk-vs-psk well-defined?

**Yes, all pairs covered.** The operational test "every move legal under
selected is also legal under artifact" handles all (artifact × selected)
pairs generically. For this sprint (basic-ko artifact), psk and ssk are
both stricter and hit the same clause.

**ssk-vs-psk is well-defined operationally** (set inclusion of legal moves)
but not named explicitly. See COULD-2.

### Q3: Is A1's ≥ 100-query denominator with pinned seed reproducible across machines?

**Seed recording is specified** ("recorded in the harness and in the
evidence"). The RNG source is not specified. Zig's
`std.Random.DefaultPrng` is NOT guaranteed cross-platform (seeded with
OS entropy unless explicitly seeded with a deterministic algorithm). The
O-8 brief should use an explicit PRNG with a known algorithm (e.g.
`std.Random.Pcg`) whose output is platform-independent, so the pinned seed
reproduces identically on any machine. Not a spec defect — an implementation
note. See COULD-3.

### Q4: Is the fixpoint convention-free, and does R2's reader-side selection hold for all three conventions?

**Yes, verified against code.** The fixpoint propagates L and H as
independent bounds without pinning. The stored L/H interval [L, H] contains
the true game-theoretic value. All three conventions (TIE=0, no-result,
score-on-cycle) select V ∈ [L, H] by different rules — TIE=0 picks median
with zero, no-result picks a sentinel, score-on-cycle picks some score.
Since [L, H] bounds the true value, any selection within it is a valid
score under that convention. The decoupling holds.

**One edge:** if the reader selects a convention that assigns a score
OUTSIDE [L, H], the artifact provides no guarantee. But no proposed
convention does this; all three select within the bracket.

### Q5: Is the byte-budget gate stated tightly enough to prevent a projection from passing as a derivation?

**Yes.** The gate requires:
1. Derived from "the chosen key encoding, column schema, and the actual
   EXP-3 counts (passes NOT folded)"
2. "A derived budget > 600 MB returns the sprint to the Orchestrator for
   re-scoping"

A projection (e.g. "if we fold passes the budget is X") would violate
"passes NOT folded." A handwave (e.g. "roughly 400 MB") would not be a
derivation from key encoding + column schema + actual counts. The
acceptance audit (O-4) can reject a non-derivation.

**The gate also correctly moves the discovery to design time** — O-3
produces a budget before O-5 dispatches. If O-3's budget exceeds 600 MB,
O-4 flags it, G2 doesn't ratify, and no wall-clock session is wasted.

---

## Additional findings

### COULD-1: M2a interface naming detail

The spec's §5 M2a lists "StateIdx32 (line 266), rank/unrank, moves32/4×4
analogue." The 4×4 path uses a different encoding — `encodeState4` (packed
u64), `decodeBoard4`/`decodeSide4`/`decodeKo4`/`decodePasses4`, and
`genChildren4`. No `StateIdx4` struct exists.

The spec's "4×4 analogue" phrasing is sufficient at spec level. The M2a
brief should enumerate the exact symbols: for 3×2/3×3 the `StateIdx`/
`StateIdx32` struct + `moves`/`moves32` functions; for 4×4 the
`encodeState4` tuple + `genChildren4`. This is a briefing detail, not a
spec defect.

### COULD-2: ssk-vs-psk ordering is implicit

§3.1's "stricter than artifact" clause uses the logical test "every
selected-legal move is artifact-legal." For this sprint (basic-ko
artifact), psk and ssk are both stricter and the ordering between them is
academic. For a future sprint with a psk artifact, selecting ssk would hit
the "weaker" clause (ssk-legal ⊈ psk-legal → FATAL), which is correct.

The spec could add a one-sentence note: "Stricter ordering: basic-ko ⊂ ssk
⊂ psk (by move-set inclusion)." Not necessary for this sprint, but cheap
future-proofing.

### COULD-3: A1 RNG reproducibility detail

The spec states "pinned seed (recorded in the harness and in the
evidence)" but not the RNG algorithm. Zig's `std.Random.DefaultPrng`
selects a platform CSPRNG and does NOT guarantee cross-machine
reproducibility. For A1 to reproduce, the O-8 brief should pin an explicit
PRNG algorithm (e.g. `std.Random.Pcg`) so the same seed produces the same
sequence on any host.

This is an implementation detail for O-8's brief, not a spec defect —
"pinned seed" and "recorded in evidence" are the right requirements. The
brief writer should note the PRNG-specific pinning.

### COULD-4: passes=2 states excluded from 4×4 compact, DTT implications

R10 specifies DTT=0 for passes=2 states. The 4×4 fixpoint excludes
passes=2 from its compact array (`if (passes == 2) continue;` at line
1104), so M2b will not receive them from M2a's interface. M2b must
generate DTT=0 entries for all passes=2 states and include them in the
serialisation — they anchor R3's backward DTT propagation.

The spec correctly provides the anchor (R10), and M2b's task description
says "compute DTT (R3, anchored per R10)." The passes=2 gap between the
fixpoint interface and the DTT anchor is a design detail for M2b, not a
spec omission — the spec names the contract; M2b implements it.

---

## What the spec gets right

1. **Root-cause diagnosis (§1) is precise and evidenced.** The defect is
   purely in the write path (lines 1316–1339), not in the solve. The
   consequences (UNCHAINABLE, missing DTT, baked-in convention) are
   enumerated with measurements.

2. **R2's L/H storage is genuinely convention-free.** Verified against the
   fixpoint code — no pin rule contaminates the iteration. The decoupling
   from Wave 1 task 1 is real, not aspirational.

3. **The acceptance criteria (§4) are falsifiable with baselines.** Each A
   criterion states what a WRONG answer scores, and each today's-v1 score
   is honest (where it can be checked against the code, it matches).

4. **The F2 byte-budget gate moves discovery to design time.** A wasted
   4-hour wall-clock session after R9 breach would be a sprint failure;
   this gate makes it a design-time finding instead.

5. **The A1/A2 relationship is explicitly stated.** "A1 is the headline
   because it is the user-visible symptom; A2 is the soundness gate." This
   prevents a false-positive reading where A1 passes but A2 fails.

6. **The module decomposition (§5) has correct dependency arrows.** M1
   blocks M2b/M3/M4a; M2a runs off the critical path; M4a runs concurrent
   with M2b/M3. No cycles, no hidden serialisation.

7. **§6's falsification conditions are honest.** "A1 does not improve" is
   listed first — the sprint's central diagnosis could be wrong, and the
   spec pre-commits to reporting it rather than working around.

8. **The strategy's "read-only, not untouchable" [F1] carries through.**
   The old forbid-list ("may not touch") is replaced with "may be imported
   but not mutated" — the right mechanism for a reuse-not-rewrite sprint.

---

## Summary

| Grade | Count | IDs |
|-------|-------|-----|
| BLOCKER | 0 | — |
| MUST | 0 | — |
| SHOULD | 0 | — |
| COULD | 4 | COULD-1 (M2a naming), COULD-2 (ssk/psk ordering), COULD-3 (A1 PRNG), COULD-4 (passes=2 DTT gap) |

All six MUST+ findings from the pass-0 audit are resolved. The three
SHOULD/COULD findings (F7–F9) are adopted. Four COULD observations are
noted — all are implementation/briefing details, not spec defects.

**The spec is ready for human ratification (G1).**
