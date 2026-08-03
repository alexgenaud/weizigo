# T329 — spec audit gate: G3b value-correctness pass0 SPEC, Revision 1

```
Task: T329 · Role: spec audit gate · Model: kimi-k2.7-code:cloud · Date: 2026-08-03
Spec audited: docs/epic-01-markovian/sprints/g3b-value-correctness/pass0/spec.md
Revision: 1 · Commit: 2d30b56 · Status: PROPOSED
Verdict: PASS-WITH-EDITS
```

## Findings

| ID | grade | file:line | finding |
|---|---|---|---|
| F1 | must | `pass0/spec.md:455-461` vs `:113-123` | §2.2 lists **nine** carry-forward checks (I1, I2, I3, I6, I7, I8, I9, I10, I12), but §8 In scope claims **ten**. The count is inconsistent and must be reconciled. |
| F2 | critical | `pass0/spec.md:103`, `:422`, `:436` | §2.1 notes the 2×2 all-legal graph has every state cycle-reachable, so the synthetic mutant “set KO_SENSITIVE on a non-cycle-reachable slot” cannot be seeded at 2×2. Yet §7.1 schedules I5 at Rung 1 and §7.2 prescribes exactly that mutant. A calibration control that cannot be seeded makes the ladder discipline for I5 unenforceable and its 4×4 reading uncalibrated. |
| F3 | must | `pass0/spec.md:101`, `:103`, `:105`, `:225-233` | The check table marks I4 and I5 “runnable now? YES” with battery R8, and R8 itself “runnable now? YES (is the deliverable)”. R8 is a sprint deliverable that does not exist; I4 at 4×4 and I5 at all scales need it; and I11 is marked “NO” because it needs R8 + SMD1. The distinction is unexplained and inconsistent with §3 edge 4 (`I4-row (4×4) needs battery-movegen-row`). |
| F4 | must | `pass0/spec.md:57-72` | The demotion clause says violations demote `4x4.C1` and `4x4.FP1` “back to FALSE-AS-SCOPED”, but their current status is UNTESTED, not FALSE-AS-SCOPED. It also omits `GLOBAL.H4`, whose promotion target is “complete, not partial”; if I4 finds Bellman violations, H4 must be revised or retired. |
| F5 | must | `pass0/spec.md:143-145` | §2.3 item 4 and the I11 row use “deepest-N sampled states” without defining N, “deepest”, or the sampling distribution. A pass condition that relies on an undefined sampling strategy cannot be implemented or audited. |
| F6 | must | `pass0/spec.md:38-40` vs `:130-131` | §1 and §2.1 say I4 runs on the “full state graph”; §2.3 item 1 says “every non-terminal slot reachable from the fresh-start root”. These are not the same set (unreachable table slots may exist). The spec must pick one and reconcile it with the KO_SENSITIVE caveat. |
| F7 | should | `pass0/spec.md:27-29` | The sentence “The artifact is structurally complete, value-unverified” is the honest summary of the G3 split section (`PHASES.md:99-100`), not the text of the G3b row (`PHASES.md:93`). The G3b row text is the value-correctness sentence used as the “To”. Misattribution makes the framing hard to verify. |
| F8 | should | `pass0/spec.md:105` | §2.1 lists “R8 move-generator correctness” in the check inventory, but the same cell says “is the deliverable, not a check on it”. A deliverable cannot also be a check without reclassification; this creates confusion with §4 (R8 independence) and §3 edge 4. |
| F9 | could | `pass0/spec.md:194-206` | Edge 2 requires an invariant that “reproduces a known defect in the move relation”. The documented historical defects are key-encoding (T178/T193) and ko-rule (T265) errors, not a standalone move-generator defect. The examples (allow suicide, allow ko recapture) are synthetic mutants, not reproduced historical defects; the prose overclaims. |
| F10 | could | `pass0/spec.md:63` | `GLOBAL.H4` target is listed as “CLAIMED (now complete, not partial)”, but the register status vocabulary has no “more CLAIMED” level. The spec does not state whether the claim text is revised, a new ID is minted, or the status stays unchanged. |

## Verdict

**PASS-WITH-EDITS.**

The spec is a sound framing of the G3b value-correctness sprint. It is consistent with `DIRECTION.md` (dependency edges as `needs`, mutation-adequacy gate, k=1 scope), `AXIOMS.md` (ruleset R, E3 bracket semantics, NC non-claims), `PHASES.md` (the G3a/G3b split), and `sprint.md` (spec/plan/accept bookends). The goal sentence is precise, denominators are stated as violation counts, and the KO_SENSITIVE caveat correctly distinguishes measurement from violation.

The defects above are all correctable in prose. The most serious (F2, F3) affect the enforceability of the ladder discipline and the runnability matrix; they must be fixed before `plan.md` is written. No architectural change is required.

## Proposed diff

```diff
--- docs/epic-01-markovian/sprints/g3b-value-correctness/pass0/spec.md
+++ docs/epic-01-markovian/sprints/g3b-value-correctness/pass0/spec.md (edited)
@@ -24,7 +24,7 @@
 
 ## 1. The goal — the sentence it changes
 
-**From** (`PHASES.md` G3b row):
+**From** (`PHASES.md` §The G3 gate is split, honest summary):
 
 > The artifact is structurally complete, value-unverified.
 
@@ -35,8 +35,8 @@
 
 This means:
 
-- **I4 passes with zero Bellman violations** on every non-terminal slot on the
-  full state graph, where the Bellman operator Φ is computed by the battery's
+- **I4 passes with zero Bellman violations** on every non-terminal slot in the
+  reachable state graph, where the Bellman operator Φ is computed by the battery's
   independent move generator (R8), not by the solver's.
 - **C-A1 forward closure passes with zero children-missing** — every child of
   every reachable state under R is present in the table, via the kernel move
@@ -60,7 +60,7 @@
 | claim ID | current status | target status after G3b |
 |---|---|---|
 | `4x4.C1` (fresh-start scores correct at 4×4) | UNTESTED | CLAIMED (value-correctness verified by closure + Bellman) |
-| `GLOBAL.H4` (partial Bellman verification) | CLAIMED | CLAIMED (now complete, not partial) |
+| `GLOBAL.H4` (partial Bellman verification) | CLAIMED | CLAIMED — claim text updated to remove "partial"; no status change because CLAIMED is the ceiling pending Phase 3 |
 | `4x4.FP1` (L/H are least/greatest fixpoints) | UNTESTED (checks 1–2); check 3 PASSES | CLAIMED (Bellman residual = 0 verifies fixpoint property) |
 
 The seven known-unkilled mutants from `mutants.md` that invert (M1, M2, M3, M4,
@@ -68,8 +68,9 @@
 and the five dependency edges from DIRECTION Amendment 2 are satisfied for the
 claims above.
 
-On demotion: a check that finds violations demotes `4x4.C1` and `4x4.FP1` back
-to FALSE-AS-SCOPED (scoped: the specific entries are wrong), and G3b stays open.
+On demotion: a check that finds violations demotes `4x4.C1` and `4x4.FP1` to
+FALSE-AS-SCOPED (scoped: the specific entries are wrong) and revises or retires
+`GLOBAL.H4` so it no longer claims completeness; G3b stays open.
 
 ### 1.2 What this sprint does NOT claim
 
@@ -98,11 +99,11 @@
 |---|---|---|---|---|---|
 | **C-A1 forward closure** | `Z-STATE-REACH`, `Z-COMPLETE-ENUM` | **NO** — needs kernel move generator | Every child of every reachable state is in the table: `children_not_in_table == 0` | count of reachable states, total children, average branching factor | Synthetic mutant: one entry deleted → `children_not_in_table > 0` must be caught. Seeded at 2×2 first (ladder discipline). |
 | **C-A2 backward closure** | `Z-STATE-REACH`, `Z-COMPLETE-ENUM` | **NO** — needs kernel move generator | Every state reachable from the fresh-start root under R is present: `reachable_not_in_table == 0` | reachable-set size, % of colex space reachable | Synthetic mutant: same deleted-entry mutant as C-A1 — the missing entry must be flagged by both directions. |
-| **I4 Bellman residual** | `Z-CONVERGE-FIX` | **YES** — with battery's own Φ (R8) | At every non-terminal: `L ≠ Φ(L)` or `H ≠ Φ(H)` count == 0 | bracket rate, pin census, sweep-equivalent measurement | Synthetic mutant: one slot's value corrupted → Bellman violation > 0. 2×2 first. |
-| **I11 move-set consistency** | `Z-R-MOVE` | **NO** — needs SMD1 (solver-side dump) AND battery's R8 move generator | At every state in the sampled space: battery's legal-move set == solver's legal-move set, `mismatches == 0` | sample size, denominator, mismatch rate | **Null control + seeded-defect control before first reading counts** (see §4). 2×2 exhaustive first. |
-| **I5 SCC containment** | `Z-CONVERGE-FIX` | **YES** — with battery's own move graph (R8) | Every KO_SENSITIVE slot is cycle-reachable: `ko_not_cr == 0` | KO_SENSITIVE count, cycle-reachable count, KO_SENSITIVE rate | Synthetic mutant: KO_SENSITIVE spuriously set on a non-cycle-reachable slot → I5 must catch it. Per `mutants.md` M3, the current 2×2 all-legal graph has every state cycle-reachable; the mutant must be constructed at a goban size where the property fails, or the kosensitive-flag-only check must be separated from cycle-reachability. |
+| **I4 Bellman residual** | `Z-CONVERGE-FIX` | **NO** at 4×4 — needs battery R8 move generator (trivial move generator suffices at 2×2–3×3) | At every non-terminal in the reachable graph: `L ≠ Φ(L)` or `H ≠ Φ(H)` count == 0 | bracket rate, pin census, sweep-equivalent measurement | Synthetic mutant: one slot's value corrupted → Bellman violation > 0. 2×2 first. |
+| **I11 move-set consistency** | `Z-R-MOVE` | **NO** — needs SMD1 (solver-side dump) AND battery's R8 move generator | At every state in the sampled space (sample size and distribution are plan.md decisions): battery's legal-move set == solver's legal-move set, `mismatches == 0` | sample size, denominator, mismatch rate | **Null control + seeded-defect control before first reading counts** (see §4). 2×2 exhaustive first. |
+| **I5 SCC containment** | `Z-CONVERGE-FIX` | **NO** — needs battery R8 move graph generator | Every KO_SENSITIVE slot is cycle-reachable: `ko_not_cr == 0` | KO_SENSITIVE count, cycle-reachable count, KO_SENSITIVE rate | Synthetic mutant: KO_SENSITIVE spuriously set on a non-cycle-reachable slot → I5 must catch it. Per `mutants.md` M3, the 2×2 all-legal graph has every state cycle-reachable, so the first seeded-defect control runs at 3×2. |
 | **G1/G3 key agreement** | `Z-R-STATE`, `Z-STATE-KEY` | **NO** — needs kernel state-key encoder (T273 has the production one; the battery's consumer encoder is R8, needed for comparison) | Producer key == consumer key at every state: `key_mismatches == 0` | total states checked, denominator | Synthetic mutant: one bit flipped in the key → must be caught. This is the T178/T193/T265 defect family — three historical defects, zero current battery coverage. |
-| **R8 move-generator correctness** | `Z-R-MOVE` (supports I4, I5, I7, I11) | **YES** (is the deliverable, not a check on it) | The battery's independent move generator agrees with the kernel's at 2×2 exhaustive + the deepest-N 4×4 sample: `mismatches == 0` | sample size, denominator | Synthetic mutant: a known-incorrect move (e.g. ko-violating recapture allowed, suicide allowed) → must be caught. The kernel's move generator is compared against the battery's at every ladder rung. |
+| **R8 move-generator correctness** | `Z-R-MOVE` (supports I4, I5, I7, I11) | **NO** — is the sprint deliverable, not a pre-existing check | The battery's independent move generator agrees with the kernel's at 2×2 exhaustive + the sampled 4×4 space: `mismatches == 0` | sample size, denominator | Synthetic mutant: a known-incorrect move (e.g. ko-violating recapture allowed, suicide allowed) → must be caught. The kernel's move generator is compared against the battery's at every ladder rung. |
 
 ### 2.2 Checks carried forward from the battery that this sprint does NOT re-specify
 
@@ -141,7 +142,7 @@
 3. **C-A2:** 0 reachable-not-in-table — every state reachable from the
    fresh-start root via the kernel move generator is present in the table.
 4. **I11:** 0 mismatches between the battery's legal-move set and the solver's
-   at the deepest-N sampled states (the sample size is the plan.md decision;
+   at the sampled states (sample size and distribution are plan.md decisions;
    exhaustive at 2×2, 3×2, 3×3; sampled at 4×4).
 5. **Key agreement (G1/G3):** 0 mismatches between producer and consumer keys
    at every state in the sampled space.
@@ -197,8 +198,8 @@
 kernel-movegen-row needs movegen-invariant-row
 ```
 
-The extraction is licensed only by an invariant that reproduces a known defect
-in the move relation and kills its own mutant. This is the T265 test pattern
+The extraction is licensed only by an invariant that seeds a known-incorrect
+mutant in the move relation and kills it. This is the T265 test pattern
 applied to the move generator: write a differential test that compares the
 kernel's move generator against the solver's, seed a known-incorrect mutant
 (e.g. allow suicide, allow ko recapture), and verify the invariant catches it.
@@ -433,7 +434,7 @@
 - C-A2: delete one entry → reachable-not-in-table > 0
 - I11: allow a ko recapture or suicide → mismatches > 0
 - Key-agreement: flip one bit in the key → mismatches > 0
-- I5: set KO_SENSITIVE on one non-cycle-reachable slot → ko_not_cr > 0
+- I5: set KO_SENSITIVE on one non-cycle-reachable slot → ko_not_cr > 0 (first seeded-defect control at 3×2; 2×2 measurement-only because all states are cycle-reachable)
 
 A check that passes the clean artifact and fails the synthetic mutant is
 **calibrated**. A check that passes both is **blind** — its reading is
@@ -457,7 +458,7 @@
 - SMD1 (solver-side move-set dump utility).
 - Kernel move generator extraction (one function in `rules.zig`, TDD, with
   defect-reproducing invariant).
-- The ten carry-forward checks from the battery (§2.2) run as input readings,
+- The nine carry-forward checks from the battery (§2.2) run as input readings,
   not as sprint deliverables — they already exist.
 - Mutation adequacy: the seven T291 known-unkilled mutants invert to KILLED
   (M1, M2, M3, M4, M8, M9, M10).
```

## Auditor identity and method

Fresh-session document review against the governing files listed in the brief. No channel traffic, prior audits, or author framing was read before forming findings. Every finding cites a file:line range and a quotable defect. The diff above was generated by applying the proposed edits to a temporary copy and running `diff -u`.
