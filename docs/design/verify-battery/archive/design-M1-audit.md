# verify-battery M1 design audit — pass 1

```
Auditor:  Opus 5 / V-5 (claude-opus-5) · 2026-07-31
Subject:  docs/design/verify-battery/pass1/design-M1.md (DSPro/V-4, PROPOSED)
Against:  docs/infra/verify-battery/spec.md (rev 1) ·
          docs/infra/verify-battery/strategy.md (rev 1) ·
          docs/design/verify-battery/pass1/spec-audit.md (T137) ·
          docs/design/verify-battery/pass1/i5-feasibility.md (DSPro/T134)
Verdict:  NEEDS-FIX — 2 blockers, 4 critical, 8 must-fix, 10 should-fix,
          4 could-fix
Grading:  blocker / critical / must / should / could; PASS / NEEDS-FIX / REDO
          (retired sprint doc's scale, per spec header)
```

## Executive summary

The architecture is right and worth keeping: one binary parameterised by goban
and artifact, JSON Lines transport, a header record plus one result record per
invariant, a hand-owned WZO1 loader with an ordered validation procedure, a
single-function invariant interface, and exit-code aggregation owned by the
harness. The stdout/stderr split, the load-procedure ordering (magic → version
→ layout → semantics → total → size → CRC-32), the WZO2 clean-refusal, and the
error-kind taxonomy are all sound and directly satisfy their requirements. The
CRC-32 polynomial, header offsets, payload segment order, flag-bit meanings,
and DTT sentinel in §4.2 match the format on disk — I checked the header bytes
of three real artifacts, not the prose.

Two blockers stop ratification, and both are about the *result schema*, which
is the one artefact of this design that Gate 2 freezes for the sprint.

**Blocker 1: the schema is written for an artifact kind that does not exist
yet.** Every in-scope artifact under acceptance criterion A2 is WZO1, and WZO1
carries **one** value per `(position, side)` — the design's own §4.2 column
table says so (`vb`, `vw`, `fb`, `fw`, `db`, `dw`). But the §3.5 value schemas
for I1 (`pin_T`/`pin_L`/`pin_H`), I3 (`L > H` violations), I4
(`L_violations`/`H_violations`) and I10 (`TIE = median(L, TIE, H)`) are all
defined over an `(L, H)` pair the loader cannot produce. The 3×2 pin census
that acceptance criterion A3 requires the battery to reproduce was computed
*inside the solver* from in-memory L/H tables (`src/exp4_solve.zig:1033`), not
read from any artifact. As designed, four invariants cannot run against any
file the fleet run will be given.

**Blocker 2: exit class 2 has no mechanism.** Requirement R6's three-class
scheme needs the battery to decide *reference-bad* at run time, but the design
never says how a committed register figure gets into the process — and §3.5's
I1 note explicitly hands that decision to V-14 instead, contradicting §2.3.

The rest is repairable in place: a `mode` enum that cannot express the §6a
matrix's own `E·G` cell, an `exit_class` enum that §2.3 already uses a value
outside of, an I5 denominator left as an either/or in direct breach of R3, a
peak-RSS mechanism that reads current RSS instead of peak, a cell-cardinality
contradiction between §3.4 and §10, and one wrong number about a real file.

**NEEDS-FIX, not REDO.** The skeleton survives; §3.5 and the reference-figure
mechanism need rework, and blocker 1's resolution is partly a Gate 1/Gate 2
decision rather than V-4's to make alone.

---

## 1. What I verified independently

Register-citation hygiene is this sprint's standing rule, so the design's
factual claims were checked against the files, not against the documents that
assert them.

| claim in design-M1 | how checked | result |
|---|---|---|
| §4.2 header layout (32 B, offsets, LE) | `od -N 32` on `artifacts/oracle-2x2.wzo`, `artifacts/oracle-3x2.wzo`, `data/oracle-4x4-basicko-tie-area.wzo` | ✓ magic `WZO1`, `format_version=1`, `colex_layout=1`, `board_w/h`, `value_semantics=1`, `column_count=6`, `reserved=0` all as described |
| §4.2 `rules_id` values | header byte 9: `1` at 2×2/3×2, `2` at 4×4 v1 | ✓ matches `src/artifact.zig:76-77` |
| §4.2 CRC-32 = ISO-HDLC over payload | `src/artifact.zig:179,206` uses `std.hash.crc.Crc32IsoHdlc` over the payload | ✓ |
| §4.3 step 11 file size = 32 + 6 × total | 2×2 = 518 B; 3×2 = 4,406 B; 4×4 = 258,280,358 B = 32 + 6 × 43,046,721 | ✓ exact, including the two unhashed 4×4 checkpoints (same size) |
| §3.2 `artifact_sha256` for `oracle-3x2.wzo` | `shasum -a 256` vs `artifacts/SHA256SUMS:2` | ✓ `d4d22c0d…bb523` correct |
| §3.2 `artifact_legal_count: 289` for `oracle-3x2.wzo` | header offset 20 (u64 LE) = **489** | ✗ **wrong** — see M7 |
| §5.4 "all-legal = OEIS A094777 × 2 (both sides)" | 2×2 `legal_count` = 57 → 57 × 2 = 114, vs committed all-seed V = **282** (`scc2x2.py`, spec §4) | ✗ **wrong** — see M7 |
| §3.4 `depends_on` example IDs | `GLOBAL.FP1` = `docs/epistemic/CLAIMS.md:243`; `3x2.C1` referenced at `docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md:132` | ✓ real claim IDs, correct shape |
| §3.5 I1 reference figures (2220/298/34/34 over 2,586) | spec A3(a) → `docs/evidence/QA-026/exp4-solve-2026-07-29.stdout:96` | ✓ matches the register |
| §3.5 I6 union 24,318,165 | 4×4 header `legal_count` = 24,318,165 = OEIS A094777 | ✓ the union is right; the split is not — see M5 |
| WZO1 carries no L/H/TIE columns | `src/artifact.zig:26-33,102-109` (six columns, `vb`/`vw` single-valued); pin census printed from solver-internal tables at `src/exp4_solve.zig:1033`, `src/exp6_solve.zig:1494` | ✓ confirms **B1** |
| WZO2 will carry L and H separately | `docs/design/oracle-v2/pass1/design-M1.md` §1, §1.1 (`key_byte L H DTT flags`) | ✓ the bracket columns arrive with oracle-v2, not before |

---

## 2. Findings — graded

### Blockers

| # | what | detail and fix |
|---|---|---|
| **B1** | The §3.5 value schemas for I1, I3, I4 and I10 require `L` and `H` columns that no in-scope artifact contains | WZO1's payload is `vb \| vw \| fb \| fw \| db \| dw` — **one** value per `(position, side)` (design §4.2, verified on disk). Under `rules_id = 2` that value is the TIE-resolved pin, not a bracket. Consequences, precisely: `L_eq_H` **is** derivable (the `KO_SENSITIVE` bit is exactly `L ≠ H` per §4.2's own flag table), but `pin_T`/`pin_L`/`pin_H` are not — they need the numeric position of TIE inside `[L, H]` (`src/exp6_solve.zig:1494`, `src/qa023_pinrule.zig:36`). **I3 (`L ≤ H`) has nothing to compare.** **I10 (`TIE = median(L, TIE, H)`) has one of its three arguments.** **I4 as written (`L = Φ(L)`, `H = Φ(H)`, fields `L_violations`/`H_violations`) has neither**; worse, a residual check on the single `V` column under `rules_id = 2` would report violations *exactly on the ko-sensitive region*, because TIE=0-on-cycles is a policy pin and not Φ-stable — a "failure" that is correct behaviour. Acceptance criterion A3(a)/(b) asks the battery to reproduce the 3×2 and 3×3 pin censuses; those numbers came from solver-internal L/H tables (`src/exp4_solve.zig:1033`), so **A3 is unachievable against the A2 artifact list as designed**. Sharpest consequence: A5 lets the acceptance auditor pick the blind re-implementation from `{I4, I5, I7}`, and I4 currently has no well-defined WZO1 semantics to re-implement. **Fix (V-4 cannot do all of this alone):** (a) state the WZO1-computable set explicitly — I2, I5, I6, I7, I8, I9, I11, I12 plus I1's `L_eq_H` — and mark the rest `not_applicable` with reason `no-bracket-columns` until WZO2; (b) define I4 on WZO1 as a residual restricted to `KO_SENSITIVE`-clear slots, or declare it WZO2-only; (c) if I1/I3/I10 must be green before WZO2, specify the source — a solver-side L/H dump, the same shape as the dump I11 already assumes (§3.5 `solver_dump_path`) — and cost it; (d) escalate the §6a matrix consequence to Gate 1/Gate 2, because the spec marks I1/I3/I10 as **E** at all five gobans and that is now known to be unsatisfiable on the current artifact set. |
| **B2** | No mechanism by which committed register figures reach the battery, so exit class 2 (reference-bad) cannot be produced | §2.3 requires the battery to exit 2 when "at least one invariant computed cleanly and disagrees with a committed register figure", and §3.3 requires the `value` object to carry "both the battery's computed value and the expected register value". But nothing in the design says where `expected_L_eq_H: 2220` or `max_scc_expected: 160` or `cycle_reachable_expected: 1678` comes from: compiled-in constants, a reference data file, a `--reference <path>` flag, or a parse of `docs/epistemic/CLAIMS.md` at run time. R4 forbids *writing* the register; reading it by `file:line` at run time would be brittle, and hard-coding is a maintenance claim that must be stated to be reviewable. Then §3.5's I1 note **contradicts §2.3 outright**: "the battery reports its own figures and the reference separately; the V-14 absorption step decides reference-bad vs pass." If V-14 decides, the battery never emits `exit_class: "reference-bad"` and never exits 2 — and R6's three-class scheme is two classes in practice. **Fix:** choose one. Recommended: a committed, versioned reference table in the battery's own tree (e.g. `data/battery-references.json`), each entry carrying value + `file:line` citation, loaded at startup, its own SHA-256 reported in the header record; the battery then computes reference-bad itself and V-14 absorbs the verdict rather than deriving it. Whatever is chosen, delete the contradicting sentence in §3.5 I1 and add the reference source to the header record. |

### Critical

| # | what | detail and fix |
|---|---|---|
| **C1** | The `exit_class` enum is incomplete and §2.3 already uses a value outside it | §3.3's field table defines `exit_class ∈ {pass, artifact-bad, reference-bad, battery-bad}`. §2.3's exit-0 row says "every result has `exit_class` = `pass` or **`skipped`**" — `skipped` is not in the enum. And `status: "not_applicable"` (I8 at 3×2+, I9 at 4×3) has **no** defined `exit_class` at all, while §3.4 requires a proposed row for exactly those cells. R6 demands machine-distinguishable classes; a consumer switching on `exit_class` hits an undefined value on the most common non-pass path. **Fix:** either add `skipped` and `not-applicable` to the enum, or make `exit_class` nullable for non-computing statuses and say so; then restate §2.3's exit-0 condition in terms that exist. |
| **C2** | Acceptance criterion A6 is not satisfiable by the stated mechanism, and no record carries the invocation-level peak | §7 says "On Linux: read `/proc/self/status` VmRSS field. On macOS: `task_info` with `MACH_TASK_BASIC_INFO` → `resident_size`." Both are **current** resident set size, not peak. Sampling "before and after each invariant" therefore misses any peak *inside* an invariant — precisely the I5 Phase 3 and I4 sweeps that A6 exists to bound, and precisely the shape that made the host kernel-panic on 2026-07-29. The peak fields are `/proc/self/status`'s **`VmHWM`** and `mach_task_basic_info.resident_size_max`. Separately, A6 asks for peak RSS **per invocation**; the design reports it per invariant only, and the header record (first line, emitted before anything runs) cannot carry it. A2 likewise asks for "exit codes … recorded per invocation", and the exit code appears nowhere in the data stream. **Fix:** read the high-water fields; add a **trailer record** (`"kind": "trailer"`) as the last line carrying invocation `peak_rss_mb`, total `duration_ms`, the final exit code, and per-class result counts. A trailer also gives consumers a truncation detector: no trailer ⇒ the run died. |
| **C3** | Cell cardinality is contradictory: `(invariant, goban, artifact)` vs `(invariant, goban)` | §1 and §3.4's opening sentence both say one record per **`(invariant, goban, artifact)`** cell; §10 rule 2 says one proposed row per **`(invariant, goban)`** cell. The §6a matrix is 12 × 5 = 60 = `(invariant, goban)`, but A2 puts **three** artifacts in scope at 4×4, and spec §6a's settled definition requires the invariant to have run "against every in-scope artifact for that goban". So for cell (I7, 4×4) V-14 receives either one row or three, undefined — and no field expresses the aggregate. **Fix:** state that result records and proposed rows are **per artifact** (they already carry `artifact` and `artifact_sha256`), that a §6a *cell* is an aggregate over artifacts computed by V-13, and add the artifact-set coordinate to the proposed row (e.g. `artifacts_in_scope: N`, `artifact_index: i`) so V-14 can tell a complete cell from a partial one. Then fix §10 rule 2 to match. |
| **C4** | No `artifact_kind` field, though strategy §3 requires the schema to take it as an input — and the schema freezes at Gate 2 | Strategy rev 1 §3: "V-4's schema takes artifact kind (pinned-V vs bracket) as an input, so the battery runs against WZO2 the day it exists." The design instead handles WZO2 by refusing it (§4.4, correct as a *loader* scope boundary) and asserts "the schema anticipates bracket columns" (§4.4) without a single field expressing the distinction. Combined with B1, the schema cannot even record *which* kind produced a result. Because Gate 2 freezes the schema for the sprint, this omission costs a mid-sprint unfreeze. **Fix:** add `artifact_kind: "pinned-v" \| "bracket"` to the header, result and proposed-row records now, with `pinned-v` the only value the v1.0.0 loader emits; and add `format: "WZO1"` + `format_version` alongside it. Cheap now, expensive after Gate 2. |

### Must-fix

| # | what | detail and fix |
|---|---|---|
| **M1** | `--no-fixture` and `CheckOptions.fixture_mode` are undefined behaviour, and the undefined behaviour is the **default** | §2.2: "`--no-fixture` … Skip known-bad fixture validation (for production fleet runs). Fixture runs are the default during development." Nothing in the document says what "fixture validation" *does*: run each invariant against a fixture artifact before the real one and abort if it passes? Load a fixture from where? Fail with which exit class? §6.1 passes `fixture_mode: bool` into every invariant with no contract. R2 and A1 place the known-bad fixtures in M5/V-10, not in the harness's default path, so a flag that changes default behaviour toward an unspecified extra run is a hazard in both directions — and `--no-fixture` on the fleet run disables whatever self-check it was. **Fix:** either specify the mode fully (fixture source, ordering, exit semantics, what it emits) or delete the flag and the `CheckOptions` field and leave fixtures entirely to V-10's harness invocations. |
| **M2** | I5's denominator is left as an either/or, breaching R3, and the worked example matches neither candidate | §3.5 I5: "`denominator`: total KO_SENSITIVE flags checked (or total non-settled slots, whichever is the relevant population)." R3 requires every reported number to **state** its denominator; "whichever is relevant" is not a denominator, and V-14 cannot absorb a ratio whose population is decided at run time. The example then sets `denominator: 508` while carrying `ko_sensitive_flags: 203`, `nodes: 282`, `edges: 508` — 508 is the **edge count** of the 2×2 all-seed graph (spec §4 calibration), so the example's denominator is neither candidate. The loose phrasing is inherited from `i5-feasibility.md` §6.5 ("or similar denominator"); M1 is where it must be pinned. **Fix:** define the population once — recommended: `denominator` = number of `KO_SENSITIVE`-set legal slots examined, `numerator` = how many of those are not cycle-reachable — and move `nodes`/`edges`/`sccs_*` to clearly-named graph-shape fields that are not the ratio. |
| **M3** | I5's `exit_class` rules contradict each other at 3×2, misattribute spec §7, and omit two gobans | §3.5's "I5 exit_class rules (special)" lists both "`ko_sensitive_not_cycle_reachable > 0` at 2×2/3×2 → **artifact-bad**" and "> 0 at 3×2 that matches a known spread → **reference-bad**". Both fire at 3×2; no precedence is given. The fourth rule says "> 0 at 4×4 → artifact-bad (finding larger than sprint — spec §7)", but spec §7's larger-than-sprint case is **3×2 beyond the 1,724/1,704/1,678 spread**, not 4×4 — the citation is misapplied. 3×3 and 4×3 have no rule at all. **Fix:** one ordered rule set — specific-before-general, spread-match ⇒ reference-bad, everything else ⇒ artifact-bad, all five gobans covered — and cite spec §7 for the 3×2-beyond-spread escalation only. |
| **M4** | I9's `value` object has no `numerator`/`denominator`, contradicting §3.5's own opening rule and R3 | §3.5 opens: "Every invariant's `value` object has at minimum `{numerator, denominator}`." I9's schema is `{expected_root, actual_root, match, reference_citation, note}`. R3 is a standing rule, and I9 is one of the invariants whose result feeds a CLAIMS row. **Fix:** give I9 a denominator that means something (anchors checked / anchors committed, i.e. `1/1` where an anchor exists, `0/0` at 4×3) or amend the opening rule to name I9 as the deliberate exception with its reason. Silent exceptions to a standing rule are how R3 erodes. |
| **M5** | I6's `union_legal` is incoherent as named, mixes units with its own denominator, and `oeis_a094777` presumes a square goban | The example computes `union_legal: 24318165` = `illegal` (24,187,097) + `legal_both_sides` (65,534) + `legal_one_side_only` (65,534). A union of *legal* things that includes the illegal count is not a union of legal things; whatever identity the spec's I6 row is asserting, this field name misstates it, and V-14 will absorb the field name into a claim. Second, `denominator: 99133036` is the **compact slot** count `(position, side, passes ∈ {0,1})` while the three components are counts over the **dense 3¹⁶ position** space — the ratio `numerator/denominator` mixes units and is meaningless. Third, `oeis_a094777` hard-codes a sequence defined for **n×n** boards; the 3×2 and 4×3 cells have no A094777 target (verified: `legal_count` = 57 at 2×2, 489 at 3×2, 24,318,165 at 4×4 — only the square cases are A094777 entries). Note the T137 spec audit's M2 already flagged the component split as uncited; M1 propagates it into a frozen field name. **Fix:** rename to what the arithmetic is (`legal_positions_total`, with the components that actually sum to it), state the population of every I6 count in one unit, and rename `oeis_a094777` → `oeis_legal_reference` with a nullable value and a citation field. |
| **M6** | The `mode` enum conflates the sampling axis with the scope axis, so the §6a matrix's `E·G` cell is inexpressible — and a memory fallback silently reads as a declared sample | §3.3: `mode ∈ {exhaustive, sampled, once-per-goban, not-applicable}`. §6a marks I5 as **`E·G`** — exhaustive **and** once-per-goban, two independent attributes. The design's error example duly emits `"mode": "once-per-goban"`, which loses the exhaustiveness declaration that R5 and R3 both hang on. Worse: if the i5-feasibility F3 fallback engages, I5 at 4×4 emits `mode: "sampled"`, indistinguishable from a cell that was *declared* sampled — a silent exhaustive→sampled downgrade, which is the exact failure R5 was written against ("a 4×4 sample proves nothing at 4×4 either, unless it says so"). `--sample-size` can also override an §6a-exhaustive cell with nothing guarding it. **Fix:** split into `mode_declared` (from the §6a matrix) and `mode_actual` (what ran), plus a boolean `scope_once_per_goban`; make any `mode_actual ≠ mode_declared` set a `deviation` field and force at least a stderr-named warning; reject `--sample-size` on a cell §6a declares exhaustive unless an explicit `--allow-mode-deviation` is passed. |
| **M7** | Two factual errors about real artifacts | (a) §3.2's header example gives `"artifact_legal_count": 289` for `artifacts/oracle-3x2.wzo`; the file's header at offset 20 reads **489** (`od -N 32`, u64 LE). Examples in a schema document are read as calibration by implementers. (b) §5 item 4: "all-legal = OEIS A094777 × 2 (both sides)". At 2×2, `legal_count` = 57, so that formula gives 114, while the committed all-legal (all-seed) node count is **282** — the ko-point and pass dimensions multiply the position count, which is the whole reason `i5-feasibility.md` §2 argues about graph closure. The formula understates the 4×4 graph by a large factor and would mis-size the I5 memory pre-check of §7. **Fix:** correct 489; replace the formula with the memo's node definition `(board, side, ko_point)` with passes cut at ≥ 1, and cite `i5-feasibility.md` §2 and §9. |
| **M8** | The header record has no field table, no nullability, and cannot be emitted in the cases §9 requires it | §3.3 and §3.4 both carry field-type tables; §3.2 carries only an example and prose notes. §9 then requires "header record + error result" for **invalid goban size**, **unknown flag**, and **artifact load failure** — cases in which `goban`, `artifact_total`, `artifact_legal_count`, `artifact_rules_id`, `artifact_rules_name` and often `artifact_sha256` cannot be populated. Only §6.3 mentions nullability, and only for the I5 all-legal path. The example also contradicts its own note: `"seed": 42` on a 3×2 run whose `invariants_requested` are all exhaustive per §6a, where the note says `seed` is "`null` if none are sampled". **Fix:** add a typed field table with explicit nullability for every header field, and specify the minimal header emitted on a pre-load failure (kind, battery_version, timestamp, argv echo, everything else null). |

### Should-fix

| # | what | detail |
|---|---|---|
| **S1** | `status: "fail"` for a reference-bad result is semantically wrong | §3.3: for reference-bad, "the invariant holds, but disagrees with a committed register figure". Reporting an invariant that **holds** as `status: "fail"` puts `status: fail` into a proposed CLAIMS row for a sound artifact — exactly the misreading the three-class scheme exists to prevent. Add a distinct status (`reference_disagreement`) and reserve `fail` for artifact-bad. |
| **S2** | Key/value naming is inconsistent across the schema | `mode: "not-applicable"` (§3.3 enum, hyphen) vs `mode: "not_applicable"` (§3.5 I8, underscore) — the same field, two spellings, in one document. `exit_class` values use hyphens while `status` values use underscores. Pick one convention and normalise; a `jq` filter written against the wrong spelling silently returns nothing. |
| **S3** | Fields duplicated between top level and `value` invite divergence | Top-level `seed`/`sample_size`/`sample_denominator` vs I11's `value.sample_seed`/`value.sample_size`; top-level `mode` vs I11's `value.mode`; header `i5_graph` vs I5's `value.i5_graph`. Two writers, one fact. Give each fact one home (top level) and delete the copies. |
| **S4** | §11.1's ban on `std.json` is justified by the wrong risk | "must not depend on `std.json` for writing — `std.json.stringify` allocates" — allocation is not a budget concern at ~60 records, whereas hand-rolled JSON must correctly escape arbitrary artifact paths, `error.message` text, and `claim_text` containing quotes, backslashes and the project's `×`/`⊆` characters. That is a silent-corruption class of defect, in the instrument, which is what this sprint exists to avoid. Either use `std.json` for writing, or mandate the escaping rules explicitly plus a round-trip test (write → parse → compare) over a fixture containing quotes, backslashes, newlines and non-ASCII. |
| **S5** | Proposed rows are written only after all invariants complete, so a battery-bad run emits none | §10 rule 3 writes rows after completion "to avoid partial rows on error". But §3.4's stated purpose is to record "which cells have been evaluated and which haven't", and §9's partial-results paragraph promises results for invariants that completed. On a battery-bad run the consumer gets result records for completed invariants and **zero** proposed rows — the cells that did complete look unevaluated. Emit rows for completed invariants with an explicit `run_incomplete: true`, or state plainly that proposed rows require exit ∈ {0,1,2} and that V-13 must re-run. |
| **S6** | `--seed 0 (auto)` makes the default non-reproducible for an evidence-producing instrument | "0 = derive from PID + time" means the default fleet invocation of a sampled cell cannot be replayed from its recorded arguments alone (the used seed is reported, so it is recoverable *after* the fact — but a default of nondeterminism in a Tier-A instrument is the wrong way round). Also seed 0 becomes unrequestable. Default to a fixed documented seed; make `--seed auto` the explicit opt-in. |
| **S7** | The R8 boundary for tests and calibration is unspecified, and §4.1 invites a breach | §4.1: "The battery's loader MUST produce identical results to `src/artifact.zig`'s `decode()` … Verification: round-trip … against the reference loader in V-10". Taken literally, a V-10 test file imports `src/artifact.zig` next to the battery's own loader — R8 says the battery imports nothing from `src/`, and a test that lives in the battery's tree is the natural place to put it. State that the comparison runs in a separate binary that is not part of the battery, and that a disagreement is **adjudicated** (either side may be wrong) rather than auto-resolved toward `src/`. Otherwise the one place R8 buys nothing becomes the place R8 is quietly dropped. |
| **S8** | `--i5-only --i5-graph reachable` contradicts the flag table, and `""` as a positional sentinel is a poor contract | §2.2's flag table says `--i5-only` means "no artifact required" and "skips artifact loading"; the following prose says an artifact IS loaded for `--i5-graph reachable` and for flag checks. §6.3 says only `--i5-only --i5-graph all-legal` skips loading. Then the mutual-exclusion note tells the caller to pass the empty string as the artifact argument. Make `<artifact>` an optional positional (or a `--artifact` flag), and state the one rule: the artifact is loaded unless the selected invariant set needs none. |
| **S9** | §4.1's ~600-line estimate silently takes the low bound of the T137 audit's range and reframes its conclusion | The spec audit's S1 estimated **~700** lines (loader 200–400, colex ~100, rules ~300) ≈ 35%. §4.1 takes 200/100/300 = 600 ≈ 30% and attributes the framing to "spec audit S1". Carry the range (600–800, ≈30–40%) and cite it as a range — Gate 1 is weighing exactly this cost. The table also omits a fourth re-implemented subsystem: `src/util.zig`'s `out(...)` stdout discipline (AGENTS.md:97) is likewise off-limits under R8 and must be re-written. |
| **S10** | Two §3.5 examples contradict their own surrounding text | I7's example carries `terminals_total: 0` (there are terminals), `non_terminals_with_dtt_255` equal to the full denominator (which would make every slot a non-terminal), and `uniform_count == denominator` with `numerator: 0` — while the paragraph immediately below says those same values mean `status: "fail"`. I11's example shows `mode: "sampled"`, `sample_size: 500` over `denominator: 2622` (the 3×2 population) while its own `note` says "exhaustive at 2×2/3×2" — the example demonstrates a run §6a forbids. Replace both with examples consistent with the §6a matrix, and give I7 a separate pass example and fail example since A4 turns on the fail shape. |

### Could-fix

| # | what | detail |
|---|---|---|
| **Cf1** | §3.2's `artifact_rules_id` note cites `src/artifact.zig` for the semantics | Harmless as provenance, but §4.2 is the battery's own independent specification of exactly this field — cite §4.2 and keep the R8 boundary visible in the document's own cross-references. |
| **Cf2** | §4.2's "no text is copied from `src/artifact.zig`" is unverifiable and beside the point | For a wire format, faithfulness beats novelty — an independently-worded but *wrong* header table is strictly worse than a copied correct one. Say what R8 actually buys here: the **decoder** shares no code, so a decode defect cannot be common-mode. (Note the design does share `std.hash.crc.Crc32IsoHdlc` with `src/artifact.zig:179` — correctly, and worth stating rather than leaving as an implicit exception.) |
| **Cf3** | No `--version` flag | `battery_version` appears only inside the header record, so a fleet script cannot check the binary before running it. One line. |
| **Cf4** | I5's `calibration` object omits committed targets the spec calls load-bearing | It carries `max_scc_expected` and `cycle_reachable_expected` only. Spec §4 commits V/E as well (2×2: 255/434 true root, 282/508 all-seed; 3×2: 2,583/5,510 true root, 2,622/5,668 42-seed) and calls **max SCC at 3×2 = 1,676** "the single most important gate before 4×4" — the `index`/`lowlink` slip that first reported 7. Add `nodes_expected`, `edges_expected`, and the 3×2 `max_scc_expected: 1676`, each with its citation, so the gate is checked by the instrument and not by a reader. |

---

## 3. Requirement-by-requirement

| id | grade | notes |
|---|---|---|
| **R1** | PASS | One binary, `verify-battery <goban> <artifact>`; goban parsed at startup and threaded through §5's six parameterisation points. Correct. |
| **R2** | **NEEDS-FIX** | The only harness-side mechanism is `--no-fixture`, whose behaviour is undefined (M1). R2's substance lives in V-10, but the flag must either mean something or go. |
| **R3** | **NEEDS-FIX** | Denominators are structurally present (`numerator`/`denominator`, `sample_denominator`), which is the right shape — but I5's is an either/or (M2), I9's is absent (M4), and I6's mixes units (M5). |
| **R4** | PASS | The battery writes only `--output` and `--proposed-rows`; `evidence_path` points at V-13's file and the battery does not write it. §12 correctly assigns absorption to V-14. |
| **R5** | **NEEDS-FIX** | §5 and §6.1 resolve applicability from the §6a matrix — right mechanism — but `mode` cannot express `E·G`, a fallback downgrade is indistinguishable from a declared sample, and `--sample-size` can override the matrix unguarded (M6). |
| **R6** | **BLOCKED** | Three classes are defined, ordered, and machine-distinguishable by exit code, with a stated precedence and rationale — the design's strongest section. But class 2 has no mechanism and §3.5 contradicts §2.3 (B2), and the `exit_class` enum is incomplete (C1). The "named failure" half of R6 is also unspecified: no stderr failure-line format is given, though A1 requires the failure to name the invariant and `i5-feasibility.md` §6.5 asserts a specific message. |
| **R7** | PARTIAL | §8 correctly declines to self-throttle and assigns pacing to Orcha with the human as backstop; single-threaded per invocation is right. But A6's measurement reads current RSS, not peak (C2), and §7's pre-Phase-3 prediction is described without stating what it is compared against (`VmHWM` headroom? total system memory? the 4 GB cap?). |
| **R8** | PARTIAL | The three re-implemented subsystems are named and costed, the independence rationale is carried, and §11.3's build links no solver objects — good. Under-specified at the test/calibration boundary (S7), low-balled in the estimate (S9), and missing the `util.out` re-implementation (S9). Note the battery's own files living under `src/` is fine — R8 is about importing solver modules, not about directory names — but say so, because "none imports from `src/`" (§6.2) is literally false of `src/vb_common.zig`. |

## 4. Acceptance-criterion reachability under this design

| id | reachable? | notes |
|---|---|---|
| **A1** | not yet | Fixture behaviour undefined (M1); no specified named-failure output for a fixture assertion to match. |
| **A2** | partially | The loader handles all seven in-scope files (size arithmetic verified, including the two unhashed 4×4 checkpoints); exit codes are not recorded in the data stream (C2); four invariants cannot run at all (B1). |
| **A3** | **no** | The 3×2 and 3×3 pin censuses require L/H that WZO1 does not carry (B1). This is the criterion B1 kills outright. |
| **A4** | yes | I7 is computable from `db`/`dw` alone, the fail shape is stated, and §3.5 names the v1 outcome explicitly. Fix S10's contradictory example and this is the design's soundest invariant. |
| **A5** | at risk | The auditor picks from `{I4, I5, I7}`; I4 has no defined WZO1 semantics (B1) and I5's denominator is undefined (M2), leaving I7 as the only safely re-implementable choice — which narrows a criterion whose whole point was the auditor's free choice. |
| **A6** | **no** | Current-RSS reads, no invocation-level peak record (C2). |

## 5. Answers to the design's §13 questions

**1. JSON Lines vs a line protocol.** Keep JSON Lines. The deciding argument
is not `jq` or readability, it is that Gate 2 freezes this schema for the
sprint: JSON tolerates additive fields, so C4's `artifact_kind`, C2's trailer,
and M6's `mode_declared`/`mode_actual` can arrive without breaking a consumer,
whereas a positional tab-separated format re-numbers every column and silently
mis-parses old files. Emission cost is irrelevant at ~60 invocations × ~13
records. Accept the escaping obligation explicitly (S4) — that is the real
cost of the choice, and it is worth paying.

**2. I5 artifact independence.** The design's handling is consistent with the
spec's intent, but it is missing the piece that makes I5 well-defined. "Reads
no stored values" means the *graph* derives from the rules engine alone; the
stored `KO_SENSITIVE` flags are the **subject** of the containment test, not an
input to the graph. Reading `fb`/`fw` is therefore correct and not a violation.
What is missing is the **projection**: artifact slots are `(position, side)`,
and per `src/artifact.zig:48-54` the `rules_id = 2` payload is specifically the
`ko == NONE, passes == 0` slice — "a stored value never knows a ko is
pending" — while the I5 graph's nodes are `(board, side, ko_point)` with passes
cut at ≥ 1 (`i5-feasibility.md` §2). The design must state which graph node a
slot maps to (presumably `ko = NONE, passes = 0`) and what "cycle-reachable"
means for a slot whose other ko-point variants may differ. Without that, M2's
denominator cannot be defined even in principle. Add it to §4.2's layout
semantics and to §6.3.

**3. Proposed rows: separate file or a `kind` in the main stream.** Separate
file, as designed — §10 rule 3's write-after-completion needs a separate sink,
and R4 hygiene is easier to argue when the register-shaped output has its own
path. But close S5's gap, or the separation costs the very record ("which cells
have been evaluated") that justifies the file.

**4. RSS prediction for I5: compile-time, run-time, or both.** Run-time, as
`i5-feasibility.md` §5.2 recommends — a compile-time gate cannot know the
host's available headroom, and the 2026-07-29 kernel panic was a host-state
failure, not a size-class failure. Make it a comparison against *measured*
headroom, not against the 4 GB constant alone, and fix the field it reads
first: predicting against `VmRSS` when you mean `VmHWM` (C2) makes the
prediction wrong in the same direction as the danger.

---

## 6. Required before Gate 2

Blocking:

1. **B1** — reconcile the value schemas with WZO1's actual columns; declare
   the WZO1-computable invariant set; define or defer I4; escalate the §6a
   consequence for I1/I3/I10 to Gate 1/Gate 2. This one needs a human
   decision, not just a document edit.
2. **B2** — specify how committed register figures enter the battery, and
   delete §3.5's sentence handing the reference-bad verdict to V-14.
3. **C1–C4** — complete the `exit_class` enum; fix the RSS mechanism and add a
   trailer record; resolve cell cardinality; add `artifact_kind` before the
   freeze.
4. **M1–M8** — as listed; M2, M6 and M7 are the ones that would otherwise
   propagate into V-7/V-8/V-9 code and into CLAIMS rows.

Non-blocking but cheaper now than after Gate 2: S1–S3 (naming and status
semantics are schema surface), C4-adjacent Cf4 (calibration fields).

## 7. Verdict

**NEEDS-FIX.**

The harness architecture, the CLI shape, the exit-class precedence with its
rationale, the load procedure, the WZO1 re-specification (verified byte-for-byte
against three real artifacts), the WZO2 refusal, and the invariant-dispatch
interface are all correct and should survive the revision unchanged. The design
is let down by its result schema, which is written for the bracket artifact
oracle-v2 has not shipped yet while its own loader section documents the
single-value artifact the fleet will actually be given — and by a
reference-figure mechanism that exists in the exit-code table and nowhere else.

Both are the kind of gap that a Gate 2 freeze converts from an edit into a
sprint-wide unfreeze, which is why they are blockers rather than must-fixes.
One revision pass should clear them; the WZO1/bracket question (B1) needs the
human at Gate 1 or Gate 2 to say whether I1/I3/I10 wait for WZO2, get a
solver-side L/H dump, or leave the §6a matrix — the auditor should not decide
that, and the design should not have to guess it.

— Opus 5 / V-5
