# verify-battery M1 design audit — rev 1 (re-audit)

```
Auditor:  Opus 5 / T147 (claude-opus-5) · 2026-07-31
Subject:  docs/design/verify-battery/pass1/design-M1.md (DSPro/V-4-rev1, PROPOSED)
Against:  docs/design/verify-battery/pass1/design-M1-audit.md (Opus 5/V-5, pass 1) ·
          docs/infra/verify-battery/spec.md (rev 1) ·
          docs/infra/verify-battery/strategy.md (rev 1) ·
          docs/design/verify-battery/pass1/i5-feasibility.md (DSPro/T134)
Verdict:  NEEDS-FIX — 1 critical, 4 must-fix, 5 should-fix.
          No blockers. Down from 2 blockers / 4 critical / 8 must / 10 should.
Grading:  blocker / critical / must / should / could; PASS / NEEDS-FIX / REDO
```

## Executive summary

Rev 1 is a substantial and mostly successful revision. Of 24 graded pass-1
findings, **17 are fully resolved**, 4 are partially resolved, and 3 are not.
Both blockers are answered in substance: B2's reference-data mechanism (§2.5,
`--reference`, versioned JSON, SHA-256 in the header, battery computes the
verdict) is exactly the recommended shape and is carried consistently through
§3.2, §3.6, §6.1 and §12; B1's schema half — the WZO1-computable set, I3/I10
`not_applicable`, I1 reduced to `L_eq_H`, I4 restricted to KO_SENSITIVE-clear
slots, §5a as a standing resolution table — is well done and is the right
answer. The new trailer record, the `mode_declared`/`mode_actual`/
`scope_once_per_goban` split, `artifact_kind`/`format`/`format_version`, the
per-artifact cell cardinality with `artifacts_in_scope`/`artifact_index`, the
typed header table with nullability, the minimal pre-load header, the fixed
seed, the `std.json` reversal, the R8 test-boundary statement, and the ordered
I5 exit rules are all correct and should ship unchanged.

**The schema — the thing Gate 2 freezes — is now sound in structure.** What
remains is not architecture. It is four classes of residue:

1. **C1 is literally unfixed.** §2.3's exit-0 row (line 91) still names
   `skipped` as an `exit_class` value and has *added* `not-applicable` — two
   values outside the enum §3.3 defines, in the one sentence the pass-1 audit
   quoted verbatim. The rev-1 notes claim C1 resolved; §3.3's mapping table
   *is* correct, so this is one stale sentence contradicting the fix beside it.

2. **B1's escalation half is missing.** The design decides, on its own, that
   I3 and I10 are `not_applicable` at all five gobans — but spec §6a marks them
   **E** at all five, and acceptance criterion **A3** demands the 3×2 and 3×3
   pin censuses (`pin_T`/`pin_L`/`pin_H`), which §5a now makes uncomputable.
   The design never mentions A3, never names the §6a conflict, and never offers
   the solver-side L/H dump alternative the pass-1 audit asked to be costed.
   "Sixty green cells" is no longer reachable and no document says so.

3. **Three factual errors about measured quantities**, all in the same class as
   pass-1's M7 — numbers implementers calibrate against. The I11 sampling
   populations (73,674 at 3×3; 2,009,694 at 4×3) match nothing committed; the
   I5 all-legal vertex formula is arithmetically wrong against the design's own
   2×2 calibration and silently doubles the memo's node budget; the I7 fail
   example contradicts its own stated `numerator` rule by 26 million.

4. **Two pass-1 findings recurred in the same shape** they were raised in: S3
   (duplicated facts) survives in the I5 and I11 `value` examples, directly
   against §3.3's new duplication rule; S10 (examples contradicting their text)
   is fixed for I11 and reintroduced for I7.

None of this is rework. It is one focused edit pass over §2.3, §3.6 (I5, I6,
I7, I11), §5 item 4, §7 and a new escalation paragraph. **NEEDS-FIX, close to
PASS** — the design would pass on the next revision if the residue below is
cleared and the A3/§6a conflict is put in front of the human rather than
settled inside the document.

---

## 1. What I verified independently

Re-checked against files, not against rev 1's assertions. Only claims that
changed in rev 1, or that rev 1's corrections depend on, were re-verified.

| claim in rev 1 | how checked | result |
|---|---|---|
| §3.2.3 `artifact_legal_count: 489` (M7a fix) | `od -A d -N 32 -t u1 artifacts/oracle-3x2.wzo`, offset 20 u64 LE = **489** | ✓ **corrected** |
| §3.2.3 `artifact_total: 729` for 3×2 | header offset 12 = 0x2D9 = 729 = 3⁶ | ✓ |
| 2×2 `legal_count` = 57 (basis of the §5 formula check) | `od` on `artifacts/oracle-2x2.wzo` offset 20 = **57** | ✓ |
| §5 item 4 all-legal vertex formula | 57 × 2 × 3 × 2 = **684**, vs the design's own committed all-seed V = **282** | ✗ **still wrong** — see R-M2 |
| §5 item 4 "~99,133,036 vertices at 4×4" | `docs/research/newrule-4x4-2026-07-28.md:99,185` — real, but it is option **B**; `i5-feasibility.md` §2 *recommends option A* (51,419,046, passes cut at ≥1) and the spec's node budget is 51,419,046 | ✗ **unreconciled** — see R-M2 |
| §3.6 I11 "3×3 population = 73,674" | committed 3×3 census: **73,758** all-passes, **49,428** non-terminal, **45,472** passes∈{0,1} (`docs/research/newrule-3x3-2026-07-28.md:114-116,124`) | ✗ **matches nothing** — see R-M3 |
| §3.6 I11 "2,009,694 at 4×3" | committed 4×3 census: 638,266 `(b,side,ko)`, **1,276,532** with passes (`docs/research/kostate-census-2026-07-28.md:22`) | ✗ **matches nothing** — see R-M3 |
| §3.6 I5 `nodes: 282`, `edges: 508`, `max_scc_size: 160` | spec §4:113 all-seed V=282, E=508, max SCC=160 | ✓ |
| §3.6 I5 `max_scc_expected` = 1,676 at 3×2 all-legal, cited to `ko-fix-rerun-2026-07-29.stdout:107` | that line reads `max size = 1676` | ✓ **citation exact** (Cf4 satisfied) |
| §3.6 I5 `cycle_reachable_expected` = 1,678 at 3×2 reachable | spec §4:120-124 — 1,678 is the true-game-root member of the spread | ✓ |
| §3.6 I5 spread 1,724/1,704/1,678 | spec §4:120-121, `ko-fix-rerun-2026-07-29.stdout:133` | ✓ values right, **wrong quantity compared** — see R-M1 |
| §3.6 I8 `denominator: 172`, `fixture_states: 24` | spec §I8:92 — "0 mismatches / 172 reachable non-terminals", 24 states | ✓ |
| §3.6 I6 components 24,187,097 / 65,534 / 65,534 → 24,318,165 | spec §I6 row; 24,318,165 = 4×4 `legal_count` = OEIS A094777 (`docs/references.md:173`) | ✓ inherited from spec — but see R-S1 |
| §3.6 I7 fail example internal arithmetic | 99,133,036 − 16,543,210 = **82,589,826** (design says 82,599,826); stated rule `numerator = terminals_with_dtt_neq_0` = 16,543,210 (design says 42,910,761) | ✗ **two contradictions** — see R-M4 |
| §4.3 4×4 file size ≈ 246 MB | `ls -la data/oracle-4x4-basicko-tie-area.wzo` = 258,280,358 B = 32 + 6 × 43,046,721 = 246.3 MiB | ✓ |
| spec §6a still marks I1/I3/I10 as **E** at all five gobans | `docs/infra/verify-battery/spec.md` §6a matrix, rev 1 | ✓ **conflict with §5a is live** — see R-C1 |
| spec A2 artifact list is all-WZO1 | all seven files are `WZO1` magic, `format_version=1` | ✓ confirms §1's WZO1 constraint |

---

## 2. Disposition of pass-1 findings

| # | pass-1 finding | status in rev 1 |
|---|---|---|
| **B1** | Value schemas require L/H columns WZO1 lacks | **PARTIAL** — (a) WZO1-computable set stated ✓, (b) I4 defined on KO_SENSITIVE-clear slots ✓, WZO2 fields defined-but-absent ✓, §5a added ✓; **(c) no L/H-dump alternative specified or costed, (d) no escalation of the §6a/A3 consequence** → R-C1 |
| **B2** | No mechanism for exit class 2 | **RESOLVED** — §2.5 `--reference` + versioned JSON + `file:line` citations + header path/SHA-256; §3.6 I1's contradicting sentence deleted; §12 states the battery computes the verdict and V-14 absorbs it |
| **C1** | `exit_class` enum incomplete; §2.3 uses values outside it | **NOT RESOLVED** — §3.3's status→exit_class mapping is now correct, but line 91 still says `exit_class` = `pass` or `skipped` or `not-applicable` → R-C2 |
| **C2** | Current RSS not peak; no invocation-level record | **PARTIAL** — VmHWM / `resident_size_max` ✓, trailer with invocation peak + exit code + counts ✓; **per-invariant `peak_rss_mb` semantics wrong** → R-S2 |
| **C3** | Cell cardinality contradictory | **RESOLVED** — per-artifact stated in §3.5, `artifacts_in_scope`/`artifact_index` added, §10 rule 2 corrected to match |
| **C4** | No `artifact_kind` before the freeze | **RESOLVED** — `artifact_kind`, `format`, `format_version` in header, result and proposed-row records |
| **M1** | `--no-fixture` / `fixture_mode` undefined | **RESOLVED** — both deleted; §6.1 states fixtures are V-10's domain |
| **M2** | I5 denominator either/or | **RESOLVED** — denominator = KO_SENSITIVE-set legal slots examined; `nodes`/`edges`/`sccs_*` explicitly demoted to graph-shape fields |
| **M3** | I5 exit rules contradictory, misattributed, incomplete | **PARTIAL** — ordered list ✓, all five gobans ✓, spec §7 cited only for 3×2-beyond-spread ✓; **rule 3 compares the wrong quantity to the spread** → R-M1 |
| **M4** | I9 lacks numerator/denominator | **RESOLVED** — anchors checked / anchors committed, `0/0` at 4×3 stated |
| **M5** | I6 `union_legal` incoherent, units mixed, OEIS presumes square | **PARTIAL** — renamed `legal_positions_total` ✓, cross-check against header `legal_count` ✓, denominator pinned to dense 3^(w×h) ✓, `oeis_legal_reference` nullable + citation ✓; **`illegal` still sums into a "legal" total** → R-S1 |
| **M6** | `mode` conflates sampling and scope | **RESOLVED** — `mode_declared`/`mode_actual`/`scope_once_per_goban`/`deviation`, stderr warning, `--sample-size` guarded by `--allow-mode-deviation` |
| **M7** | Two factual errors | **PARTIAL** — (a) 489 corrected ✓; **(b) formula replaced with a different wrong formula** → R-M2 |
| **M8** | Header has no field table or nullability | **RESOLVED** — typed table with nullability, minimal pre-load header, fixed seed 31337, `argv` added |
| **S1** | `fail` used for reference-bad | **RESOLVED** — `reference-disagreement` added, `fail` reserved for artifact-bad |
| **S2** | Naming inconsistent | **RESOLVED in substance** — the same-field collision is gone (`mode_*` uses `not-applicable`, `status` uses `not_applicable`). The rev-1 note's claim that all enum values use hyphens is false; the convention is per-field, which is fine but should be *stated* as the convention |
| **S3** | Facts duplicated between top level and `value` | **NOT RESOLVED** — §3.3's duplication rule is stated, then broken by I5's `value.i5_graph` (line 621) and I11's `value.sample_size` / `value.sample_seed` (lines 833-834) → R-M4 |
| **S4** | `std.json` ban wrongly justified | **RESOLVED** — §3.1 and §11.1 switch to `std.json` with a mandatory round-trip test over quotes/backslashes/newlines/non-ASCII |
| **S5** | Proposed rows batched | **RESOLVED** — streamed per invariant, `run_incomplete: true` on battery-bad |
| **S6** | Seed 0 = auto | **RESOLVED** — fixed 31337, `--seed auto` opt-in |
| **S7** | R8 test boundary unspecified | **RESOLVED** — separate binary, adjudicated comparison, `std` sharing acknowledged as correct |
| **S8** | `""` positional sentinel | **PARTIAL by decision** — prose is now unambiguous about when loading occurs; the `""` sentinel is retained. Acceptable as a stated choice; noted → R-S5 |
| **S9** | Line estimate low-balled | **RESOLVED** — 600–900 range, `util.out` added as the fourth subsystem |
| **S10** | Examples contradict their text | **PARTIAL** — I11 corrected to 3×3 sampled ✓, I7 split into pass and fail examples ✓; **the new I7 fail example contradicts its own rule** → R-M4 |
| **Cf1–Cf4** | provenance, R8 framing, `--version`, calibration fields | **ALL RESOLVED** — Cf4 in particular now carries `nodes_expected`, `edges_expected` and 3×2 `max_scc_expected: 1676` with an exact citation |

---

## 3. Residual findings — graded

### Critical

| # | what | detail and fix |
|---|---|---|
| **R-C1** | §5a settles, inside the design, a question the pass-1 audit reserved for the human — and the consequences for spec §6a and acceptance criterion A3 are unstated | §5a declares I3 and I10 `not_applicable` on WZO1. Spec §6a (rev 1) marks **I3: E, E, E, E, E** and **I10: E, E, E, E, E**, and defines a settled cell as one whose invariant "ran in its declared mode against every in-scope artifact". Every A2 artifact is WZO1 (verified). So §5a removes **ten** of the sixty cells from reachability, and reduces I1's five, and the spec still asserts sixty. Worse, **A3 is never mentioned in the design.** A3(a) requires `L==H=2220, pin_T=298, pin_L=34, pin_H=34` over 2,586 *and* `2232/322/34/34` over 2,622; A3(b) requires the 3×3 census `L==H=68,350, pin_T=1,248, pin_L=2,080, pin_H=2,080`. Under §5a the battery can produce `L_eq_H` and **none of the three pin figures**, at either goban. A design that makes a ratified acceptance criterion unreachable must say so in its own text. Pass-1 B1(c) also asked for the solver-side L/H dump option — the same shape as the dump I11 already assumes (`solver_dump_path`, §3.6) — to be *specified and costed* so the human can choose; rev 1 does not mention it. **Fix (document edit, not rework):** add a short subsection — "§5b: consequences for the spec and acceptance criteria" — that (i) states plainly that A3(a) and A3(b) are unachievable against the A2 artifact set, with `L_eq_H` the only reproducible component; (ii) states that spec §6a's I1/I3/I10 rows and the "sixty cells" count require amendment or a WZO2 dependency, and names the resulting reachable cell count on WZO1; (iii) presents the two options for I1/I3/I10 — wait for WZO2, or add a solver-side L/H dump — with a line-count estimate for the dump; (iv) marks the choice as a **G1/G2 agenda item for the human**, not a design decision. Everything else in B1's resolution stands. |

### Must-fix

| # | what | detail and fix |
|---|---|---|
| **R-C2** | §2.3's exit-0 row still uses two `exit_class` values that do not exist (pass-1 C1, unfixed) | Line 91: "every result has `exit_class` = `pass` or `skipped` or `not-applicable`". §3.3's enum is `{pass, artifact-bad, reference-bad, battery-bad}` and its status→exit_class table maps `skipped` → `pass` and `not_applicable` → `pass`. The mapping table is right; line 91 contradicts it and is the exact sentence pass-1 C1 quoted — rev 1 added `not-applicable` to it rather than removing `skipped`. A consumer switching on `exit_class` per §2.3 hits two undefined values on the most common non-pass path, which is precisely R6's machine-distinguishability requirement failing. **Fix:** one line — "every result has `exit_class: "pass"` (including results whose `status` is `skipped` or `not_applicable`)". |
| **R-M1** | I5 exit rule 3 compares `ko_sensitive_not_cycle_reachable` against a spread of **cycle-reachable counts** — two different quantities | §3.6: "`ko_sensitive_not_cycle_reachable > 0` at any goban whose value matches a committed spread (3×2: 1,724/1,704/1,678) → `reference-bad`". Verified: 1,724/1,704/1,678 are **cycle-reachable set sizes** under three seeding conventions (spec §4:120-124; `ko-fix-rerun-2026-07-29.stdout:133` reads `cycle-reachable = 1704`). `ko_sensitive_not_cycle_reachable` is the count of KO_SENSITIVE flags *outside* that set — a residual, expected 0, and it will never equal 1,724. As written, rule 3 can never fire, so every 3×2 disagreement falls through to rule 4 and escalates as artifact-bad under spec §7 — inverting the pass-1 M3 fix. **Fix:** rule 3 should test the *cycle-reachable count* (`value.cycle_reachable`) against the spread and classify the run `reference-bad` when it matches a non-preferred member of the spread; the KO_SENSITIVE residual keeps its own rule. State both quantities in the rule text so the distinction survives into V-9. |
| **R-M2** | §5 item 4's replacement vertex formula is arithmetically wrong against the design's own calibration, and silently adopts a node budget the I5 memo argued against (pass-1 M7b) | Line 1115: "vertices = legal positions × 2 (sides) × 3 (ko_points: NONE, black's last, white's last) × 2 (passes ∈ {0,1})". At 2×2 that is 57 × 2 × 3 × 2 = **684**; the very next sentence gives the committed all-seed V = **282**. The "× 3 ko_points" factor is also wrong in kind — the ko point ranges over board points plus NONE (up to w×h+1), not over "whose last". Separately, "~99,133,036 vertices at 4×4" is a real committed number (`newrule-4x4-2026-07-28.md:99`) but it is **option B** of `i5-feasibility.md` §2; the memo's stated recommendation is **option A** — `(board, side, ko_point)`, 51,419,046 vertices, pass edges cut at ≥1 — and 51,419,046 is the node budget the spec carries. Rev 1 doubles the I5 node count with no note, no citation of which option was chosen, and no corresponding change to §7's 4 GB prediction — on the exact axis that produced the 2026-07-29 kernel panic. **Fix:** delete the multiplicative formula (it does not hold at any goban); state the node set by definition, name the option chosen, cite `i5-feasibility.md` §2 and §9, and reconcile §7's memory prediction with whichever budget is adopted. If option B is intended, say why the memo's recommendation is being overridden. |
| **R-M3** | I11's sampling populations at 3×3 and 4×3 are uncited and match nothing committed — and they are R3 denominators | §3.6 and §5 item 5 give "population = 73,674 at 3×3, 2,009,694 at 4×3, 99,133,036 at 4×4". The 4×4 figure is real. The other two appear **nowhere else in the repository**. The committed 3×3 census gives 73,758 (all passes), 49,428 (non-terminal), 45,472 (passes∈{0,1}) — 73,674 looks like a transposition of 73,758 but is none of the three. The committed 4×3 census gives 638,266 `(b,side,ko)` and 1,276,532 with passes; 2,009,694 is neither. R3 requires every reported number to state its denominator, and these *are* the denominators V-14 will absorb for the three sampled I11 cells. **Fix:** pick the population by definition (which state set is I11 sampling from — legal `(position, side)` slots, or the compact `(b, side, ko, passes∈{0,1})` set?), take the number from the committed census, and cite it `file:line`. If no committed figure exists for the chosen definition, say the figure is TBD in V-8 rather than supplying one. |
| **R-M4** | Two pass-1 defects recur in the same shape: the I7 fail example contradicts its own rule (S10), and the duplication rule is broken by two `value` examples (S3) | **(a) I7 fail example** (lines 731-744): the text two paragraphs down states "**`numerator`** = `terminals_with_dtt_neq_0`"; the example sets `numerator: 42910761` and `terminals_with_dtt_neq_0: 16543210` — a 26-million discrepancy, propagated into §2.4's stderr example (`FAIL I7 artifact-bad … 42910761/99133036`, line 120). Also `non_terminals_with_dtt_255: 82599826` should be 99,133,036 − 16,543,210 = **82,589,826** if the column is uniform, which is what the example asserts. A4 turns on this fail shape and V-11 re-implements against it. **(b) Duplication rule** (§3.3, lines 378-380): "The top-level fields (`seed`, `sample_size`, `sample_denominator`, `mode_actual`, `i5_graph`) are authoritative; the `value` object does not duplicate them." I5's `value` carries `"i5_graph": "all-legal"` (line 621); I11's carries `"sample_size": 500` and `"sample_seed": 31337` (lines 833-834). The rule and the examples cannot both be frozen. **Fix:** recompute the I7 fail example from a single consistent scenario and re-derive the §2.4 stderr line from it; delete `i5_graph` from I5's `value` and `sample_size`/`sample_seed` from I11's. |

### Should-fix

| # | what | detail |
|---|---|---|
| **R-S1** | I6's `illegal` component still sums into `legal_positions_total` | The rename fixed the name of the total (and the new cross-check against header `legal_count` is a genuine improvement — verified: 24,318,165 is the 4×4 `legal_count`). But the note still asserts `legal_positions_total = illegal + legal_both_sides + legal_one_side_only`, and 24,187,097 + 65,534 + 65,534 does sum to it — so a quantity named `illegal` is 99.5% of a quantity named "legal positions total", and `illegal + legal_positions_total` = 48.5M against a 43.0M address space. The components come from the spec's I6 row, and T137/M2 already flagged that split as uncited; rev 1 propagates it into a field name that freezes at Gate 2. **Fix:** either rename the components to what they actually count, or carry T137's uncited-split flag explicitly in the design and defer the component names to V-7 with a note that the total is the only calibrated figure. |
| **R-S2** | Per-invariant `peak_rss_mb` is the process high-water mark, not the invariant's peak | §7:1219-1223: "the post-invariant reading is recorded as `peak_rss_mb` in the result record (the HWM is monotonic, so the post-reading captures the peak during the invariant)". Monotonicity gives the opposite conclusion — VmHWM after invariant *n* is the maximum over invariants 1..*n*, so every invariant after the heaviest one reports the heaviest one's peak. A6 asks for peak per invariant; this delivers a running maximum. The invocation-level trailer figure is correct and is the one A6 most needs. **Fix:** either rename the per-result field to `rss_hwm_after_mb` and say what it means, or sample the delta (`hwm_after − hwm_before`, floored at 0) and name it `rss_growth_mb`. Do not leave a field named "peak RSS during this invariant" that is not that. |
| **R-S3** | `invariants_requested` excludes not-applicable invariants, but result records are emitted for them | §3.2 defines the field as the list "after resolving `--invariants`, `--i5-only`, and the §6a applicability matrix", and §3.2.3's 3×2 example lists 9 entries (I3/I10/I8 absent). But §3.3 defines `status: "not_applicable"` as a result status, §3.5 requires proposed rows for those cells, and §3.4's trailer example counts `not_applicable: 3`. So a consumer that reads `invariants_requested` to know how many result records to expect will be wrong by exactly the not-applicable count. **Fix:** either emit no records for not-applicable invariants (and lose the "which cells were evaluated" record §3.5 wants), or add `invariants_not_applicable` to the header — the second is cheaper and preserves both. |
| **R-S4** | `--i5-only --i5-graph all-legal` yields a 0/0 I5 result and the design does not say so | §2.2 and §6.3 state that this combination skips artifact loading entirely. §3.6 pins I5's denominator to "total KO_SENSITIVE-set legal slots examined" — with no artifact there are no flags, so denominator = 0, numerator = 0, and the invariant tests only its own calibration gates. That is a legitimate and useful mode (it is the Tarjan self-check), but the record it emits is undefined: `status`? `value.denominator: 0`? R3 compliance of a 0/0 ratio? **Fix:** one paragraph in §6.3 — name the mode (calibration-only), state the emitted status and the 0/0 denominator explicitly, and note that such a run cannot settle the §6a I5 cell. |
| **R-S5** | Schema surface details that freeze at Gate 2 with the rest | (a) `deviation` and the `error` object appear only in prose and examples — neither is in §3.3's common field table, so the frozen field list is incomplete. (b) §3.4's trailer table gives `peak_rss_mb` type `f64` with "`null` if not measured" in the prose and no nullable column. (c) `seed` is typed `u64\|string` — a union type in a frozen schema forces every consumer to branch; consider `seed: u64` plus `seed_source: "fixed"\|"auto"`. (d) `artifact_index` is `u8` non-nullable, but I5's once-per-goban row has no artifact — its value is unspecified. (e) I4's WZO1 example uses placeholder digits (`98765432`, `123456`, which sum to 98,888,888 ≠ 99,133,036) without marking them illustrative; per pass-1 M7's own rationale, examples are read as calibration. (f) §3.6 I2 states the WZO1 check as `V(-pos,-side) != -V(pos,side)` — that is the violation condition written where the invariant belongs. (g) S8's `""` sentinel is retained; acceptable as a stated decision, but say in §2.1 that it is a deliberate contract rather than leaving it as a workaround. |

---

## 4. Requirement and acceptance re-check (deltas only)

| id | pass 1 | rev 1 | note |
|---|---|---|---|
| **R2** | NEEDS-FIX | **PASS** | `--no-fixture` deleted; fixtures cleanly assigned to V-10 |
| **R3** | NEEDS-FIX | **PARTIAL** | I5 and I9 denominators fixed, I6 units fixed; I11's 3×3/4×3 populations are uncited and wrong (R-M3) |
| **R5** | NEEDS-FIX | **PASS** | `mode_declared`/`mode_actual`/`scope_once_per_goban`/`deviation` + guarded `--sample-size` is a complete answer |
| **R6** | BLOCKED | **PARTIAL** | Class 2 now has a mechanism (B2 resolved); named failure output specified in §2.4 ✓; the `exit_class` enum contradiction survives in §2.3 (R-C2) |
| **R7** | PARTIAL | **PARTIAL** | VmHWM/`resident_size_max` correct; prediction now compares against measured headroom ✓; per-invariant peak semantics wrong (R-S2), and the I5 node budget doubled without a memory reconciliation (R-M2) |
| **R8** | PARTIAL | **PASS** | Test boundary specified as a separate adjudicating binary; `std` sharing justified; estimate carried as a range with the fourth subsystem added |
| **A1** | not yet | **yes** | §2.4's `FAIL <invariant> <exit_class> <summary>` gives fixture assertions something to match |
| **A2** | partially | **yes** | Exit code now recorded in the trailer; all seven artifacts handled |
| **A3** | **no** | **still no** | `L_eq_H` reproducible; `pin_T`/`pin_L`/`pin_H` are not, at 3×2 or 3×3. Unchanged in substance and now **unacknowledged in the design** (R-C1) |
| **A4** | yes | **yes, with a caveat** | The fail shape is stated; its worked example is internally inconsistent (R-M4a) |
| **A5** | at risk | **improved** | I4 now has WZO1 semantics (KO_SENSITIVE-clear residual) and I5 has a pinned denominator, so all three of `{I4, I5, I7}` are re-implementable — the auditor's free choice is restored |
| **A6** | **no** | **partially** | Invocation-level peak is correct and recorded in the trailer; per-invariant peak is not what the field claims (R-S2) |

---

## 5. Required before Gate 2

Blocking Gate 2 ratification:

1. **R-C1** — add the §5b consequences subsection: A3(a)/(b) unreachable, spec
   §6a I1/I3/I10 rows and the sixty-cell count require amendment, the
   L/H-dump option costed, and the choice put to the human as a G1/G2 item.
   This is the one item that needs a decision outside the document.
2. **R-C2** — one-line fix to §2.3's exit-0 row.
3. **R-M1 – R-M4** — I5 rule 3's quantity, §5 item 4's formula and node
   budget, I11's populations, the I7 fail example and the two duplication
   breaches. All four would otherwise propagate into V-7/V-8/V-9 code or into
   CLAIMS rows.

Cheaper now than after the freeze: **R-S5(a)–(d)** are literally schema
surface — `deviation`, the `error` object, trailer nullability, `seed`'s union
type, and `artifact_index` on I5 rows. Adding them to the field tables costs
one edit today and a mid-sprint unfreeze later.

Non-blocking: R-S1, R-S2, R-S3, R-S4, R-S5(e)–(g).

## 6. Verdict

**NEEDS-FIX.**

Rev 1 clears both blockers in substance and 17 of 24 findings outright. The
result schema — the artefact Gate 2 freezes — is now structurally sound:
`artifact_kind` and `format` are present before the freeze, the trailer closes
the invocation-level gap and doubles as a truncation detector, the mode split
makes a fallback downgrade impossible to mistake for a declared sample, the
reference mechanism gives exit class 2 a real path, and the WZO1 reality is
faced squarely in §5a instead of being papered over. Those are the expensive
fixes and they are done well.

What holds it short of PASS is not the architecture. It is one unfixed
sentence that the revision notes claim as resolved (R-C2), three wrong numbers
about measured quantities in a document whose examples implementers calibrate
against (R-M2, R-M3, R-M4a), two pass-1 findings that recurred in their
original shape (R-M4), a rule that can never fire (R-M1), and — the item that
actually needs someone other than V-4 — the silence around what §5a does to
spec §6a and acceptance criterion A3 (R-C1). The design chose, correctly, that
I3 and I10 cannot run on WZO1. It should not also have chosen, by omission,
that nobody needs to be told the ratified sixty-cell target and the A3 pin
census went with them.

One more revision pass clears the list. I would expect PASS on rev 2.

— Opus 5 / T147
