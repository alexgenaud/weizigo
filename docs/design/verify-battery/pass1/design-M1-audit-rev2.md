# verify-battery M1 design audit — rev 2 (re-audit)

```
Auditor:  DSPro/T151 · 2026-07-31
Subject:  docs/design/verify-battery/pass1/design-M1.md (DSPro/T149, PROPOSED rev 2)
Against:  docs/design/verify-battery/pass1/design-M1-audit-rev1.md (T147/Opus 5) ·
          docs/infra/verify-battery/spec.md (rev 1) ·
          docs/infra/verify-battery/strategy.md (rev 1)
Verdict:  PASS — 0 critical, 0 must-fix, 5 should-fix (all carry-overs from rev 1).
          Rev 1's 1 critical + 4 must-fix are all resolved.
Grading:  blocker / critical / must / should / could; PASS / NEEDS-FIX / REDO
```

## Executive summary

Rev 2 resolves all five findings that held rev 1 at NEEDS-FIX. R-C1 (the
missing §5b) is present and complete — it states the A3 consequences, names the
50-cell WZO1 reachable count, presents both options with cost estimates, and
marks the choice as a human G1/G2 item. R-C2 (the stale `exit_class` sentence)
is fixed — §2.3 now says `exit_class: "pass"` with `status` in the
parenthetical. R-M1 (I5 rule 3's wrong quantity) is corrected — rule 3 tests
`cycle_reachable` against the spread, and a note explains the distinction.
R-M2 (the arithmetically-wrong vertex formula) is deleted and replaced with a
definition-based description citing option A's 51,419,046 budget. R-M3 (I11's
uncited populations) is resolved — 3×3 and 4×3 are now "TBD in V-8". R-M4 (I7
example contradiction + duplication breaches) is fixed — the I7 fail example is
internally consistent, and no `i5_graph` / `sample_size` / `sample_seed` leak
into `value` objects.

Five should-fix items carry over from rev 1 unchanged. None has changed in
severity, and none blocks Gate 2.

**The schema is now freezable.** Gate 2 can proceed.

---

## 1. What I verified independently

Re-checked against files on disk, not against the design's assertions.

| claim in rev 2 | how checked | result |
|---|---|---|
| §3.2.3 `artifact_total: 729`, `artifact_legal_count: 489` for 3×2 | `struct.unpack` offset 12 and 20 from `artifacts/oracle-3x2.wzo` | **729** and **489** — ✓ |
| 2×2 `total: 81`, `legal_count: 57` (basis of §2.2.1 example and §5 I5 graph) | `struct.unpack` from `artifacts/oracle-2x2.wzo` | **81** and **57** — ✓ |
| 4×4 `total: 43,046,721`, `legal_count: 24,318,165` | `struct.unpack` from `data/oracle-4x4-basicko-tie-area.wzo` | **43,046,721** and **24,318,165** — ✓ |
| 4×4 file size = 258,280,358 = 32 + 6 × 43,046,721 | `wc -c` on the artifact | **258,280,358** — ✓ (design §4.3 says ~246 MB; 258,280,358 / 1024² ≈ 246.3 MiB, correct) |
| §2.3 exit-0 row reads `exit_class: "pass"` (R-C2 fix) | read from the file | **✓** — `every result has exit_class: "pass" (including results whose status is skipped or not_applicable)` |
| §5b exists and covers A3 + spec §6a (R-C1 fix) | read from the file (lines 1186–1230) | **✓** — complete, includes both options and cost estimates |
| §5 item 4 no longer has a multiplicative formula (R-M2 fix) | read from the file | **✓** — definition-based: `(board, side, ko_point)` reachable triples, option A, 51,419,046 |
| §3.6 I11 value example has no `sample_size`/`sample_seed` (R-M4b fix) | read from the file | **✓** — only `numerator`, `denominator`, `mismatches`, `mismatch_examples`, `solver_dump_path`, `note` |
| §3.6 I5 value example has no `i5_graph` (R-M4b fix) | read from the file | **✓** — removed |
| §3.6 I7 fail example `numerator` = `terminals_with_dtt_neq_0` (R-M4a fix) | compared fields in the example | **✓** — both are 16,543,210 |
| §3.6 I7 fail example `non_terminals_with_dtt_255` = 99,133,036 − 16,543,210 = 82,589,826 | computed from example values | **✓** — example says 82,589,826 |
| §2.4 stderr example matches corrected I7 numbers | compared against §3.6 I7 example | **✓** — `16543210/99133036` |
| §3.6 I5 rule 3 tests `cycle_reachable` against spread (R-M1 fix) | read from the file | **✓** — rule says `cycle_reachable matches a member of the committed spread (1,724/1,704/1,678)` with a note explaining these are cycle-reachable counts |
| §5 item 5 I11 populations at 3×3 and 4×3 (R-M3 fix) | read from the file | **✓** — `population TBD in V-8 at 3×3 and 4×3` |

---

## 2. Disposition of rev-1 findings

| # | rev-1 finding | status in rev 2 | evidence |
|---|---|---|---|
| **R-C1** | §5a settles A3/§6a silently; no L/H-dump costing | **RESOLVED** | §5b added (lines 1186–1230). States A3(a)/(b) unachievable, names 50-cell WZO1 reachable count, presents wait-for-WZO2 and L/H-dump options with cost estimates, marks as G1/G2 human agenda item. |
| **R-C2** | §2.3 exit-0 row uses non-existent `exit_class` values | **RESOLVED** | Line now reads `exit_class: "pass"` with parenthetical correctly using `status`. Verified in file. |
| **R-M1** | I5 rule 3 compares wrong quantity to spread | **RESOLVED** | Rule 3 now tests `cycle_reachable` against the spread. Note explains spread values are cycle-reachable counts, `ko_sensitive_not_cycle_reachable > 0` is the gate condition for both rules 3 and 4. |
| **R-M2** | §5 item 4 vertex formula wrong; node budget doubled | **RESOLVED** | Multiplicative formula deleted. Definition-based: `(board, side, ko_point)` reachable triples, option A per `i5-feasibility.md` §2, 51,419,046 budget cited. |
| **R-M3** | I11 sampling populations at 3×3 and 4×3 uncited and wrong | **RESOLVED** | 3×3 and 4×3 replaced with "TBD in V-8". 4×4 figure retained with provenance. I11 value example note and §5 item 5 both updated. |
| **R-M4a** | I7 fail example contradicts its own numerator rule | **RESOLVED** | `numerator: 16543210` = `terminals_with_dtt_neq_0: 16543210`. `non_terminals_with_dtt_255: 82589826` = 99,133,036 − 16,543,210. §2.4 stderr updated to `16543210/99133036`. |
| **R-M4b** | Duplication rule broken by I5 and I11 `value` examples | **RESOLVED** | `i5_graph` removed from I5 value. `sample_size` and `sample_seed` removed from I11 value. |
| **R-S1** | I6 `illegal` component name | **UNCHANGED** (should-fix) | `illegal` still 99.5% of `legal_positions_total`. Not fixed in rev 2; no change in severity. |
| **R-S2** | Per-invariant `peak_rss_mb` semantics wrong | **UNCHANGED** (should-fix) | §7 still says post-invariant HWM "captures the peak during the invariant" — monotonic HWM captures max over 1..n, not per-invariant peak. |
| **R-S3** | `invariants_requested` excludes not-applicable | **UNCHANGED** (should-fix) | Header field excludes I3/I10/I8; result records are emitted for them. Consumer mismatch persists. |
| **R-S4** | I5-only all-legal 0/0 result undefined | **UNCHANGED** (should-fix) | §6.3 states artifact loading is skipped but does not define the emitted result's status or denominator. |
| **R-S5** | Schema surface details | **UNCHANGED** (should-fix) | (a) `deviation` and `error` not in common field table; (b) trailer `peak_rss_mb` nullability unstated in table; (c) `seed` union type `u64\|string`; (d) `artifact_index` on I5 once-per-goban rows unspecified; (e) I4 WZO1 placeholder digits; (f) I2 states violation condition where invariant belongs; (g) `""` sentinel already documented — no change from rev 1. |

---

## 3. Should-fix carry-overs (no change from rev 1)

These five items were graded should-fix in rev 1 and are unchanged in rev 2.
None has increased in severity; none blocks Gate 2.

| # | finding | recommended fix |
|---|---|---|
| **R-S1** | I6 `illegal: 24,187,097` is 99.5% of `legal_positions_total: 24,318,165`. The components come from spec §I6 and T137/M2 flagged the split as uncited; freezing this field name at Gate 2 locks in the confusion. | Rename the components to what they actually count, or carry T137's flag explicitly with a note that the total is the only calibrated figure. |
| **R-S2** | Per-invariant `peak_rss_mb` is the process high-water mark, not the invariant's peak. The monotonic HWM after invariant *n* is max over 1..*n*. §7's claim that "the post-reading captures the peak during the invariant" is wrong. | Rename the field to `rss_hwm_after_mb` and state what it means, or sample the delta (`hwm_after − hwm_before`) and name it `rss_growth_mb`. |
| **R-S3** | `invariants_requested` excludes not-applicable invariants (I3, I10, I8), but result records are emitted for them with `status: "not_applicable"`. A consumer reading `invariants_requested` to know how many records to expect is off by the not-applicable count. | Add `invariants_not_applicable` to the header, or emit no records for not-applicable invariants (and lose the evaluated-cell record). |
| **R-S4** | `--i5-only --i5-graph all-legal` skips artifact loading, making I5's denominator 0 (no KO_SENSITIVE flags to examine) and numerator 0. The result status, denominator, and R3 compliance for a 0/0 ratio are undefined. | Add one paragraph to §6.3: name the mode (calibration-only), state the emitted status, explain the 0/0 denominator, and note that this run cannot settle the §6a I5 cell. |
| **R-S5(a–d)** | Schema surface that freezes at Gate 2 is incomplete: `deviation` and `error` not in §3.3's field table; trailer `peak_rss_mb` nullability not in table; `seed` union type `u64\|string` forces consumer branching; `artifact_index` value unspecified for I5 once-per-goban rows (which have no artifact). | Add `deviation` (optional), `error` (optional) to the common field table. Add nullable column to trailer field table. Consider `seed: u64` + `seed_source: "fixed"\|"auto"`. State `artifact_index` value for artifact-less rows (`0` or `null`). |

---

## 4. Acceptance criteria for should-fix carry-overs

Each carry-over item is stated as a concrete pass/fail test, independent of
implementation, that the reviewer can check post-build. The first column is a
short ID for a task tracker.

### AC-S1 — I6 field naming (owner: V-7)

| # | test | pass condition |
|---|---|---|
| AC-S1.1 | Read the I6 `value` object emitted for a 4×4 WZO1 artifact. List its top-level keys. | No key is named `illegal` unless the design's §3.6 I6 schema is amended to define what it counts and carry T137's uncited-split flag in the field's `note`. If the field is renamed, `illegal` must not appear. |
| AC-S1.2 | Sum the three components (`illegal` + `legal_both_sides` + `legal_one_side_only`). Compare to `legal_positions_total`. | The sum equals `legal_positions_total`. If renamed, the new component names make the arithmetic self-documenting without a note. |

### AC-S2 — per-invariant RSS field (owner: M1 harness)

| # | test | pass condition |
|---|---|---|
| AC-S2.1 | Run the battery with at least two invariants where the second uses more memory than the first. Examine the per-result `peak_rss_mb` (or renamed field). | The field for the lighter invariant does not report the heavier invariant's peak. If the field is `rss_hwm_after_mb`, the prose in §7 states clearly that it is a running maximum, not a per-invariant peak. If the field is `rss_growth_mb` (delta), the value for the first invariant is non-negative and the prose defines it. |
| AC-S2.2 | Check the field name in the frozen schema (§3.3 common field table). | The name does not contain the word "peak" unless the value is actually the per-invariant peak. Suggested: `rss_hwm_after_mb` or `rss_growth_mb`. |

### AC-S3 — invariants_requested completeness (owner: M1 harness)

| # | test | pass condition |
|---|---|---|
| AC-S3.1 | Run the battery on a 3×2 WZO1 artifact with default flags. Count the entries in the header's `invariants_requested` array. Count the result records emitted (excluding header and trailer). | The two counts differ by exactly the number of `not_applicable` results. The consumer can derive the total record count without guessing. |
| AC-S3.2 | Check the header record for a field that names the not-applicable invariants. | One of the following holds: (a) a field `invariants_not_applicable` lists them, (b) `invariants_requested` includes them with a separate `invariants_skipped` for `--invariants` omissions, or (c) no result records are emitted for not-applicable invariants and the design states this. |

### AC-S4 — I5-only all-legal 0/0 result (owner: M1 harness + V-9)

| # | test | pass condition |
|---|---|---|
| AC-S4.1 | Invoke `verify-battery 2x2 "" --i5-only --i5-graph all-legal`. Examine the I5 result record. | The record has `status` defined (not absent, not "error"). `value.denominator` is `0`. `value.numerator` is `0`. The design §6.3 or the result's `note` field states that `0/0` means calibration-only and this run does not settle the §6a I5 cell. |
| AC-S4.2 | Same invocation. Check the `exit_class` on the I5 result and the overall exit code. | If calibration gates pass: `exit_class: "pass"`, exit code 0. If calibration fails: `exit_class: "battery-bad"`, exit code 3. The 0/0 ratio itself is not treated as a violation. |

### AC-S5(a–d) — schema surface completeness (owner: M1 harness)

| # | test | pass condition |
|---|---|---|
| AC-S5a.1 | Run the battery with `--sample-size` on a §6a-exhaustive cell without `--allow-mode-deviation`. Examine the result record. | A `deviation` field is present. The field name is listed in §3.3's common field table with type and nullability. |
| AC-S5a.2 | Run the battery on a 4×4 artifact that triggers an I5 memory fallback. Examine the I5 result record. | An `error` object is present. The `error` key is listed in §3.3's common field table as nullable, type `object`. |
| AC-S5b.1 | Check §3.4's trailer field table. | The `peak_rss_mb` row has a nullable column (value `yes` or `no`), matching the prose "`null` if not measured". |
| AC-S5c.1 | Check the header field table (§3.2.1) for `seed`. | The type is `u64` or `string`, not a union `u64\|string`. If the auto path must be a string, it is a separate field (`seed_source: "fixed"\|"auto"`). Consumers do not branch on the JSON type of `seed`. |
| AC-S5d.1 | Invoke I5 once-per-goban (any goban). Examine the proposed-row record. | `artifact_index` has a defined value. If `null`, the field table says it is nullable. If `0`, the prose explains that 0 means "not per-artifact". The value is not absent and not undefined. |

---

## 5. Requirement and acceptance re-check

| id | rev 1 | rev 2 | note |
|---|---|---|---|
| **R3** | PARTIAL | **PASS** | I11 populations now TBD in V-8 rather than wrong — denominator honesty is restored. |
| **R6** | PARTIAL | **PASS** | R-C2 resolved — exit_class sentence in §2.3 now correct. No remaining R6 conflicts. |
| **R7** | PARTIAL | **PARTIAL** | R-M2 resolved — I5 node budget restored to option A. Per-invariant peak_rss_mb semantics still wrong (R-S2). |
| **A3** | still no | **ACKNOWLEDGED** | §5b now states plainly that A3(a)/(b) pin figures are unachievable on WZO1 and puts the resolution choice to the human. This is the correct outcome — the design doesn't silently absorb the consequence. |
| **A4** | yes, caveat | **PASS** | R-M4a resolved — I7 fail example is now internally consistent. |
| **A5** | improved | **PASS** | I4 WZO1 semantics + I5 denominator + I7 fail shape are all re-implementable. |
| **A6** | partially | **PARTIALLY** | Invocation-level peak is correct. Per-invariant field name still misleading (R-S2). |

---

## 6. Verdict

**PASS.**

Rev 2 resolves all six graded findings from rev 1 (1 critical, 4 must-fix)
completely and correctly. The §5b escalation is the right shape — it does not
decide the A3/§6a question inside the document but puts it in front of the
human, and it costs both options so the human can choose on evidence.

The five should-fix carry-overs are real but none is new, none has worsened, and
none blocks Gate 2. R-S5(a–d) (schema surface omissions) should be the highest
priority of the five — they are a one-edit addition to field tables before the
freeze, and fixing them mid-sprint would cost an unfreeze. The others can be
addressed in V-7 implementation.

This design is ready for Gate 2 ratification.

— DSPro/T151
