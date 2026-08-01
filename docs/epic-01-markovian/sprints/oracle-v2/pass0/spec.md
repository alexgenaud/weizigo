# oracle-v2 — SPEC

```
Status:   RATIFIED (G1, 2026-07-31) — pass-1 audit PASS (T135, spec.audit-2.md)
Author:   Opus/Navigator (claude-opus-5[1m]) · 2026-07-31
Revised:  Fable/Navigator (claude-fable-5) · 2026-07-31 — resolves pass-0
          audit F1–F6 (BLOCKER + 5 MUST); adopts F7 (M4 split), F8 (R8
          baseline), F9 (naming). Revised in place (original text: git show
          56950a1:docs/design/oracle-v2/pass0/spec.md; audit:
          docs/epic-01-markovian/sprints/oracle-v2/archive/spec.audit-1.md). Each resolution is
          tagged [Fn].
Process:  docs/infra/sprint.md (RATIFIED rev 4 d53c2a8; rewritten 200b974 —
          substance = DECISIONS.md D-16…D-20)
Tier:     A — new state representation + format contract + verifier changes
Audit:    this document, before any design task is dispatched
```

## 1. The problem

The 4×4 solve is correct and verified. **The artifact is not the solve.**

`src/exp6_solve.zig` computed the value of every state on the key
`(goban, side, ko_point, passes)` — 99,133,036 compact states — and Kimi-k3/T104
verified the result exhaustively: **0 / 99,133,036 Bellman violations**.

`src/exp6_solve.zig:1316-1339` then wrote the artifact through two filters:

```zig
if (passes != 0) continue;      // discards every one-pass state
if (ko != KO_NONE4) continue;   // discards every ko-pending state
```

**48,505,262 of 99,133,036 values reach disk.** The shipped key is
`(pattern, side)` — dense over `3^16` raw colex, two columns. There is nowhere
in it to record that a ko is pending or that a pass is standing.

Three consequences, all measured (channel msgs 058–060):

1. **The engine refuses the table.** `weizigo-oracle` logs `UNCHAINABLE` and
   plays a history-free fallback on **10 of 10** opening plies with the v1
   artifact, against **0 of 6** with the old PSK artifact. EXP-9's Bellman
   identity checks (A1 at the node, A2 at the chosen child) fail because a
   parent's optimal child is often a ko-pending or one-pass state whose value
   was discarded; the slice substitutes the no-ko value of the same pattern.
2. **The depth-to-terminal column was never computed** — `@memset(db, 255)` at
   `src/exp6_solve.zig:1311`, never written again. All 43,046,721 slots are
   `DTT_FAR`, in both v1 and the old PSK artifact.
3. **The cycle convention is baked in.** Only the pinned `V = median(L, 0, H)`
   is stored; `L` and `H` are discarded except for one `KO_SENSITIVE` bit. A
   different cycle convention requires a new solve.

Net: the current 4×4 engine is a **regression** against the PSK artifact it was
meant to replace, and no pin-rule result can repair it — ADR-0020's Markov key
has four components and the artifact carries two.

## 2. What to build

An artifact and a consuming engine that preserve the full Markov key, plus the
value bracket, plus a real progress measure.

**This spec does not choose the layout, the encoding, or the algorithm.** Those
are `design.md`. This document states requirements and how they will be checked.

## 3. Requirements

| id | requirement | rationale |
|---|---|---|
| **R1** | The artifact key is `(goban, side, ko_point, passes)`. No dimension is projected away. | §1 — the defect |
| **R2** | Store `L` and `H`, not a pinned `V`. The cycle convention is applied by the **reader**, not baked into the data. | one artifact answers TIE=0, no-result and score-on-cycle; decouples this sprint from the pin-rule reconciliation (Wave 1 task 1) |
| **R3** | Depth-to-terminal is **computed** during the solve and stored. | §1(2); a value table is not a policy — under TIE=0 a winning player can shuffle forever without a progress measure |
| **R4** | The format is self-describing: `rules_id`, layout version, and the key encoding documented in the format contract, not inferable only from source. | v1's projection is documented nowhere; `rules_id = 2` was written by a tool the reader did not know about |
| **R5** | The engine tracks the ko point at play time and looks up the **matching** key. | otherwise R1 buys nothing |
| **R6** | Legality enforcement is selectable at run time: `basic-ko` \| `psk` \| `ssk`. Default, mismatch behaviour, and filter semantics per §3.1 below. | the human's 2026-07-31 directive; enforcement need not be Markovian because the engine holds the history |
| **R7** | One documented command regenerates the artifact from a clean clone, byte-identical to a recorded SHA-256. | `data/` is gitignored and no `.wzo` is in history — the recipe ships, not the artifact |
| **R8** | Any relaxation of a reader/verifier check is called out explicitly in `design.md` and audited. **Baseline inventory [F8]:** the A1–A9 harness in §4 plus the reader-side checks that M1's `design.md` enumerates (that enumeration is an M1 deliverable). "Relaxation" means any weakening of a comparison, a denominator, or an expected-failure condition relative to that inventory. | the `decode` widening of 2026-07-31 went in un-audited; verifiers are where this project has been burned |
| **R10** | **passes=2 terminal contract [F6].** A `passes=2` state is a terminal: absorbing in the solve (no children generated), value `L = H =` the area score of the goban as it stands (`genericAreaScore`; captures already resolved by move application, no separate dead-stone removal), DTT `= 0`. This matches the current solver (`exp6_solve.zig:454-460`). | M2 needs the boundary condition; R3's DTT anchors at these terminals |

**Solver fixpoint convention [F5]** (addendum to R2). The existing fixpoint
maintains `L`/`H` as convention-free bracket bounds: initialised to ±n,
terminals pinned to `L = H =` area score (R10), then minimax sweeps to
convergence (`exp6_solve.zig:444-531`). No pin rule enters the iteration.
The TIE=0 pin — `V = @max(L, @min(0, H))`, `exp6_solve.zig:1329` — is a
projection applied only at v1's write path, and v2 drops it. The stored
`L`/`H` are the converged bracket bounds; states left with `L < H` are the
cycle-affected ones, and the reader selects its `V` within the bracket
(TIE=0, no-result, score-on-cycle) at load or play time.

### 3.1 R6 semantics [F3]

- **Default:** enforcement mode = the artifact's `rules_id` (basic-ko for the
  WZO2 artifact this sprint produces). Logged once at load:
  `ENFORCEMENT <mode> (artifact rules_id <id>)`.
- **Mismatch, stricter than artifact** (`psk` or `ssk` selected over a
  basic-ko artifact): **permitted.** Every psk/ssk-legal move is
  basic-ko-legal, so every reachable state has an entry; the values remain
  basic-ko values, so the optimality guarantee is void. Logged once at load:
  `ENFORCEMENT-OVERRIDE: values are <rules_id>-optimal, play filtered by <mode>`.
- **Mismatch, weaker than artifact** (selected mode permits a move the
  artifact's rule forbade): **refuse to load** — reachable states would have
  no entry, which is exactly the §1 defect reintroduced. Logged:
  `RULES-MISMATCH-FATAL`.
- **Filter semantics:** enforcement filters **both** sides. Opponent moves
  are checked at the GTP layer (illegal under the selected mode → GTP error).
  The oracle's own suggestions are filtered before play: a suggested move
  illegal under the selected mode is skipped and the next-best legal move by
  the reader's `V` is chosen; if no legal move remains, pass. The filter
  consults the oracle first, then applies legality — never the reverse.

**Out of scope**, explicitly: solving a new ruleset; the SCC-scoped memo; any
goban other than those already solved; performance work beyond the budget in
R9 below; changing the value semantics of the solve itself.

## 4. Acceptance criteria

Falsifiable, numeric, and each states what a **wrong** answer scores. Any
criterion that today's artifact passes trivially is marked so — it proves
nothing on its own.

| id | criterion | today's v1 artifact scores |
|---|---|---|
| **A1** | **Refusal rate [F4].** On random self-play with a pinned seed (recorded in the harness and in the evidence), denominator ≥ 100 oracle queries: **0** `UNCHAINABLE` refusals. The old PSK artifact is run on the identical sample and its rate reported as baseline. | **10/10 refused — FAIL** on the scripted opening. Old PSK: 0/6. This is the headline criterion. |
| **A2** | **Bellman residual = 0** on the full key, measured **after a decode round-trip**, not on the in-memory solve. Report the denominator. | untestable — the key does not exist on disk |
| **A3** | **Colour inversion, exhaustive:** `L(−pos, −side) == −H(pos, side)` and `H(−pos, −side) == −L(pos, side)` for every stored state. | untestable — `L`/`H` not stored |
| **A4** | **Pin census reported:** `L==H`, `pin_T`, `pin_L`, `pin_H`, with `pin_L == pin_H`. | never run at 4×4. The invariant whose violation (`pin_L=142, pin_H=0`) exposed the `fixpoint_kernel` bug |
| **A5** | **Round-trip identity:** `decode(encode(x)) == x` for every state, exhaustively at 2×2/3×2/3×3, sampled with a stated denominator at 4×4. | passes trivially for v1 — proves nothing about R1 |
| **A6** | **Known-bad calibration:** a deliberately corrupted artifact (one perturbed value, one dropped ko state, one zeroed DTT column) **fails** A1–A5 **or A8**, and the failure is named. *[Amendment pending G2 ratification, per M1 audit T146 NEW-6: the zeroed-DTT corruption passes A1–A5 as originally written and is detectable only by A8.]* | not run |
| **A7** | **Gate chain reproduced** from the new pipeline end to end: 2×2 = 0, 3×2 = 0, 3×3 = +9. A pipeline that cannot reproduce known anchors is not trusted at 4×4. | v1 passes — carry it forward, do not treat as new evidence |
| **A8** | **DTT is non-constant** and consistent: terminals have DTT 0, and every non-terminal's DTT exceeds at least one child's. Report the distribution. | **1 distinct value across 43,046,721 slots — FAIL** |
| **A9** | **Reproducibility:** clean clone → documented command → SHA-256 match. | never attempted |
| **R9** | **Budget:** peak RSS ≤ 4 GB (the `tools/runner` cap; the host kernel-panicked at 12.5 GB on 2026-07-29), wall ≤ 4 h, artifact ≤ 600 MB. | v1: 3.1 GB, 53 min, 258 MB |

**A1/A2 relationship** (audit Q1). A1 is the headline because it is the
user-visible symptom; **A2 is the soundness gate.** A2 passing without A1
improving is implausible; A1 improving without A2 passing is a false positive.
Neither substitutes for the other.

**Byte-budget gate [F2].** R9's 600 MB ceiling is a guess with headroom, not
a derivation — EXP-3 measured 4×4 at 51,419,046 `(goban, side, ko)` triples
over 29,497,329 distinct `(goban, ko)` addresses and projected 177 MB at
6 B/address, 354 MB *with passes folded*, which R1 forbids. Therefore:
**M1's `design.md` must derive a concrete byte budget from the chosen key
encoding, column schema, and the actual EXP-3 counts (passes NOT folded)
before M2b may begin. A derived budget > 600 MB returns the sprint to the
Orchestrator for re-scoping.** Discovering an R9 breach after a 4×4 run is a
wasted wall-clock session; this gate moves the discovery to design time.

**Artifact naming [F9].** The ratified artifact is
`data/oracle-{goban}-v2.wzo2` (this sprint: `data/oracle-4x4-v2.wzo2`).
During the sprint, all builds write to `untracked/oracle-v2/` only; the
single run that populates `data/` happens after acceptance is ratified,
per the strategy's `data/` write exemption. R7's recorded SHA-256 is taken
from the `untracked/` build; the `data/` copy is verified against that hash.

## 5. Modules — the delegable units

Five delegable units, **disjoint file ownership**, so they can be held by
different agents concurrently under the one-writer rule.

```
     M2a REFACTOR      M1 FORMAT  (blocks M2b, M3, M4a)
    (needs only the      /    |    \
     ratified spec)   M2b   M3    M4a ACCEPT-decoupled
                        \    |    /
                       M4b ACCEPT-integration
```

| id | module | owns | depends on |
|---|---|---|---|
| **M1** | **Format.** The WZO2 key encoding, column schema (`L`, `H`, DTT, flags), header, `encode`/`decode`, round-trip tests. Includes the R8 baseline inventory and the F2 byte-budget derivation. | `src/artifact2.zig` (new), `docs/epic-01-markovian/sprints/oracle-v2/format.md` (new) | — |
| **M2a** | **Fixpoint interface exposure [F1].** `src/exp6_solve.zig` has no importable interface today — its sole `pub` is `main()`; `StateIdx32` (line 266), the reachability pass, and the fixpoint are file-private. M2a marks `pub` exactly what M2b needs to obtain the converged `(L, H)` tables in memory: the state encoding (`StateIdx32`, rank/unrank, `moves32`/4×4 analogue), the reachability builder, and the fixpoint entry points. **No behavioural change.** Acceptance: v1 pipeline still builds; A7 gate chain reproduces; 3×3 v1 artifact byte-identical. | `src/exp6_solve.zig` | ratified spec only — not M1; runs concurrent with format design |
| **M2b** | **Builder.** Import the exposed fixpoint read-only; compute DTT (R3, anchored per R10); serialise the full key with no projection. **M2b does not re-solve from scratch** — the fixpoint comes from M2a's interface. | `src/oracle_v2_build.zig` (new) | M1 design ratified + M2a reviewed |
| **M3** | **Engine side.** Reader integration; track `ko_point` and `passes` at play time; full-key lookup; the §3.1 enforcement modes. | `src/gtp.zig` | M1 design ratified |
| **M4a** | **Acceptance, decoupled [F7].** The checks needing only the format contract: A3, A5, A6 fixtures, A9 recipe. Runs concurrent with M2b/M3 — the checks exist before the code they judge. | `src/oracle_v2_accept.zig` (new), `docs/evidence/ORACLE-V2/` | M1 design ratified |
| **M4b** | **Acceptance, integration [F7].** A1 (pinned-seed self-play), A2 (post-round-trip Bellman), A4 (pin census), A8 (DTT distribution). | same files as M4a (serialised by `holds=`) | M2b, M3, M4a |

**M1 blocks M2b, M3 and M4a and must not be parallelised with them.** Two
agents improvising a format concurrently is the EXP-4→EXP-7 buffer-aliasing
failure waiting to happen. M2b, M3 and M4a may run concurrently once M1's
`design.md` has passed audit. M2a needs only this spec ratified and runs
while the format is being designed.

**Read-only, not untouchable [F1]:** `src/retro.zig`, `src/oracle.zig`,
`src/rules.zig`, `src/solve.zig` may be **imported but not mutated** by any
module. `src/exp6_solve.zig` is mutated only by M2a, only as described above.
M3 touches `src/gtp.zig`, which is therefore held for the duration and must
not be given to another sprint.

**Overlap declared:** M4 duplicates invariants that `verify-battery`
(`docs/epic-01-markovian/sprints/verify-battery/pass0/spec.md`) will also implement. This is deliberate
and time-boxed — coupling the two sprints would serialise them. A later task
merges M4's checks into the battery; that task is out of scope here.

## 6. What would falsify success

Stated so the audit can check that success is not tautological:

- **A1 does not improve.** If a full-key artifact still refuses at the old
  artifact's rate or worse, then the projection was not the cause and §1's
  diagnosis is wrong. That is the single most important negative result this
  sprint can produce and it must be reported, not worked around.
- **A2 fails after round-trip while the in-memory solve passes.** Serialisation
  is lossy in a second, unidentified way.
- **R9 is breached** — the full key does not fit the budget, and the sprint
  becomes a compression problem rather than a serialisation one. The F2 gate
  exists to catch this at design time; a breach discovered later means the
  gate's derivation was wrong, which is itself a reportable finding.
- **A6 passes when it should fail** — the harness cannot detect corruption, and
  every other criterion becomes uninterpretable.
- **M2a cannot expose a usable interface without behavioural change** — the F1
  resolution was wrong; stop, new spec round (report, don't adapt).

## 7. Dependencies outside this sprint

- **Wave 1 task 1 (pin-rule reconciliation)** — *informational, not blocking.*
  R2 stores `L` and `H`, so whichever way the reconciliation lands, the artifact
  does not change; only the reader's selection rule does. If the reconciliation
  had blocked this sprint, R2 would be the wrong requirement.
- **The rule-mismatch ruling** (channel 056 §0.1) — the human's call on whether
  the player enforces the table's rule. §3.1 proposes the default (enforce the
  artifact's `rules_id`); the ruling can override the default without touching
  the build.

## 8. For the pass-1 auditor

Per `DELEGATOR.md` rule 5 you should know less than the author. Grade findings
**blocker / critical / must / should / could**; return **PASS / NEEDS-FIX /
REDO**. Write to `docs/epic-01-markovian/sprints/oracle-v2/archive/spec.audit-2.md` (done; PASS).
The original text and its audit are at `git show 56950a1:docs/design/oracle-v2/pass0/spec.md`
and `docs/epic-01-markovian/sprints/oracle-v2/archive/spec.audit-1.md` — verify each tagged
resolution `[F1]`–`[F9]` actually discharges its finding, not merely mentions it.

Questions worth asking, offered without answers:

1. **[F1]** Is M2a's `pub`-exposure refactor genuinely behaviour-preserving,
   and is its acceptance (A7 chain + byte-identical 3×3 artifact) sufficient
   to prove that? Is anything M2b needs missing from the exposed list?
2. **[F3]** Do the §3.1 mismatch rules cover every (artifact rules_id ×
   selected mode) pair, and is "stricter/weaker" well-defined for ssk vs psk?
3. **[F4]** Is A1's ≥ 100-query denominator with a pinned seed reproducible
   across machines (RNG source, seed recording)?
4. **[F5]** Is the claim that the fixpoint is convention-free consistent with
   `exp6_solve.zig:444-531`, and does R2's reader-side selection then hold for
   all three conventions?
5. **[F6]** Does R10's terminal contract match `exp6_solve.zig:454-460`
   exactly, including the DTT=0 anchor R3 depends on?
6. **[F2]** Is the byte-budget gate stated tightly enough that M1's `design.md`
   cannot satisfy it with another projection instead of a derivation?
