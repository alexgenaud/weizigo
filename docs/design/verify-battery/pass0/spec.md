> **Pass-0 snapshot (frozen).** Exact text of `docs/infra/verify-battery/spec.md`
> as graded by `spec-audit.md` in this directory (2026-07-31, verdict
> NEEDS-FIX). Revisions land in the live spec under `docs/infra/`; this copy
> does not change, so the audit's section and line references stay resolvable.

# verify-battery — SPEC

```
Status:   PROPOSED — awaiting independent audit, then human ratification
Author:   Opus/Navigator (claude-opus-5[1m]) · 2026-07-31
Process:  docs/infra/sprint.md (un-retirement proposed in channel msg 062)
Tier:     A — one instrument, run ~60 times; a defect in it is invisible
Audit:    this document, before any strategy or design work begins
```

## 1. The problem

Epic-01 closes when the epistemic tree is complete at every solved goban —
2×2, 3×2, 3×3, 4×3, 4×4. That is roughly a dozen verification questions across
five gobans: sixty cells, most of which have never been evaluated.

**The obvious way to fill sixty cells is sixty agents. That is the way this
project has already failed.**

`Opus/T102` found buffer aliasing in the brute-force cross-checks of **EXP-4
through EXP-7** — every independent implementation, agreeing with every other,
every one unsound. Many instances of one bug, all reading as corroboration.
Sixty unreviewed checkers would reproduce that at fleet scale, and sixty
agreeing runs would feel like proof.

So: **one instrument, adversarially reviewed once, invoked sixty times.** The
review of the instrument is the load-bearing work of this sprint; the runs are
cheap.

## 2. What to build

A single tool that, given a goban size and an artifact, evaluates a fixed set
of invariants and emits a machine-readable result plus proposed claim rows.

**This spec does not choose the implementation, the output format, or the
invariant algorithms.** Those are `design.md`.

## 3. Requirements

| id | requirement | rationale |
|---|---|---|
| **R1** | One binary, parameterised by goban size and artifact path. Not one tool per goban, not one per invariant. | §1 |
| **R2** | Every invariant ships with a **known-bad fixture** that it must fail. A check that has never failed has not been shown to work. | standing rule 2; `2B-5`'s positive control passed while covering none of the defective call site |
| **R3** | Every reported number states its **denominator**, including the within-budget denominator when anything is sampled. | standing rules 3 and 6; `budget-exhausted: 0` on an exponential harness is a red flag |
| **R4** | The tool **never writes** `CLAIMS.md`, `PROGRESS.md`, `CURRENT.md` or `STATE.md`. It emits *proposed* rows into its own evidence directory. | sixty concurrent writers to the register is a corrupted register, silently |
| **R5** | Exhaustive by default; sampling only where exhaustive is infeasible, and then the sample size, seed and denominator are reported. | per-goban independence means a 4×4 sample proves nothing at 4×4 either, unless it says so |
| **R6** | A failing invariant is a **non-zero exit and a named failure**, never a warning buried in output. | `stdout` = data, `stderr` = diagnostics (`AGENTS.md`) |
| **R7** | Runs within the `tools/runner` budget: ≤ 4 GB peak RSS per invocation. Concurrency is limited by **RSS, not agent count**. | EXP-6 peaked at 3,137 MB; the host kernel-panicked at 12.5 GB on 2026-07-29. **At most two 4×4-scale invocations at once.** |

**Out of scope:** deciding any claim's status; editing the register; the
SCC census (a separate measurement, Wave 1); solving anything.

## 4. The invariants

The initial set. The audit should challenge both inclusions and omissions.

| id | invariant | what it catches | precedent |
|---|---|---|---|
| **I1** | `pin_L == pin_H` | inverted-branch guards | the tell that exposed the `fixpoint_kernel` bug (`pin_L=142, pin_H=0`) |
| **I2** | colour inversion, exhaustive: `V(−pos,−side) == −V(pos,side)`; on bracket tables `L(−pos,−side) == −H(pos,side)` | sign defects | EXP-9 had one, now pinned by a test |
| **I3** | `L ≤ H` everywhere | fixpoint corruption | — |
| **I4** | Bellman residual: `L = Φ(L)`, `H = Φ(H)`, count of violations with denominator | solver and serialisation error | T104: 0 / 99,133,036 at 4×4 — make it standing, not one-off |
| **I5** | `KO_SENSITIVE ⊆ cycle-reachable` | value table vs. graph structure, reading **no** stored values | channel 054 §2 — an independent instrument on the 21.32% figure |
| **I6** | UNDEF census: illegal / legal-both-sides / legal-one-side-only, union against the OEIS legal count | serialisation holes | 4×4 v1: 24,187,097 / 65,534 / 65,534, union 24,318,165 = A094777 |
| **I7** | DTT sanity: terminals at 0, non-terminals exceed a child, distribution reported | a schema-present, data-empty column | v1 and the old PSK artifact are both uniformly 255 across all 43,046,721 slots |
| **I8** | truncation-gap fixture: the 24 known 2×2 fixpoint-vs-truncation mismatch states | semantic drift between builds | ADR-0020 mandates this as a standing fixture |
| **I9** | anchor check against published values where they exist (2×2 = 0, 3×2 = 0, 3×3 = +9) | pipeline regression | note 4×4 is **+1 vs MIGOS +2** and is an open discrepancy, not a failure |

**I5 is the one that reads no stored values.** It derives from the move graph
alone, which makes it the only invariant here that is independent of the
artifact under test. The audit should consider whether that makes it the most
valuable check in the set or a different tool entirely.

## 5. Acceptance criteria

| id | criterion | what a wrong answer scores |
|---|---|---|
| **A1** | Every invariant fails its known-bad fixture (R2), and the failure names the invariant. | an instrument that never fails is indistinguishable from one that always passes |
| **A2** | Runs to completion on all five gobans against every artifact in `data/`, with exit codes and denominators recorded. | — |
| **A3** | **Reproduces three known results**: 2×2 pin census `L==H=2220, pin_T=298, pin_L=34, pin_H=34`; 3×3 `L==H=68,350, pin_T=1,248, pin_L=2,080, pin_H=2,080`; 4×4 v1 UNDEF census in I6 above. | a tool that cannot reproduce a committed number is not measuring the same thing |
| **A4** | **Detects the v1 defects it should**: 4×4 v1 must **fail** I7 (DTT constant). | if the battery passes the artifact we already know is broken, it is not sensitive |
| **A5** | Independent re-implementation of **one** invariant — chosen by the auditor, not the author — agrees. | the only instrument that has found a defect in this project |
| **A6** | Peak RSS reported per invocation; no invocation exceeds 4 GB. | R7 |

**A4 is the sharpest criterion.** The v1 4×4 artifact is a known-bad fixture we
did not have to construct. Any battery that passes it is wrong.

## 6. Modules — the delegable units

```
   M1 HARNESS  (blocks the rest)
    /    |    \
  M2    M3     M4      (invariant groups, concurrent)
    \    |    /
      M5 FIXTURES + FLEET RUN
```

| id | module | owns | depends on |
|---|---|---|---|
| **M1** | **Harness.** CLI, artifact loading, goban-size parameterisation, result schema, denominator reporting, exit-code discipline. **No invariants.** | `src/verify_battery.zig` (new) | — |
| **M2** | **Table invariants** I1, I2, I3, I6 — read the artifact only. | `src/vb_table.zig` (new) | M1 schema ratified |
| **M3** | **Fixpoint invariants** I4, I7, I8, I9 — need the move relation. | `src/vb_fixpoint.zig` (new) | M1 schema ratified |
| **M4** | **Graph invariant** I5 — Tarjan SCC, reads no stored values. Calibrated against the committed 3×2 figure (one non-trivial SCC of 1,676) and Wave 1's `SCC-2x2`. | `src/vb_graph.zig` (new) | M1 schema ratified; Wave 1 5a/5b for calibration |
| **M5** | **Known-bad fixtures + the fleet run.** Construct the A1 fixtures; run all five gobans; emit proposed rows. | `docs/evidence/BATTERY/`, fixture files | M2, M3, M4 |

M2, M3 and M4 are concurrent once M1's result schema is ratified. **M4 should go
to whoever ran Wave 1's SCC tasks** — same instrument, and `2B-2`'s first Tarjan
reported a max SCC of 7 instead of 1,676 via an `index`/`lowlink` slip that
looked entirely plausible.

## 7. What would falsify success

- **A4 fails** — the battery passes the v1 4×4 artifact. The instrument is not
  sensitive and nothing it reports can be believed.
- **A5 disagrees** — the independent re-implementation of an invariant differs.
  Then §1's premise (one reviewed instrument beats sixty) is not yet earned.
- **I5 contradicts the stored `KO_SENSITIVE` flags at 3×2**, where both sides
  are already committed. Then either the fixpoint kernel or the cycle census is
  wrong, and that is a finding larger than this sprint.
- **The invariant set is found to be missing something the fleet then trips
  over.** Sixty green cells followed by a defect found another way means the
  battery measured the wrong things — a completeness failure, not a bug.

## 8. For the auditor

Grade **blocker / critical / must / should / could**; return **PASS /
NEEDS-FIX / REDO**. Write to `docs/design/verify-battery/pass0/spec-audit.md`.

Questions worth asking:

1. Is the §4 invariant set complete? Name what a defect could look like that
   none of I1–I9 would catch.
2. Is I5 in the right tool? It reads no artifact and needs the whole move
   graph — arguably a different instrument.
3. Does A5 (one invariant re-implemented) buy enough, or does the load-bearing
   one need re-implementing in full?
4. Is the M1-blocks-M2/M3/M4 serialisation worth its cost?
5. §1 argues one instrument beats sixty. Where does that argument break down —
   is there a class of defect that only diverse implementations would find?
