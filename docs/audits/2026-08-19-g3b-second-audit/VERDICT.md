# T474 — #2 auditor over the G3b evidence chain VERDICT

```
Task:     T474 · Set: A · Date: 2026-08-20 · Auditor: deepseek-v4-flash/T474
Mandate:  untracked/T474-second-auditor-g3b.md — audit the evidence chain behind the
          G3b discharge (remainder T-c of docs/audits/2026-08-19-L2-audit/VERDICT.md),
          not the discharge's conclusion. Per property: does the cited evidence say what
          the ruling says it says, at the denominator claimed, by the instrument named?
          Also re-check the corrected numbers in the first audit's §1 table (an auditor
          who inherits the previous auditor's table is the failure this gate exists for).
Landmark: L2 (proven 4×4 values) — remainder T-c
Bars:     read-only on source/instruments/artifacts; register what I find outside the
          mandate; repair nothing; model family differs from the first auditor
          (claude-fable-5, T467) per the standing protocol rule.
Method:   every reading checked at source (instrument code + findings record) and,
          where scale allowed, re-run on the current artifact at HEAD; one independent
          first-principles census of the artifact; denominators re-derived where possible.
```

## Ruling: PASS WITH FINDINGS — the evidence chain says what the ruling says, at the denominators claimed, by the instruments named, on all six value conditions. Three new findings (N1–N3), none verdict-changing.

**The short form.** I verified every property in the discharge chain two ways: (a) the
instrument code against its recorded run, and (b) by re-running the two most
load-bearing full-scale readings on the current artifact at HEAD — the 4×4 I5
containment check (0 / 3,455,412) and the 4×4 C-A1/C-A2 closure (0 / 616,030,190 ·
0 / 99,133,034) — plus one independent census of all 99,133,036 key bytes and a
re-run of the 4×3 I4 rung. Every recorded figure reproduces exactly, and the
denominators reconcile from first principles (my census independently recovers the
pass-edge count 50,627,774, the passes=2 count 48,505,262, and the KO_SENSITIVE
count 3,455,412 that the C-A1/I5/I4 denominators decompose into). The corrected
numbers in the first audit's §1 table are all confirmed; its F1/F2/F3 findings were
resolved by T475 on 2026-08-19 (commit cb00f0f, verified). Three new findings, all
registered, none affecting a verdict: **N1** the 4×4 I5 graph is *placement-only* —
the instrument's pass-edge path is dead (a ko=255 sentinel that can never match a
table key byte, verified by my full scan) — which makes the check *stricter* than the
"full-graph" language of accept.md claims, so the verdict survives and is conservative;
**N2** T472's Track A ruling (2026-08-19) has not been propagated to CLAIMS.md's
4x4.C1 scope-limit text; **N3** the discharge ruling's mutation line ("7 / 7 mutants
asserted killed") is an overstatement — the honest kill-verified count is 6/10 — and
the ruling table still carries the 7/7 figure against the corrected 6/10 in the same
document's §2.2 and in mutants.md.

---

## 1. Artifact identity — verified, no drift

`data/oracle-4x4-v2.wzo2` — SHA-256 `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a`,
size 518,123,097 bytes, mtime 2026-08-04 00:39 (re-verified 2026-08-20). Matches
`docs/evidence/BATTERY/baselines.json:1084`, the T310 deterministic-rebuild reference
(8/8 builds byte-identical, `docs/research/parallel-fixpoint-measurement-2026-08-03.md:86-100`),
T341's sidecar, and T472's record. My own header parse of the shipped file:
w=4, h=4, rules_id=3 (basic-ko L/H area), entry_size=4, group_header_size=5,
ko_bits=5, hdr_flags=1 (PASSES_2_OMITTED), n_groups=24,318,165, n_entries=99,133,036,
data_offset=128; file size formula 128 + n_groups×5 + n_entries×4 = 518,123,097 exactly.
The artifact every reading below depends on has not drifted.

## 2. Every property — claim vs evidence vs my verification

| property | claim (denominator) | evidence on record | my verification (2026-08-20) |
|---|---|---|---|
| I4 Bellman residual | **0 / 95,677,624** KO_SENSITIVE-clear + **0 / 3,455,412** set (measurement) + 0 cycle-boundary (T343) | `findings/T343-i4-4x4.json`: n_entries=99,133,036, clear=95,677,624, set=3,455,412, all zeros, verdict true, exhaustive | ✓ T343 findings read; instrument `src/vb_bellman_4x4.zig` `i4Bellman` (R8 move set + independent place/capture/ko + areaScore terminals; KO_SENSITIVE = stored L≠H, :711); my full-artifact census independently recovers L≠H = **3,455,412** and clear = 99,133,036 − 3,455,412 |
| I4, independent route | **0 / 99,133,036** (A2_exhaustive, T309, kernel engine) | `baselines.json:1183-1200`: stride=1, 50.6 s, note "all 99,133,036 entries" | ✓ `checkA2Inner` (`oracle_v2_accept.zig:758`) is a genuinely second Φ: kernel `rules.Rules`/`colex.Indexer` move engine vs R8; the two routes bucket differently (clear/set/cycle-boundary vs L/H/missing-child) — verdict-plus-zero-counts agreement, exactly as the first audit caveated |
| C-A1 forward closure | **0 / 616,030,190** non-terminal children over all 99,133,036 entries | `findings/T383-ko-decode.json` F-3 (245.8 s, 1124 MB); T383 independent probe agrees | ✓ **re-ran** `WEIZIGO_CLOSURE_4X4_FULL=1` at HEAD: entries_scanned=99,133,036, non_term_children=**616,030,190**, passes2=48,505,262, children_not_in_table=**0**, avg_bf=6.2142, exit 0 (259.2 s). Structural reconciliation verified two ways: 565,402,416 + 50,627,774 = 616,030,190, **and** my census measures passes=0 entries = 50,627,774 (pass edges) and passes=1 = 48,505,262 (passes2 children) — the decomposition is exact at the artifact level, not just the ledger level |
| C-A2 backward closure | **0 / 99,133,034** reachable non-terminals; 2 non-reachable (colex=0 side-mismatch pair); 32 sweeps | T383 F-3/F-4: independent probe agrees to the entry; settled-skip variant reproduces T380's 98,999,934/133,102 | ✓ **re-ran** at HEAD: reachable_non_terminal=**99,133,034**, reachable_terminal=48,505,261, reachable_not_in_table=**0**, sweeps=32; the 2 non-reachable are the enumerated empty-board side-mismatch entries; settled-skip discrepancy is a measure, not the decode (both conventions: verdict 0) |
| Key agreement | **0 / 99,133,036** (4×4, T345) · **0 / 643,378** (4×3, T363) | T345 findings; tests in `differential.zig:1360` (4×4) and `:1468` (4×3) | ✓ both tests assert 0 mismatches and the exact denominator (4×3: 643,378 = 321,689 legal positions × 2 sides, ko=NONE passes=0 slice); the same-pair caveat stands — kernel producer vs R8 consumer is the same pair I11 and I4-vs-A2 use, no from-the-rules third route at 4×4 (T380 Q2 kernel-vs-exp6 0/266,779 adds a producer-side cross-check in the same family) |
| I5 cycle containment | **0 / 3,455,412** (4×4) · **0 / 170,181** (4×3) | T363/T391/T395 records; third-route adjudication `docs/evidence/I5-DISAGREEMENT/adjudication-2026-08-06.md` (3×2/4×3 to the digit; 4×4 "— (scale)" not re-derived) | ✓ **re-ran** `checkI5Wzo2` at HEAD: V=99,133,036, E=565,402,416, maxSCC=47,429,504, cycle_reach=97,689,592, ko_sens=**3,455,412**, ko_not_cr=**0** (158.2 s, 2768 MB, exit 0) — identical to every recorded run; seeded-defect red-then-green (0→1→0) recorded in T391 and wired as a live test. **→ N1 (below): the 4×4 graph is placement-only** |
| I11 move-set | **0 / 50,000 sampled** of 99,133,036 (0.05%) at 4×4; exhaustive 0/114 · 0/978 · 0/25,350 · 0/643,378 below | T346 findings; live tests in `vb_i11.zig` assert each count and 0 mismatches; 4×4 sample stratified (10 deciles × 2 sides, seed 31337), deterministic | ✓ tests read and confirmed (2×2 114, 3×2 978, 3×3 25,350, 4×3 643,378 = 321,689 × 2, 4×4 50,000); the sample denominator framing is accurate — 0.0504% of the table; **→ N4: `vb_i11.zig` is mid-edit by the in-progress T473 (uncommitted working-tree change)** |
| Mutation adequacy | ruling: **7 / 7** asserted killed (Amendment 2 gate); honest: **6 / 10** | T363's "7 of 7" (overstatement, contradicted T345's own record); T475 reconciled mutants.md to 6/10 | ✓ `vb_mutants.zig` read at source: M5/M6/M7/M8/M9/M10 killed (I2/I7/I2/closure/I11-null/BATT-HEALTH), **M3 asserted SURVIVE** (:94, I5 vacuous at 2×2), M1/M2/M4 no per-mutant fixtures; 6/10 is the true kill-verified rate. **→ N3 (below): the ruling table still says 7/7** |
| Track A (T472) | KO_SENSITIVE column discharged by provenance (2026-08-19) | accept.md §8 provenance chain (7 steps, file:line) | ✓ chain re-verified at source: `oracle_v2_build.zig` imports std/version/exp6/artifact2/colex — no retro; its only 4×4 value source is `exp6.run_fixpoint_4x4` (:143); `retro.zig` contains zero "wzo2" occurrences and writes `data/oracle-4x4.wzo`/`.checkpoint.wzo` (:3166-3167); `data/oracle-4x4.wzo` absent on disk, checkpoint present (258,280,358 B) — consistent with the AGENTS.md foreclosure. **→ N2 (below): not propagated to CLAIMS.md** |

**The corrected §1 table of the first audit (T467) — checked, not inherited.** Every
reading in it was independently re-verified above, at full denominator or by
first-principles census: the C-A1/C-A2 corrected figures (0/616,030,190 · 0/99,133,034),
the two-convention reconciliation (kernel-successor vs T380 settled-skip 98,999,934/133,102,
discrepancy = the settled-skip, not the decode — 20,378 = 99,020,312−98,999,934 = 133,102−112,724),
the I4 two-engine pair, the I5 numbers, and the I11 sample. All arithmetic in the table
re-checks (3,455,412+95,677,624=99,133,036; 99,133,034+2=99,133,036; 463,024+170,276=633,300;
565,402,416+50,627,774=616,030,190; 50,000/99,133,036≈0.05%). T467's F1/F2/F3 (stale
denominators, bare ko_not_cr, unreconciled kill matrix) were all resolved by T475 on
2026-08-19 (commit cb00f0f — CLAIMS.md:328, instrument-coverage.md:72/75, accept.md
Amendment 1, mutants.md), which I verified in git. The two dated remainder items that
were open at T467's close — T-a (Track A ruling) and T-d (absorption) — are closed
(T472, T475); T-b (I11 exhaustive) is in progress as T473.

## 3. Findings register (all registered, none repaired — read-only mandate)

- **N1 — the 4×4 I5 graph is placement-only; the pass-edge path is dead.** In
  `checkI5Wzo2` (`src/vb_scc_4x4.zig`), `applyPass` returns ko=255 (an SMD1 sentinel,
  `:257`), and the pass-child lookup then encodes ko=255 into a key byte where
  `255<<2` truncates in u8 to 252 — a target no table entry can match. I verified by
  scanning all 99,133,036 key bytes: **zero** entries carry a key byte that could match
  the pass-edge targets (0xFC/0xFE), and my re-run's E=565,402,416 is placement-only
  (a live pass path would report ≈616M, the C-A1 total). Consequences, all
  non-verdict-changing: (a) "cycle-reachable" at 4×4 is computed on the placement-only
  subgraph; since placement-only CR ⊆ full-graph CR, the check is *stricter* than the
  claim and 0/3,455,412 remains valid evidence for the full-graph property — a
  conservative direction (false FAIL possible, false PASS impossible); (b) accept.md's
  "full-graph model" language (§3.1/§7) is not what the 4×4 instrument computes, and the
  E metric is not comparable across rungs (3×2/4×3 E counts pass edges, 4×4 does not);
  (c) the seeded-defect control licenses the placement-only instrument, which is the
  instrument under test. First audit did not identify this; it sharpens, not changes,
  its "UNKNOWN by the strict bar at 4×4" reading.
- **N2 — the Track A ruling has not been propagated to the claim register.**
  CLAIMS.md 4x4.C1 (:328) still quotes scope limit 3 — "the KO_SENSITIVE column itself
  remains distrusted pending Track A" — and PROGRESS.md:440 still calls the Track A
  regen "untested, the single gate", after T472 (2026-08-19) ruled the column
  discharged by provenance and recorded the ruling in accept.md §8. A status surface
  and a ruling now disagree. Propagation is T-d-class work, outside this mandate.
- **N3 — the discharge ruling's mutation line is an overstatement and remains on the
  ruling surface.** The "Orchestrator ruling — G3b is DISCHARGED" table in accept.md
  still says "Mutation adequacy (Amendment 2 gate) | 7 / 7 mutants asserted killed",
  while the same document's §2.2 and mutants.md carry the T475-corrected 6/10 (M3
  SURVIVES, M1/M2/M4 unverified — Gap G1/G3). This is the one place in the chain where
  the cited evidence does **not** say what the ruling says. It does not touch the six
  value conditions (independently verified above), but the Amendment-2 gate as written
  was not satisfied — the honest sentence is "6/10 kill-verified, gate remainder
  registered as Gap G1/G3".
- **N4 (observation, concurrent work) — `src/vb_i11.zig` is mid-edit by the in-progress
  T473** (uncommitted working-tree change; T473 = remainder T-b, I11 exhaustive at
  4×4). The recorded I11 sample reading (T346, 0/50,000) is from the T438-era code;
  T473's exhaustive extension will supersede the 0.05% sample with the full reading and
  close scope limit 1. No action taken — one writer per engine file is T473's.
- **N5 (observation, adjacent) — T378's QA-023 probe guard fix (2026-08-19, fc9f35d)
  does not touch the G3b chain.** Verified: the inverted White guards are in
  `src/qa023_probe.zig` only; none of the chain instruments (vb_bellman_4x4,
  vb_closure, vb_scc_4x4, vb_i11, differential) import it. The blast radius is the
  small-rung probe's White-to-move bracket values, which the AGENTS.md stance already
  distrusts. Also verified benign: the 2026-08-18 d7e4bdb change to
  `vb_bellman_4x4.zig`'s `applyMove` (board-copy padding) is byte-identical behavior at
  n=16 (4×4) and never dereferences out of range at smaller n (`koAfterCaptureRt` loops
  i<n), so T343's reading and its 3×3 calibration stand.

## 4. What I checked, and at what denominator (the "finding none" honesty clause)

Not vacuous: three findings plus two observations above. Denominators:

- Re-ran **I5 4×4 exhaustive** — all 99,133,036 entries, exit 0, reproduces the record.
- Re-ran **C-A1/C-A2 4×4 full closure** — all 99,133,036 entries, 616,030,190 children,
  32 sweeps, exit 0, reproduces the record.
- Re-ran **I4 4×3** — 463,024 examined / 170,276 excluded, 0 violations, exit 0.
- **Full-artifact census** — all 99,133,036 key bytes / L / H scanned: n_entries,
  ko_bits, flags, passes distribution (50,627,774 / 48,505,262), side balance
  (49,566,518 / 49,566,518), KO_SENSITIVE (3,455,412), ko=NONE count (97,010,524),
  and the dead-pass-edge key-byte targets (0 matches).
- Every instrument's relevant code path read at source (I4, A2, C-A1, C-A2, KEY,
  I5 small+WZO2, I11, mutants, oracle_v2_build/exp6/retro provenance).
- Cross-checks against the first audit's table: all arithmetic re-derived, all
  citations (baselines.json:1084/1183, T383-ko-decode.json:48, T391-context.json:60,
  adjudication §2.2, force-life C1) verified to exist and say what is quoted.

**Independence honesty (the twice-earned lesson, applied):** my re-runs of I5 and
closure are the same instruments the record used — they prove the recorded readings
reproduce on the current artifact (determinism + no drift), not that the instruments
are correct. Correctness rests on: (a) the genuinely second implementations on record
(T383's independent closure probe to the entry; A2's kernel-engine Φ vs R8; the T391
from-the-rules Python third route at 3×2/4×3 to the digit), (b) the structural
reconciliation I re-derived from my own census (which is a third route into the C-A1
denominator), and (c) the seeded-defect controls. The one property still without an
independent full-scale route — I5 at 4×4 — remains instrument-trusted (as the first
audit ruled), and N1 now documents precisely what that instrument computes.

## 5. Relation to the first audit (T467)

- **Agreement:** the corrected §1 table is confirmed in full; the "evidence strong,
  paperwork stale" judgement was correct and the paperwork has since been repaired
  (T472, T475).
- **Extension:** N1 (placement-only I5 graph) is new — a property-level fact about the
  instrument the first audit did not have; it does not change any verdict.
- **Mutation row:** T467 reported the kill-matrix contradiction without resolving it;
  the resolution (T475, same day) says T363's 7/7 was the overstatement and the honest
  count is 6/10 — which is what N3 now records against the still-unamended ruling table.

## 6. What a human can now see

The #2 auditor gate (remainder T-c) is closed: the G3b discharge's six value
conditions are verified at their claimed denominators by the named instruments, the
corrected numbers are confirmed, and the three new findings are all in the
register-only/paperwork class — none changes a verdict. What still stands between here
and an L2 discharge ruling: T-b (I11 exhaustive at 4×4, in progress as T473) and the
operator's ruling on L2 itself; optionally, a third-route 4×4 I5 run if the strict
re-derivation bar (N1's placement-only graph is a sharper reason to want one, not a
weaker one) is to be closed.

---

*This audit consumed well under the 90%-of-200k handover bar. Read-only bar held: no
source, instrument, artifact, or status surface modified; the working tree's other
agents' edits (incl. the T473 mid-edit of vb_i11.zig) were left untouched.*
