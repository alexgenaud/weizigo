# CLAIMS — the global claim register and dependency graph

**Created:** 2026-07-28. **Owner of this file:** the claims-register agent.
**Scope:** every claim the project states in the documents listed under
"Sources swept" below, with a globally unique identifier, its status, its
evidence, and — the point of the file — its **dependency edges**.

This file answers the question the per-file epistemic trees cannot:
*what knowledge is dependent upon prior knowledge?* Statuses were already
recorded across many documents; edges were not. When C2 was falsified at 3×2
on 2026-07-26 nobody could mechanically determine what else fell. §4 computes
that.

**This file does not adjudicate.** It records what the documents say, flags
conflicts, and computes consequences. It never resolves a conflict, never
promotes or demotes a status, and never rules on an inheritance. Those are the
user's and Opus's calls.

**Amendment, 2026-07-28 — it does now *carry* adjudications made elsewhere.**
Per §8 ("this file then updates the status and cites the resolution"), a
promotion pass on 2026-07-28 recorded rulings **D-1** (QA-009 is two runs, not a
discrepancy), **D-2** (→ ADR-0016), **D-3** (the two H5(a) corrections) and
**D-5** (→ ADR-0015), plus EXP-3's measured per-goban census. Every status this
changed cites the ruling or the run that changed it, in the row:
`QA-009` UNTESTED → FALSE (D-1), `GLOBAL.H1-CENSUS` UNTESTED → PROVEN (EXP-3),
`3x3.H1-CENSUS` / `4x3.H1-CENSUS` new and PROVEN (EXP-3), `QA-015` decided
(D-2). **No status was changed on this file's own authority, and none was
changed to improve a linter counter.** Where a promotion needed a judgement
nobody had made, it was left undone and named: see §5's note on `mixed`, §6-D18,
and `GLOBAL.F2`, which stays CLAIMED-and-orphaned because ADR-0015 refutes an
*argument* and does not falsify the finisher.

Conventions inherited from `AGENTS.md`: epistemic tags on every claim; absolute
dates; every number cites its run; per-goban epistemic independence; scores are
Black-positive; the goban index is a **colex index**, never a "rank".

---

## 1. ID scheme

    <SCOPE>.<LEGACY-ID>

**SCOPE** is one of:

| scope | meaning |
|---|---|
| `GLOBAL` | size-generic: a definition, a mathematical theorem, a project foreclosure, or a claim the documents state without goban scope |
| `CODE` | a claim about the *implementation* (a source file, a guard, a format), not about a goban. Kept distinct from `GLOBAL` because the inheritance audit (§5) turns on exactly this distinction |
| `2x2` `3x2` `3x3` `4x3` `4x4` `5x4` `5x5` | the goban size the claim is scoped to |

**LEGACY-ID** is the identifier the source document already uses, verbatim
(`C2`, `M1`, `FP1`, `S3a`, `H4`, `A-1`, `T13`, `B43`, `UD-1`, …). Nothing is
renumbered. Where two documents use the same legacy ID for different claims,
the scope prefix disambiguates and both rows exist (e.g. `4x3.S2` is Benson's
*theorem*; `4x4.S2` is the Benson *implementation regression* — see §6-D6).

Where a document states a load-bearing claim with **no** legacy ID, one is
minted and the legacy column reads `—`. Minted suffixes are derived from the
source so they stay findable:

- `ADR<nnnn>-<TAG>` — an unnumbered ADR claim (e.g. `GLOBAL.ADR0006-EYE`).
- `X<n>` — an unnumbered research-note claim (e.g. `4x4.X1`).

### A second, scope-free ID form: `QA-nnn` (imported 2026-07-28)

`critique-2026-07-28.md` §7 and `roadmap-2026-07-28.md` §5 minted a Q&A claim
register, `QA-001`…`QA-028`, and the dispatch briefs cite those IDs as the
things they close. For three days it was **a second dependency graph with no
edges**: `weizigo-claimlint` C4 found 14 distinct `QA-nnn` IDs cited in `docs/`
with no register row, including `QA-023`, the load-bearing claim of the entire
roadmap and the only claim in the project with a claim-ID-named evidence
directory (`docs/evidence/QA-023/`).

They are imported verbatim in **§2.11**. Two rules:

- **`QA-nnn` carries no scope prefix.** These are questions asked *of the
  project*, not of a goban; where a QA claim is goban-scoped its `goban` column
  says so. The ID is written exactly as the source documents write it, per §8's
  "never renumber".
- **Where a QA claim restates an existing row, it is an alias, not a copy.**
  The row says so and carries `d:<canonical>`, so a status change to the
  canonical row propagates mechanically instead of leaving two rows to drift.
  Nine of the 28 are aliases; §2.11's note lists them.

### Edge kinds (used in the `depends-on` / `dependents` columns)

- **`d:` derives-from** — the claim is a *logical consequence* of the parent.
  **If the parent falls, this claim falls.**
- **`e:` evidenced-by** — the claim is *supported by a measurement or an
  artifact*. **If the parent falls, this claim becomes UNTESTED, not false.**
- **`n:` derives-from-negation** *(added 2026-07-28)* — the claim is **justified
  by the parent being FALSE**. **Propagation is inverted.** A FALSE parent is
  the *healthy* state for an `n:` edge. **If the parent is ever rehabilitated,
  this claim's justification evaporates and it must be re-examined.**

The project has been conflating the first two; the distinction is the reason
§4's two lists differ.

**Why the third kind exists.** This project is driven mostly by falsifications,
and whole positions have been adopted *because* a claim fell. `GLOBAL.REFRAME` —
the current deliverable — is not a consequence of C2/C3/C4 being **true**; it
was adopted precisely because they are **false**. Recording that as `d:` made
the deliverable read as an orphan of its own premise, which is backwards: if
C2/C3/C4 were somehow rehabilitated, the reframe would become unnecessarily
conservative, not wrong. With only `d:` and `e:` available there was no way to
say "justified by the refutation", and no way to detect the real risk, which is
a refutation being *withdrawn*. `weizigo-claimlint` check **C1b** does exactly
that: an `n:` edge to a non-FALSE parent is an ALARM.

`n:` edges are **not traversed** by the orphan sweep. A claim justified by a
refutation does not inherit the refuted parent's ancestry.

**Never point a `d:` edge at a MEASUREMENT row or a definition.** Neither can
ever be FALSE, so the edge is a **dead end**: no falsification can travel it.
`3x3.C1` ("fresh-start scores correct at 3×3") carried `d:3x3.F2`, and `3x3.F2`
measures only that the finisher *completed* all 622 orbit reps — **completion is
not soundness**. The real parent is `GLOBAL.F2` (the finisher is *sound*), which
is orphaned via `GLOBAL.C3`, falsified at 3×3, the very goban. The measurement
shadowed the real dependency and §4.1-O3 went undetected by the linter for a
day. Cite the measurement as `e:` and the soundness claim as `d:`.
`weizigo-claimlint` check **C5** reports every remaining instance.

### Statuses

`PROVEN` · `CLAIMED` · `FALSE-AS-SCOPED` · `UNTESTED` · `INTRACTABLE` ·
`MEASUREMENT` (a datum, not a truth-claim — the M-facts and the census rows) ·
`FALSE` (added 2026-07-28 with §2.11: the Q&A register records several claims
as false *without* a scope qualifier, and re-labelling them `FALSE-AS-SCOPED`
would have been a status change this file is not entitled to make).

### The two diagnostic columns (added 2026-07-28)

Both are **additive**: no row was renumbered, restructured, or re-worded to make
room for them (§8). Both are machine-read by `weizigo-claimlint`
(`src/claimlint.zig`, findings in `claimlint-2026-07-28.md`).

**`narrowed` — how many times this claim's scope has been weakened.**

A *narrowing event* is a re-statement of the **same** claim with a smaller
scope: theorem → "not a theorem", equality → bracket, "sound" → "sound in
practice", gate → screen. A **falsification is not a narrowing** (the claim was
withdrawn, not shrunk), and a scope stated narrowly *at birth* is not a
narrowing either.

The column exists because the project's characteristic failure is **retreat by
reclassification**: single score → bracket → fresh-start-only
(`critique-2026-07-28.md` §2). Each step was locally honest; three steps later
the project was solving nothing, and no individual relabelling looked like a
mistake. `weizigo-claimlint` flags any row at **≥ 2** as
`SMELL: repeated narrowing — the representation may be wrong, not the claim.`

Values: an integer, or `?`. **`0` is a default, not a measurement** — it means
"no narrowing event was found for this row in the 2026-07-28 sweep". `?` means
the documents show a hedge-ladder whose steps could not be counted. Only the
rows listed in `claimlint-2026-07-28.md` §5 were individually assessed.

**`wrong-answer-pass-rate` — P(a wrong result also passes this claim's test).**

From `critique-2026-07-28.md` §3: three of this project's validations — anchor
agreement, cycle-rule insensitivity, and bracket containment — would have been
passed by a wrong answer **40–70%** of the time and were recorded as
confirmation. "A test a wrong answer passes 70% of the time is close to
unfalsifiable."

Values: a percentage, or `?` (not computed). `weizigo-claimlint` flags any
**PROVEN** row whose rate is `?` or above **25%** as `WEAK EVIDENCE`. Only the
rows the critique already computed, plus the external-attestation rows where the
figure is arithmetically obvious, are populated; everything else is `?`, and the
size of that `?` list is itself the finding.

### The `tree` column (added 2026-08-03, T305)

An eleventh, additive column carrying the requirement-tree node (AXIOMS.md §3)
that the row serves: a node ID (`Z-R-MOVE`, `Z-TABLE-FAITHFUL`, …) or the
disposition marker `RETIRED` (proposed retirement — the row serves no tree
node; the reason lives in `docs/epic-01-markovian/register-tree-map.md` §2, and
the human rules on retirements). The column exists so staleness is lintable
rather than prose: `weizigo-claimlint` check **C9** validates every cell against
the node vocabulary and cross-checks the mapping document against the register
(row set and per-row node must be identical), so a row added without a mapping
or a mapping that silently covers a subset fails the run. This was the dropped
Phase 0 deliverable (DIRECTION §5; phase0-execution-audit F2) — the mapping
itself is the register-tree-map document, and the column is its machine-readable
half.

### Sources swept

`docs/epistemic/PROGRESS.md` · `docs/epistemic/boards/4x4/EPISTEMIC.md` ·
`docs/epistemic/boards/4x3/EPISTEMIC.md` · `docs/epistemic/boards/CONCEPTS.md` ·
`docs/status/leak-crisis.md` · `docs/research/ko-sensitive-chainability.md` ·
`docs/research/corrections-2026-07-27.md` ·
`docs/research/open-hypotheses-2026-07-27.md` ·
`docs/research/ruleset-options.md` · `docs/research/retrograde-3x3.md` ·
`docs/research/retrograde-4x4.md` · `docs/research/arena-4x4-undef.md` ·
`docs/research/c2-falsification-3x2.md` · `docs/research/consistency-audit.md` ·
`docs/decisions/0001`–`0014` · `AGENTS.md`.

**Not swept** (declared, so the coverage gap is honest):
`docs/research/methods-and-findings.md`, `arena-audit.md`,
`query-engine-and-explanations.md`, `scaling-census.md`,
`enumeration-census.md`, `ko-examples.md`, `strategy-open-questions.md`,
`teaching-oracle-metrics.md`, `fresh-start-vs-real-game.md`,
`ghi-and-superko.md`, `oracle-5x5-pv.md`, `docs/epistemic/GLOSSARY.md`,
`docs/epistemic/names.md`, `docs/status/HANDOVER.md`, `docs/engine/*`.
These may carry additional claims and additional stale "proven" language.

**Line numbers are as of the sweep on 2026-07-28.** Other agents were editing
`PROGRESS.md`, `boards/4x4/EPISTEMIC.md` and `GLOSSARY.md` concurrently, so
citations into those three may drift by a few lines; the quoted text is the
durable locator.

---

## 2. The register

**274 rows** (217 at the 2026-07-28 sweep + the 28 `QA-nnn` rows imported into
§2.11 the same day + **8 added later on 2026-07-28** promoting rulings D-1, D-2,
D-3, D-5 and EXP-3's per-goban census: `3x3.E2-RUN1`, `3x3.E2-RUN2`,
`3x3.H1-CENSUS`, `4x3.H1-CENSUS`, `GLOBAL.H5a-CHILD`, `GLOBAL.H5a-FALLBACK`,
`GLOBAL.ADR0016-INHERIT`, `GLOBAL.ADR0015-BURDEN`) + **3 added 2026-07-30**
absorbing T114 ADR-0006 validation (`GLOBAL.ADR0006-PRED`,
`GLOBAL.ADR0006-LEMMAS`, `GLOBAL.ADR0006-PRUNEALL`) + **5 added 2026-07-30 (T125)**
absorbing the QA-026 BASICKO-TIE results (`2x2.BASICKO-TIE`, `3x2.BASICKO-TIE`,
`3x3.BASICKO-TIE`, `4x4.BASICKO-TIE`) and the T102 buffer-aliasing withdrawal
(`GLOBAL.BRUTE-ALIASING`) + **1 added 2026-07-31 (T126)**
absorbing the ko-composition census (`4x4.KO-CENSUS`) + **3 added 2026-07-31
(Fable/Consul absorption catch-up)**: `GLOBAL.PASS-NOKO`, `4x4.G-CENSUS`,
`4x4.I5-FEAS` + **6 added 2026-08-01 (Fable/T177, P2 absorption)**: `3x2.I5-CAL`,
`CODE.WZO2-CHAINSHORT`, `CODE.WZO2-UNRUN`, `CODE.M4A-HARNESS`, `CODE.VB-STUBS`,
`CODE.VB-BLINDGAPS` + **5 added 2026-08-03 (T279, fleet absorption)**:
`WZO2.I2-CLEAN`, `CODE.WZO2-PASS1-LAW`, `CODE.ACCEPT-KOKEY`, `CODE.GTP-LHSIDE`,
`CODE.CLAIMLINT-C7-NEWROWS` + **3 added 2026-08-03 (T293, phase-1 wave absorption)**:
`GLOBAL.BATTERY-GAPS`, `GLOBAL.BATTERY-PASS1-ACCEPTANCE`, `CODE.KEY-AGREEMENT` + **7 added 2026-08-03 (STANDING-ABSORB standing absorption)**:
`CODE.STANDING-ABSORB`, `CODE.STANDING-C3-DEAD`, `CODE.STANDING-STATE-FRAGILE` (the
standing-trigger mechanism, T294 findings ratified — all three independently re-verified by
direct source/observation during absorption), `4x4.WZO2-A2-EXHAUSTIVE`,
`4x4.WZO2-A5-EXHAUSTIVE`, `4x4.WZO2-A8-EXHAUSTIVE` (T309's exhaustive acceptance sweeps,
**held at CLAIMED not PROVEN per DIRECTION Amendment 2 edge 5** — exhaustive acceptance is
a measurement, not mutation adequacy), `CODE.WZO2-BUILD-REPRO` (T310's builder
reproducibility, CLAIMED as proposed). Grouped by family for
readability; the column set is identical throughout. (Row count and all edge
counts in §3 are printed by `bin/weizigo-claimlint` on every run — that print is
authoritative, this prose is a snapshot of it.)

### 2.1 Structural (S) — is the engine correct?

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.S1` | S1 | all | The colex mixed-radix index is a collision-free bijection over the 3^(w·h) goban space | PROVEN | `4x4/EPISTEMIC.md:17`; `4x3/EPISTEMIC.md:24` | — | `4x4.S1`, `4x3.S1`, `CODE.ADR0011-FMT`, every artifact address | 0 | ~0% | Z-STATE-LEGAL |
| `4x4.S1` | S1 | 4×4 | Colex bijection verified by exhaustive round-trip through 4×4 | PROVEN | `4x4/EPISTEMIC.md:17` | `e:GLOBAL.S1` | `4x4.C1`, `4x4` artifact | 0 | ~0% | Z-STATE-LEGAL |
| `4x3.S1` | S1 | 4×3 | Colex bijection holds at 4×3 | PROVEN | `4x3/EPISTEMIC.md:24` | `d:GLOBAL.S1` (inherited from the 4×4 round-trip — see §5-I7) | `4x3.C1`, `4x3` artifact | 0 | ? | Z-STATE-LEGAL |
| `GLOBAL.S2` | S2 | all | Benson's unconditional-life theorem holds on every finite goban | PROVEN | `CONCEPTS.md:10-12`; `4x3/EPISTEMIC.md:25`; `docs/evidence/GLOBAL-S2/PROVENANCE.md` | — | `GLOBAL.ADR0004-TERM`, all `S2-impl` rows, `GLOBAL.ADR0006-EYE` | 0 | ? | Z-R-SCORE |
| `3x3.S2-impl` | S2 | 3×3 | The `rules.zig` Benson implementation is exhaustively falsification-confirmed at 3×3 | PROVEN | `PROGRESS.md:203` | `e:GLOBAL.S2` | `3x3.C1` | 0 | ? | Z-R-SCORE |
| `4x4.S2-impl` | S2 | 4×4 | The `rules.zig` Benson implementation does not regress in a size-dependent way at 4×4 | UNTESTED | `4x4/EPISTEMIC.md:158-167` | `e:GLOBAL.S2` | `4x4.C1`, `4x4.M1`, `4x4` terminal detection | 0 | ? | Z-R-SCORE |
| `4x3.S2-impl` | S2-impl | 4×3 | The `rules.zig` Benson implementation is correct at 4×3 | UNTESTED | `4x3/EPISTEMIC.md:26` | `e:GLOBAL.S2` | `4x3.C1` | 0 | ? | Z-R-SCORE |
| `4x3.S2` | S2 | 4×3 | Benson-alive theorem holds at 4×3 | PROVEN | `4x3/EPISTEMIC.md:25` | `d:GLOBAL.S2` | `4x3.C1` | 0 | ? | Z-R-SCORE |
| `GLOBAL.S3a` | S3a | all | The move/capture/suicide kernel is correct; OEIS A094777 attests the legal-position count and nothing more | PROVEN (as scoped) | `CONCEPTS.md:14-16`; `4x4/EPISTEMIC.md:18-22` | — | `4x4.S3a`, `4x3.S3a` | 1 | ? | Z-STATE-LEGAL |
| `4x4.S3a` | S3a | 4×4 | 24,318,165 legal positions/side at 4×4 = OEIS A094777, cross-validated | PROVEN | `4x4/EPISTEMIC.md:18-22`; `retrograde-4x4.md:20,28` | `e:GLOBAL.S3a`, `e:4x4.S1` | `4x4.C1`, `4x4.M1` | 0 | <0.01% | Z-STATE-LEGAL |
| `4x3.S3a` | S3a | 4×3 | `legal_count = 321,689` at 4×3. **Caveat (T143 M5, re-verified T151): OEIS A094777 is defined for square n×n gobans only — 321,689 has no A094777 entry and is the project's own ground truth, independently reproduced by the census enumerator (`4x3.H1-CENSUS`). The count is PROVEN; the "= OEIS A094777" framing is withdrawn** | PROVEN | `4x3/EPISTEMIC.md:27` (the caveat is definitional — A094777 is an n-by-n sequence; recorded by T143 finding M5, encoded as the nullable oeis_legal_reference field in the verify-battery M1 design) | `e:GLOBAL.S3a` | `4x3.C1` | 0 | <0.1% | Z-STATE-LEGAL |
| `GLOBAL.S3b` | S3b | all | Ko-legality under history is a separate sub-claim from S3a; it is the structural reason R1 holds | CLAIMED | `CONCEPTS.md:17-21` | — | `4x4.S3b`, `4x3.S3b`, `GLOBAL.R1` | 0 | ? | RETIRED |
| `4x4.S3b` | S3b | 4×4 | Ko-legality under PSK history is implemented correctly at 4×4 | UNTESTED | `4x4/EPISTEMIC.md:135-140` | `d:GLOBAL.S3b` | `4x4.R1`, `4x4.C1`, `4x4.C2`, `4x4.C3`, `4x4.M1` | 0 | ? | RETIRED |
| `4x3.S3b` | S3b | 4×3 | Ko-legality under PSK history is implemented correctly at 4×3 | UNTESTED | `4x3/EPISTEMIC.md:28` | `d:GLOBAL.S3b` | `4x3.C1`, `4x3.M1` | 0 | ? | RETIRED |
| `GLOBAL.S4` | S4 | all | Area (Chinese) scoring is implemented correctly; the score is a pure function of the terminal snapshot | PROVEN | `CONCEPTS.md:20-21`; `0003:13-16`; `docs/evidence/GLOBAL-S4/PROVENANCE.md`; `docs/evidence/GLOBAL-S4/scorer-2026-07-30.py`; `docs/evidence/GLOBAL-S4/verify-2026-07-30.log` | — | every terminal score; `GLOBAL.ADR0004-TERM`; `GLOBAL.ADR0006-EYE` | 0 | ? | Z-R-SCORE |
| `4x4.S4` | S4 | 4×4 | Area scoring correct at 4×4 | UNTESTED (`⬜ᴵᴺᴴ`) | `4x4/EPISTEMIC.md:31-36` | `d:GLOBAL.S4` (self-declared inheritance) | `4x4.C1`, `4x4.M1` | 0 | ? | Z-R-SCORE |
| `4x3.S4` | S4 | 4×3 | Area scoring correct at 4×3 | UNTESTED (`⬜ᴵᴺᴴ`) | `4x3/EPISTEMIC.md:29` | `d:GLOBAL.S4` (self-declared inheritance) | `4x3.C1` | 0 | ? | Z-R-SCORE |
| `CODE.S4-XVAL` | — | n/a | `rules.zig` cross-validated: 500 random gobans vs `terminal.zig`, 1000 random moves vs `state.armies_from_move`, all equal | MEASUREMENT | `0008:63-66` | — | `GLOBAL.S4`, `GLOBAL.S3a` | 0 | ? | Z-R-SCORE |
| `GLOBAL.Z-R-MOVE-B1-EQUIV` | — | all | B1 shape-rule ⇔ position-identity equivalence lemma. PROVEN at 2×2/3×2, CLAIMED at 3×3/4×4. Test in src/rules.zig wired into zig build test. T306, absorbed T337 S4, 2026-08-04. Held at CLAIMED per DIRECTION Amendment 2 edge 5 — solver claim lacking mutation adequacy for larger gobans | CLAIMED | `findings/T306-b1-unification.json`; `src/rules.zig` | `d:GLOBAL.AXIOM-BASICKO` | — | 0 | 0 | Z-R-MOVE |

### 2.2 Fixpoint (FP) — is the table a genuine fixpoint?

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.FP1` | FP1 | all | L is the least and H the greatest fixpoint of the Bellman map (Knaster–Tarski, monotone map, seeded from `−N`/`+N`) | PROVEN (as mathematics) | `CONCEPTS.md:25-30`; `0009:53-61`; `docs/evidence/GLOBAL-FP1/proof-2026-07-30.md` | `d:GLOBAL.FP3` | all `FP1` rows, `GLOBAL.C3`, `GLOBAL.BRACKET` | 0 | ? | Z-CONVERGE-MONO |
| `2x2.B1` | B1 | 2×2 | Canonical `lo` is the true least fixpoint at 2×2 (V0+V1 hold, zero violations; monotone from `−N`) | CLAIMED | `leak-crisis.md:86-101`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** | `e:GLOBAL.FP1` | `2x2.C3` | 0 | ? | Z-CONVERGE-FIX |
| `3x2.B1` | B1 | 3×2 | Canonical `lo` is the true least fixpoint at 3×2 | CLAIMED | `leak-crisis.md:86-101`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** | `e:GLOBAL.FP1` | `3x2.C3` | 0 | ? | Z-CONVERGE-FIX |
| `3x3.B1` | B1 | 3×3 | Canonical `lo` is the true least fixpoint at 3×3 → failure mode (b) ruled out for E2 | CLAIMED | `leak-crisis.md:56-61,86-101`; `4x4/EPISTEMIC.md:60-62`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** | `e:GLOBAL.FP1` | `3x3.C3`, `GLOBAL.E2-VERDICT` | 0 | ? | Z-CONVERGE-FIX |
| `GLOBAL.B1-MULTIFIX` | B1 (a′) | 2×2/3×2/3×3 | The L map has multiple fixpoints (Gauss–Seidel reads oppV0 in-sweep); re-converge from `+N` lands above canonical | MEASUREMENT | `leak-crisis.md:93-99` | `e:2x2.B1`, `e:3x2.B1`, `e:3x3.B1` | `4x4.FP1` (the check *dropped* from acceptance) | 0 | ? | Z-CONVERGE-MONO |
| `GLOBAL.B1-AUDIT` | (a′) | all | The re-converge-from-`+N` check is a multi-fixpointedness observation, **not** a least-ness witness; the prior (a′) conclusion was unsound | PROVEN | `leak-crisis.md:99-101`; `4x4/EPISTEMIC.md:90-97`; `CONCEPTS.md:29-30` | `d:GLOBAL.FP1` | `4x4.FP1` acceptance set | 0 | ? | Z-CONVERGE-MONO |
| `4x4.FP1` | FP1 | 4×4 | L/H at 4×4 are the least/greatest fixpoints — three-check acceptance (seed, zero-change, V0/V1) | UNTESTED (checks 1–2); check 3 PASSES | `4x4/EPISTEMIC.md:69-97` | `d:GLOBAL.FP1`, `e:4x4.M4` (check 3; retired 2026-08-03 T330 — superseded by remaining evidence), `e:4x4.M2` | `4x4.C3`, `4x4.F2`, `4x4.BRACKET`, `4x4.C1` | 0 | ? | Z-CONVERGE-FIX |
| `4x4.FP1-C1` | FP1 check 1 | 4×4 | `converge` was seeded from `−N` (L) and `+N` (H) at 4×4, per build logs | UNTESTED | `4x4/EPISTEMIC.md:71-73` | — | `4x4.FP1` | 0 | ? | Z-CONVERGE-SEED |
| `4x4.FP1-C2` | FP1 check 2 | 4×4 | The final L-sweep and H-sweep each hit zero change at 4×4 | UNTESTED | `4x4/EPISTEMIC.md:74-75` | `e:4x4.M2` | `4x4.FP1` | 0 | ? | Z-CONVERGE-FINITE |
| `4x4.FP1-C3` | FP1 check 3 | 4×4 | V0/V1 Bellman identities hold at every non-settled slot — **PASSES** on `vb`/`vw`, 1:37 sample | PROVEN (as scoped) | `4x4/EPISTEMIC.md:76-88`; `ko-sensitive-chainability.md:60-69` | `e:QA-021` (re-pointed from retired `e:4x4.M4` by T330, 2026-08-03; QA-021 is the exhaustive PROVEN upgrade named in its own prose) | `4x4.FP1`, `GLOBAL.H4` | 1 | ? | Z-CONVERGE-FIX |
| `4x3.FP1` | FP1 | 4×3 | L/H at 4×3 are the least/greatest fixpoints | CLAIMED | `4x3/EPISTEMIC.md:30` | `d:GLOBAL.FP1` | `4x3.C1`, `4x3.BRACKET` | 0 | ? | Z-CONVERGE-FIX |
| `GLOBAL.FP2` | FP2 | all | Where L==H the score is history-independent — **ADR-0009 honesty clause, explicitly NOT a theorem** | CLAIMED | `CONCEPTS.md:31-32`; `0009:65-67,78-89` | `d:GLOBAL.FP1` | `GLOBAL.C2`, `GLOBAL.C3`, `GLOBAL.CERTCORE`, `GLOBAL.F2` | 1 | ? | Z-NONCLAIMS |
| `GLOBAL.FP2-bounded` | FP2-bounded / C2-bounded | all | History-independence under a finite, well-specified set of ban sets | FALSE-AS-SCOPED (at 3×2) | `CONCEPTS.md:33-37` | `d:GLOBAL.FP2` | `GLOBAL.C2`, deliverable option 1/2 | 2 | ? | Z-NONCLAIMS |
| `GLOBAL.FP2-general` | FP2-general / C2-general | all | History-independence under *any* past or future repetition | INTRACTABLE (possibly unprovable by finite methods) | `CONCEPTS.md:38-42`; `4x4/EPISTEMIC.md:148-157` | `d:GLOBAL.FP2` | research only; explicitly not a deliverable input | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.FP3` | FP3 | all | Bellman iteration terminates in finitely many sweeps (monotone map on a finite lattice) | PROVEN | `CONCEPTS.md:43-46`; `4x3/EPISTEMIC.md:31` | — | `GLOBAL.FP1`, all `FP3` rows | 0 | ? | Z-CONVERGE-FINITE |
| `4x4.FP3` | FP3 | 4×4 | Finite-sweep convergence at 4×4 | UNTESTED (`⬜ᴵᴺᴴ`) | `4x4/EPISTEMIC.md:37-43` | `d:GLOBAL.FP3` (self-declared inheritance) | `4x4.FP1` | 0 | ? | Z-CONVERGE-FINITE |
| `4x3.FP3` | FP3 | 4×3 | Finite-sweep convergence at 4×3 | PROVEN | `4x3/EPISTEMIC.md:31` | `d:GLOBAL.FP3` | `4x3.FP1` | 0 | ? | Z-CONVERGE-FINITE |
| `GLOBAL.CERTCORE` | — | all | Where L==H the score "cannot depend on any cycle rule … equals the mid-game score under ANY ban set" — the ADR-0009 *certification* decision | FALSE-AS-SCOPED | `0009:65-67` | `d:GLOBAL.FP2` | `GLOBAL.F2`, `GLOBAL.ADR0010-CUT`, the retired "certified core" framing | 2 | ? | Z-NONCLAIMS |
| `GLOBAL.ADR0009-HONESTY` | — | all | The certification argument has one unproven step (the memoryless-strategy leak); `L ≤ fresh-start ≤ H` and `L==H ⇒ exact` are strong structural evidence, not a theorem | PROVEN (as a statement about the argument) | `0009:78-89` | — | `GLOBAL.CERTCORE`, `GLOBAL.C3`, `GLOBAL.ADR0010-SOUND` | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.INVSYM` | — | all | Colour inversion: `value(−pos,−side) == −value(pos,side)`; for bound tables `L(−pos,−side) == −H(pos,side)`; dihedral transforms never change score or sign | PROVEN | `0009:102-107,148-157`; `0008:48-51,54-60`; `AGENTS.md:75-77`; `docs/evidence/GLOBAL-INVSYM/proof-2026-07-30.md` | — | `GLOBAL.P2`, all symmetry batteries, orbit propagation | 0 | ? | Z-SYM |
| `GLOBAL.ADR0020-LH-CORRECT` | — | 2×2 | **ADR-0020 gap adjudication (T287).** The 716 L≠H gaps at 2×2 (44% of Cartesian non-terminals, 62% of genuinely reachable) are the correct output of the loopy-game fixpoint under basic-ko. 0 Bellman violations, 0 L>H violations, 0 colour-inversion violations on all 1,620 non-terminals; fixpoint independently re-verified via Python re-run and one witness traced end-to-end (state idx=0: L = max(children L) = −4, H = max(children H) = +4). L<H is semantically expected under ADR-0020 E3 — the bracket IS the deliverable. | PROVEN | `docs/audits/adr0020-gap-adjudication.md` §2–4; `docs/evidence/QA-023/ko-fix-2026-07-29/fix2x2.py` (independent Python re-implementation, re-verified T287); `src/retro.zig` tests at :4575 and :4594 (passing) | `d:GLOBAL.AXIOM-BELLMAN`, `d:GLOBAL.AXIOM-LH`, `d:GLOBAL.AXIOM-BRACKET` | `GLOBAL.ADR0020-VERIFY-PASS` | 0 | ? | Z-TABLE |
| `GLOBAL.ADR0020-VERIFY-PASS` | — | all | **ADR-0020 pass condition (T287 adjudication).** ADR-0020 verification means: **(C1)** 0 Bellman violations (L=Φ(L), H=Φ(H)) over the reachable non-terminal state space at the size under test; **(C2)** 0 fixpoint-vs-truncation disagreements on the standing 24-state fixture (172 reachable non-terminals at 2×2 — T102/T103, re-verified T287). It does NOT require L==H on all reachable non-terminals — that would contradict E3 bracket semantics. The bracket rate is a *measurement*, not a violation. | CLAIMED | `docs/audits/adr0020-gap-adjudication.md` §3,8; T102/T103 fixture (24/24 pass, 0 mismatches); `docs/evidence/QA-026/calibration-2x2-mismatch.py` | `d:GLOBAL.ADR0020-LH-CORRECT`, `d:GLOBAL.AXIOM-BRACKET` | pass0 acceptance criteria, all future ADR-0020 checks | 0 | ? | Z-CONVERGE-FIX |

### 2.3 Value-correctness (C) — the crisis claims

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.C1` | C1 | all | Fresh-start scores are correct *as fresh-start scores* | — (definition) | `CONCEPTS.md:50-53`; `leak-crisis.md:24` | — | all `C1` rows; the entire adopted deliverable | 0 | ? | Z |
| `2x2.C1` | C1 | 2×2 | Fresh-start scores correct at 2×2 vs the history-aware exact solver | PROVEN | `leak-crisis.md:24`; `PROGRESS.md:126` | `e:2x2.EXACT`, `e:GLOBAL.ADR0006-EYE` | `2x2.C4`, arena baseline, `GLOBAL.C1-CALIB` | 0 | ? | Z-TABLE-FAITHFUL |
| `3x2.C1` | C1 | 3×2 | Fresh-start scores correct at 3×2 vs the history-aware exact solver | PROVEN | `leak-crisis.md:24`; `c2-falsification-3x2.md:56-57` (0/540 L==H fresh-start mismatches) | `e:3x2.EXACT`, `e:GLOBAL.ADR0006-EYE` | `3x2.C4`, `3x2.T13`, arena baseline | 0 | ? | Z-TABLE-FAITHFUL |
| `3x3.C1` | C1 | 3×3 | Fresh-start scores correct at 3×3 | CLAIMED | `PROGRESS.md:210` | `d:GLOBAL.F2` (the *soundness* behind `3x3.F2`; completion is not soundness — §4.1-O3), `e:3x3.F2`, `e:3x3.ANCHOR` (retired 2026-08-03 T330 — superseded by remaining evidence), `e:GLOBAL.INVSYM` | `3x3.C3`, 3×3 artifact | 0 | ? | Z-TABLE-FAITHFUL |
| `4x3.C1` | C1 | 4×3 | Fresh-start scores correct at 4×3 | CLAIMED | `4x3/EPISTEMIC.md:32` | `d:4x3.F2`, `d:GLOBAL.F1` (same buggy finisher path), `e:4x3.ANCHOR`, `e:GLOBAL.INVSYM` | 4×3 artifact, `4x3.M1` | 0 | ? | Z-TABLE-FAITHFUL |
| `4x4.C1` | C1 | 4×4 | Fresh-start scores correct at 4×4 — "SUPPORTED, not PROVEN"; no exhaustive ground truth exists | UNTESTED | `4x4/EPISTEMIC.md:141-147`; `PROGRESS.md:210-211` | `d:4x4.F2`, `d:GLOBAL.F1`, `e:4x4.ANCHOR` (retired 2026-08-03 T330 — superseded by remaining evidence), `e:GLOBAL.INVSYM`, `e:4x4.S3a` | the whole 4×4 deliverable, `4x4.M4`, `4x4.M6`, GTP player | ? | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.C2` | C2 | all | Single-score (L==H) positions are history-independent | FALSE-AS-SCOPED (at 3×2) | `leak-crisis.md:25`; `PROGRESS.md:127`; `AGENTS.md:68-73` | `d:GLOBAL.FP2-bounded` | `GLOBAL.C4`, `GLOBAL.CERTCORE`, deliverable options 1/2, `4x4.M4` interpretation | 2 | ? | Z-NONCLAIMS |
| `2x2.T12` | T12 | 2×2 | C2-pilot at 2×2 is **tautological** — 2×2 admits no reachable non-root cycles | MEASUREMENT | `4x4/EPISTEMIC.md:255-257,287-288` | `e:2x2.EXACT` | `3x2.T13` design calibration | 0 | ? | Z-NONCLAIMS |
| `3x2.T13` | T13 | 3×2 | C2 falsified at 3×2: **154 of the 508 reachable L==H slots (30.3%, over 132 distinct positions) have at least one reachable PSK history whose exact value differs from the stored fresh-start value** — 4,432 falsifying (slot, history) pairs of 134,504 tested (all reachable histories, order-independent). The 2026-07-26 run sampled one history per slot and recorded **12** of these; that count is traversal-dependent and understates by >10×. 0/540 fresh-start sanity mismatches. | PROVEN (falsification) | `docs/evidence/T13/probe-reimplementation-2026-07-30.md` §4,§8; `docs/evidence/T13/t13_probe.py`, `zig_t13_replay.zig`; `docs/research/c2-falsification-3x2.md:15-16,45-95` | `e:3x2.C1`, `e:3x2.EXACT` | `GLOBAL.C2`, `GLOBAL.C4`, `4x4.C2`, `GLOBAL.REFRAME`, `GLOBAL.H1` | 0 | ? | Z-NONCLAIMS |
| `3x3.C2` | C2 | 3×3 | C2 at 3×3 | UNTESTED | `PROGRESS.md:212-213` | `d:GLOBAL.FP2-bounded` | 3×3 real-game claims | 0 | ? | Z-NONCLAIMS |
| `4x3.C2` | C2 | 4×3 | C2 at 4×3 — explicitly *not* inherited from the 3×2 falsification | UNTESTED | `4x3/EPISTEMIC.md:33` | `d:GLOBAL.FP2-bounded` | 4×3 real-game claims | 0 | ? | Z-NONCLAIMS |
| `4x4.C2` | C2 / FP2 | 4×4 | C2 at 4×4 — "falsification is analogy-expected, not an open hypothesis" | UNTESTED (status conflict, §6-D3) | `4x4/EPISTEMIC.md:46,98-110`; `PROGRESS.md:212-213`; `arena-4x4-undef.md:87-91` | `d:GLOBAL.FP2-bounded`, `e:3x2.T13` (inherited — §5-I10), `e:4x4.ARENA-DIV` | 4×4 deliverable decision | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.C3` | C3 | all | The bracket `[L,H]` bounds the real-game score for any history, any cycle rule in `[−n,n]` | FALSE-AS-SCOPED (at 3×3) | `leak-crisis.md:26`; `PROGRESS.md:128`; `CONCEPTS.md:57-61` | `d:GLOBAL.FP2`, `d:GLOBAL.ADR0009-HONESTY` | `GLOBAL.ADR0010-CUT`, `GLOBAL.F2`, all `F2` rows, `GLOBAL.H5c`, every artifact's ko-sensitive column | 2 | ? | Z-NONCLAIMS |
| `2x2.C3` | C3 | 2×2 | Range-aware player leak-free at 2×2 (0/4000 games) | MEASUREMENT | `leak-crisis.md:72` | `e:2x2.B1` | `GLOBAL.C3` support | 0 | ? | Z-NONCLAIMS |
| `3x2.C3` | C3 | 3×2 | Range-aware player leak-free at 3×2 (0/4000 games) | MEASUREMENT | `leak-crisis.md:73` | `e:3x2.B1` | `GLOBAL.C3` support | 0 | ? | Z-NONCLAIMS |
| `3x3.C3` | C3 / E2 | 3×3 | C3 falsified at 3×3: range-aware self-play leaked (promise +3 → final −9, 12-pt leak) | PROVEN (falsification) | `leak-crisis.md:36,74-79`; `4x4/EPISTEMIC.md:55-66` | `e:3x3.B1`, `e:3x3.E3`, `e:3x3.E2-RUN1`, `e:3x3.E2-RUN2` | `GLOBAL.C3`, `4x4.C3`, `GLOBAL.H5c` | 0 | ? | Z-NONCLAIMS |
| `4x3.C3` | C3 | 4×3 | C3 at 4×3 — explicitly *not* inherited from the 3×3 falsification | UNTESTED | `4x3/EPISTEMIC.md:34` | `d:GLOBAL.C3` | 4×3 bracket claims | 0 | ? | Z-NONCLAIMS |
| `4x4.C3` | C3 | 4×4 | C3 at 4×4 — "analogy-expected falsified, NOT an open hypothesis"; a 4×4 run would be characterisation only | UNTESTED (status conflict, §6-D2) | `4x4/EPISTEMIC.md:55-66` | `d:GLOBAL.C3`, `e:3x3.C3` (inherited — §5-I9) | 4×4 deliverable decision | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.C4` | C4 | all | Fresh-start score == real-game score | FALSE-AS-SCOPED | `leak-crisis.md:27`; `PROGRESS.md:129`; `4x4/EPISTEMIC.md:26` | `d:GLOBAL.C2` (single-score half), `d:GLOBAL.P3` (ko-sensitive half) | `GLOBAL.REFRAME`, `4x4.A-2`, GTP player defect | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.LEAK` | — | all | The fresh-start player leaks on real-game PSK histories; "leak" = final score short of the strongest promise made in that game | PROVEN | `leak-crisis.md:9-14`; `PROGRESS.md:110-121` | `n:GLOBAL.C4` | `GLOBAL.P3`, `4x4.B43` | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.E1` | E1 | 2×2/3×2 | E1 as first written was **confounded** — it read the fresh-start child's fresh-start score, so it diagnoses where the plan breaks, it does not falsify C2 | PROVEN (methodological) | `leak-crisis.md:164-168` | — | `3x2.T13` (the replacement experiment) | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.BRUTE-ALIASING` | — | all | T102 audit (2026-07-30): a successor-buffer aliasing defect in `brute_value_2x2` (`src/exp4_solve.zig:555-594`) invalidates **every brute-force cross-check in the EXP-4 → EXP-7 chain**. All 24 EXP-4 2×2 "mismatches" were an artifact of the checker, not a divergence in the thing checked; fixpoint and FRT agree on all 172 reachable non-terminal 2×2 states. The same defect pattern recurs in `exp4_solve.zig` (3×2), `exp5_solve.zig` (3×3), `exp6_solve.zig` (4×4), and `exp6_hchain_audit.zig` — none re-verified. **Stands:** fixpoint results, independently verified by T102 (2×2), T104's Python kernel (2×2/3×2/3×3), and the MIGOS II anchor at 3×3. **Withdrawn:** brute-force cross-check as corroboration anywhere in the EXP chain | FALSE (methodological) | `docs/audits/2026-07-30-audit-2x2-mismatch.md` §1,§6; `docs/audits/2026-07-30-audit-2x2-mismatch.py` | — | `2x2.EXACT`, `3x2.EXACT`, `3x3.FWD-SPOT`, all EXP-4…EXP-7 brute-force corroboration claims, `QA-026` calibration | 0 | ? | Z-AUDIT |
| `3x3.E3` | E3 | 3×3 | The 3×3 leaking game is a VALID PSK game (0 illegal moves in 17 plies) — failure mode (c) ruled out | PROVEN | `leak-crisis.md:54-55` | — | `3x3.C3` | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.E2-SANITY` | E2 sanity | 2×2/3×2/3×3 | With trivial bounds (`lo=−N, hi=+N`) the same range-aware policy is leak-free everywhere → the E2 harness is wired correctly | PROVEN | `leak-crisis.md:48-52` | — | `3x3.C3` | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.E2-POLICY` | E2 | all | Correct range-aware policy: Black maximizes `lo[child]`, White minimizes `hi[child]`; the first run used `lo` for both and was wrong | PROVEN (bug + fix) | `leak-crisis.md:81-83` | `d:GLOBAL.INVSYM` | `3x3.C3` validity | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.E2-VERDICT` | (a) | 3×3 | Survivor hypothesis: C3 is genuinely false because `lo` pessimises cycle *resolutions* while PSK *removes* the move — a structural reason, not an implementation accident | CLAIMED | `leak-crisis.md:38-42,66,172-175` | `d:3x3.B1`, `d:3x3.E3`, `d:GLOBAL.E2-SANITY` | `GLOBAL.C3`, `4x4.C3` analogy argument | 0 | ? | Z-NONCLAIMS |
| `3x3.E2-RUN1` | — | 3×3 | **E2 run 1 (original).** Range-aware self-play at 3×3 leaked **25 of 4,000 games** = 0.625%; worst leak **12 pts** (promise +3 → final −9). Denominator = games played. Added 2026-07-28 promoting ruling **D-1** | MEASUREMENT | `leak-crisis.md:36,74`; `4x4/EPISTEMIC.md:58`; `open-hypotheses:289` | `e:GLOBAL.E2-POLICY`, `e:GLOBAL.E2-SANITY` | `3x3.C3`, `QA-009`, §6-D1 | 0 | ? | Z-NONCLAIMS |
| `3x3.E2-RUN2` | — | 3×3 | **E2 run 2 (B06 re-run).** Range-aware self-play at 3×3 leaked **50 of 8,000 games** = 0.625%; worst leak **12 pts**. **An independent replication of run 1, not a double-count of it** — ruled 2026-07-28 (D-1, Opus). Kept as a separate row deliberately: collapsing the two into one destroys the replication, which is the evidence | MEASUREMENT | `PROGRESS.md:128`; the D-1 ruling, recorded in §6-D1 of this file. **No run log is committed** — the 8,000-game output exists nowhere in git, so this row is C3-class debt: the number survives, the run does not | `e:GLOBAL.E2-POLICY`, `e:GLOBAL.E2-SANITY` | `3x3.C3`, `QA-009`, §6-D1 | 0 | ? | Z-NONCLAIMS |

### 2.4 Finisher / engine (F)

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.ADR0005-CACHE` | — | all | Cacheability "theorem": a node at ply `d` is cacheable iff `ko_ref ≥ d` | FALSE-AS-SCOPED | `0005:90-93`; downgraded `0008:32-38`; falsified `0013:20-44` | — | `GLOBAL.F1`, every pre-2026-07-23 artifact | 1 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.ADR0008-HOLE` | — | all | The `ko_ref ≥ d` rule is "a sound-in-practice compromise, not a theorem" — explicit retraction of ADR-0005's proof claim | PROVEN (as a statement about the argument) | `0008:32-38` | `n:GLOBAL.ADR0005-CACHE` | `GLOBAL.F1`, `CODE.ADR0011-FMT` caveat | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.F1` | F1 | all | The writes-on finisher (`ko_ref ≥ d` cross-branch memo guard) is sound | FALSE-AS-SCOPED | `0013:20-44`; `consistency-audit.md:25-34`; `CONCEPTS.md:109` | `d:GLOBAL.ADR0005-CACHE` | `3x2.C1` regen, `3x3.C1`, `4x3.C1`, `4x4.C1`, `4x4.M6`, every committed ko-sensitive column | 1 | ? | Z-TABLE-FAITHFUL |
| `3x2.F1` | F1 | 3×2 | Writes-on finisher unsound at 3×2: **45 of 378** ko-sensitive slots violate the minimax identity; writes-off gives **0** | PROVEN (falsification) | `consistency-audit.md:25-34`; `0013:15-19`; `4x4/EPISTEMIC.md:49-52` | `e:GLOBAL.AUDITOR` | `GLOBAL.F1`, `4x4.F1`, `4x3.F1`, `4x4.M6` reading 2 | 0 | ? | Z-TABLE-FAITHFUL |
| `4x4.F1` | F1 | 4×4 | Writes-on finisher unsound at 4×4 — "the guard is the same code; the bug is structural, not size-dependent"; the 4×4 auditor sample did not finish | CLAIMED | `4x4/EPISTEMIC.md:27-28,49-52` | `n:GLOBAL.F1` (this row asserts the finisher is UNsound — §4.1-O10), `e:3x2.F1` (inherited — §5-I1) | `4x4.C1`, `4x4.M6`, committed 4×4 ko-sensitive column | 0 | ? | Z-TABLE-FAITHFUL |
| `4x3.F1` | F1 | 4×3 | The committed 4×3 artifact was produced by the same unsound writes-on path | CLAIMED | `4x3/EPISTEMIC.md:35,48-50` | `n:GLOBAL.F1` (asserts UNsoundness — §4.1-O10), `e:3x2.F1` (inherited — §5-I2) | `4x3.C1` | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.F2` | F2 | all | The bracket-guided finisher (ADR-0010) is sound. **Orphan confirmed 2026-07-28 (D-5 → ADR-0015): the fresh-start-root defence fails and the burden on ADR-0010 is undischarged. Status left CLAIMED — the ruling refutes the *justification*, it does not falsify the finisher** | CLAIMED | `CONCEPTS.md:110-112`; `0010:14-38,70-81`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` | `d:GLOBAL.C3`, `d:GLOBAL.ADR0009-HONESTY`, `d:GLOBAL.ADR0006-EYE` | all `C1` rows for finisher-produced slots; all shipped ko-sensitive values | 1 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.ADR0010-CUT` | — | all | Bracket cutoffs "are valid under any ban set (the bracket is)", so they fire deep inside the ko-tangled opening. **ADR-0015 (2026-07-28) supersedes the justification: only the cutoff (ADR-0010 item 1) needs the premise — bracket move ordering and the aspiration window survive as heuristics** | CLAIMED | `0010:29-30,16-18`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` | `d:GLOBAL.C3` | `GLOBAL.F2`, `GLOBAL.H5c`, finisher tractability | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.ADR0010-SOUND` | — | all | ADR-0010's bracket claim inherits ADR-0009's honesty clause and is closed empirically, not proved | PROVEN (as a statement about the argument) | `0010:70-81` | `d:GLOBAL.ADR0009-HONESTY` | `GLOBAL.F2` | 0 | ? | Z-TABLE-FAITHFUL |
| `2x2.F2` | F2 | 2×2 | Plain and bracketed finishers agree slot-for-slot at 2×2 (0 diffs, both sides) | MEASUREMENT | `retrograde-3x3.md:197-203` | `e:GLOBAL.INVSYM` | `GLOBAL.F2` support | 0 | ? | Z-TABLE-FAITHFUL |
| `3x3.F2` | F2 | 3×3 | Bracket-guided finisher completes all 622 ko-sensitive orbit reps at 3×3; anchors PIN and MATCH | MEASUREMENT | `retrograde-3x3.md:181-196` | `e:3x3.B1`, `e:3x3.ANCHOR` (retired 2026-08-03 T330 — superseded by remaining evidence) | `3x3.C1` | 0 | ? | Z-TABLE-FAITHFUL |
| `4x3.F2` | F2/F3 | 4×3 | Writes-off finisher sound at 4×3 | UNTESTED | `4x3/EPISTEMIC.md:36` | `d:GLOBAL.F2` | `4x3.C1` | 0 | ? | Z-TABLE-FAITHFUL |
| `4x4.F2` | F2 | 4×4 | Bracket-guided finisher sound at 4×4 — needs auditor + bracket containment **on a writes-off regen** | UNTESTED | `4x4/EPISTEMIC.md:127-132` | `d:GLOBAL.F2`, `d:GLOBAL.C3`, `d:4x4.D3`, `e:4x4.M6` (retired 2026-08-03 T330 — evidence retired; needs re-derivation; was sole `e:` source, no surviving register artifact) | `4x4.C1`, artifact promotion, 4×4 deliverable | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.F3` | F3 | all | The writes-off (`memo_writes=false`, "soundish") finisher is sound; its correctness rests on exactly three invariants — bracket validity, eye-prune soundness, history-free certified seeds | CLAIMED | `0013:50-65`; `consistency-audit.md:42-51` | `d:GLOBAL.C3`, `d:GLOBAL.ADR0006-EYE`, `d:GLOBAL.CERTCORE` | all `F3` rows, Track A, artifact promotion | 1 | ? | Z-TABLE-FAITHFUL |
| `3x2.F3` | F3 | 3×2 | Writes-off finisher self-consistent at 3×2: 0 of 378 violations | PROVEN (necessary condition) | `consistency-audit.md:30`; `0013:15-19` | `e:GLOBAL.AUDITOR` | `GLOBAL.F3`, `3x2.C1` | 0 | ? | Z-TABLE-FAITHFUL |
| `4x4.F3` | F3 | 4×4 | Writes-off finisher self-consistent at 4×4 (stratified sample) | UNTESTED | `4x4/EPISTEMIC.md:111-126` | `d:GLOBAL.F3`, `d:4x4.D3`, `e:4x4.M6` (retired 2026-08-03 T330 — evidence retired; needs re-derivation; was sole `e:` source, no surviving register artifact) | `4x4.C1`, `4x4.F4`, artifact promotion, `4x4.M6` reading 2 | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.F4` | F4 | all | The Kishimoto–Müller dependency-guarded memo (Bloom fingerprint, `deps` mode) restores *sound* cross-branch reuse; bit-disjointness proves safety, false positives only forgo reuse | PROVEN (argument) + MEASUREMENT | `0013:67-116` | `d:GLOBAL.F3` | all `F4` rows, the 5×N scaling route | 0 | ? | Z-TABLE-FAITHFUL |
| `3x2.F4` | F4 | 3×2 | `deps` mode validated at 3×2 | PROVEN | `0013:88-91` (3×2/3×3/4×3 group) | `e:GLOBAL.AUDITOR` | `GLOBAL.F4` | 0 | ? | Z-TABLE-FAITHFUL |
| `3x3.F4` | F4 | 3×3 | `deps` mode: 0 auditor violations and byte-identical to writes-off at 3×3 | PROVEN | `0013:88-91` | `e:GLOBAL.AUDITOR` | `GLOBAL.F4` | 0 | ? | Z-TABLE-FAITHFUL |
| `4x3.F4` | F4 | 4×3 | `deps` mode: 0 auditor violations and byte-identical to writes-off at 4×3 | PROVEN | `0013:88-91` | `e:GLOBAL.AUDITOR` | `GLOBAL.F4` | 0 | ? | Z-TABLE-FAITHFUL |
| `4x4.F4` | F4 | 4×4 | KM dependency-guarded memo correct at 4×4 — needs KM regen + byte-compare to the writes-off regen | UNTESTED | `4x4/EPISTEMIC.md:168-174` | `d:GLOBAL.F4`, `d:4x4.F3`, `d:4x4.D3` | 5×N scaling, 4×4 artifact promotion | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.F4-COST` | — | 3×3/4×3 | Fingerprint width buys reuse; 64-bit saturates (≈0 reuse), 4096-bit recovers ~75% (3×3) / ~45% (4×3) of the gap. **The memory-for-reuse tradeoff is the central 5×N obstacle** | MEASUREMENT | `0013:92-108` | `e:GLOBAL.F4` | 5×5 feasibility | 0 | ? | RETIRED |
| `GLOBAL.AUDITOR` | #2 auditor | all | The `RETRO_CONSIST` self-consistency auditor is the standing pre-commit gate; passing is **necessary, not sufficient** (a solver can be self-consistent at a wrong fixpoint) | PROVEN | `consistency-audit.md:6-23`; `AGENTS.md:63-67`; `0013:117-122`; `docs/evidence/GLOBAL-AUDITOR/PROVENANCE.md`; `docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log` | — | `3x2.F1`, `3x2.F3`, all `F4` rows, `4x4.M6` reading 2, `GLOBAL.H5` gate | 1 | ? | Z-AUDIT |
| `GLOBAL.MEMO-XROOT` | Finding 2 | 2×2 | Cross-root memo reuse is order-dependent and **unsound**: at 2×2 it produced 116 dihedral-symmetry failures. NEVER share `ko_ref`-clean memo entries between roots | PROVEN (falsification) | `retrograde-3x3.md:23-37`; `0010:63-66` | `e:GLOBAL.INVSYM` | `GLOBAL.F1`, `GLOBAL.F2` design, `GLOBAL.ADR0010-CUT` | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.ADR0006-EYE` | — | all | Forbidding a player from filling its own Benson-alive true eye does not change the game score (weak dominance under area scoring) | CLAIMED | `0006:27-49`; `docs/audits/2026-07-30-eye-prune-validation.md` | `d:GLOBAL.S2`, `d:GLOBAL.S4` | `GLOBAL.F2`, `GLOBAL.F3`, all `EXACT` rows, `3x2.T13`, `3x3.C3`, `4x4.M4` (eye-pruned move set) | ? | ? | Z-AUDIT |
| `GLOBAL.ADR0006-PRED` | — | all | The shipped eye-prune predicate fires on genuine eyes of Benson-alive groups and never on false eyes, one-eye groups, big-eye space or opponent eyes; both implementations agree | PROVEN | `2026-07-30-eye-prune-validation.md` §3 (17/17 fixtures; 0/3,999,936 cross-impl mismatches) | `e:GLOBAL.S2` | `GLOBAL.ADR0006-EYE` | 0 | see §7 | Z-AUDIT |
| `GLOBAL.ADR0006-LEMMAS` | — | 2×2/3×2/3×3/4×3/4×4 | The six premises of ADR-0006's soundness argument (fill legal, area invariant, opponent-suicide, no capture, no new life either side) hold for every own true eye | PROVEN (per goban listed) | `2026-07-30-eye-prune-validation.md` §8 (0 violations; 1,362,424 eyes at 4×4) | `e:GLOBAL.S2`, `e:GLOBAL.S4` | `GLOBAL.ADR0006-EYE` | 0 | n/a (exact) | Z-AUDIT |
| `GLOBAL.ADR0006-TEST` | — | 2×2/3×2/3×3/4×3 | The eye-pruned forward search agrees with the unpruned retrograde table on every non-KO_SENSITIVE, non-FROM_FORWARD slot it can resolve (4,212 slots, 0 disagreements; 4×3 is a 1-in-8 sample) | PROVEN (executed 2026-07-30, scoped) | `2026-07-30-eye-prune-validation.md` §6 | `d:GLOBAL.ADR0009-NOEYE` | `GLOBAL.ADR0006-EYE` | 0 | see §7 | Z-AUDIT |
| `GLOBAL.ADR0006-PRUNEALL` | — | 2×2/3×2/3×3/4×3/4×4 | Positions where the prune removes every legal goban move are `is_settled` terminals below 4×4; at 4×4 there are 96 live such pairs, all valued identically by the eye-pruned forward search and the unpruned retrograde table | PROVEN (per goban listed) | `2026-07-30-eye-prune-validation.md` §4, §J | `d:GLOBAL.ADR0006-EYE`, `e:4x4` checkpoint | `GLOBAL.F3` (empty-move-list handling) | 0 | n/a (exact) | Z-AUDIT |
| `GLOBAL.ADR0009-NOEYE` | — | all | The retrograde graph uses the FULL legal move set (no eye-prune); coverage is total, resolving ADR-0007's eye-prune-vs-coverage tension | PROVEN | `0009:109-124`; `AGENTS.md:83-84` | — | `4x4.M1`, table coverage | 0 | ? | Z-COMPLETE-ENUM |
| `GLOBAL.ADR0007-TENSION` | — | all | ADR-0007 left eye-prune vs "score of every position" **unresolved and required-to-flag before persisting scores** | CLAIMED (open in ADR-0007; resolved by `GLOBAL.ADR0009-NOEYE`, never recorded as such in ADR-0007) | `0007:37-43` | — | see §6-D14 | 0 | ? | Z-COMPLETE-ENUM |
| `GLOBAL.ADR0004-TERM` | — | all | Benson-terminal leaf scores are the true game score → depth-independent → the transposition table becomes legitimately shareable (removes failure mode P2) | PROVEN | `0004:16-19,31-34` | `d:GLOBAL.S2`, `d:GLOBAL.S4` | every terminal score, `GLOBAL.F3` | 0 | ? | Z-R-SCORE |
| `GLOBAL.ADR0004-P1` | — | all | Superko removes repetition (failure mode P1) and makes the game tree finite | PROVEN | `0004:20`; `0003:17-20` | — | `GLOBAL.R1`, termination of all searches | 0 | ? | RETIRED |
| `GLOBAL.ADR0005-SUBBOARD` | — | all | Restricting moves to a sub-region of the goban is **unsound** (edge stones keep phantom liberties); search is full-goban only | PROVEN | `0005:5-9`; `AGENTS.md:80-81` | — | full-goban-only foreclosure | 0 | ? | RETIRED |
| `GLOBAL.ADR0005-DBLPASS` | — | all | Under optimal area play, at a double pass no dead stones remain, so `area_score` is exact (Tromp–Taylor) | CLAIMED (argued, not machine-checked) | `0005:61-63` | `d:GLOBAL.S4` | every terminal score | 0 | ? | Z-R-SCORE |
| `GLOBAL.ADR0005-PASS` | — | all | Passes are exempt from superko; pass is always available, so the "no children" case is subsumed | PROVEN | `0005:47-50` | — | Bellman equations `0009:20-22` | 0 | ? | Z-R-MOVE |
| `GLOBAL.ADR0003-AREA` | — | all | Area score is a pure function of the terminal snapshot; Japanese/territory score is path-dependent and NOT recoverable from a snapshot | PROVEN | `0003:13-16,21-24` | — | `GLOBAL.S4`, `GLOBAL.ADR0004-TERM`, `0014` scoring UI | 0 | ? | Z-R-SCORE |

### 2.5 Play (P) and the GTP player

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.P1` | P1 | all | An anchor match implies real-game correctness | FALSE-AS-SCOPED | `CONCEPTS.md:123`; `4x4/EPISTEMIC.md:24` | `d:GLOBAL.C4` | every "anchor validates the table" argument | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.P2` | P2 | all | A symmetry PASS implies correctness — **necessary, not sufficient** | PROVEN (as scoped) | `CONCEPTS.md:124` | `d:GLOBAL.INVSYM` | every "validation summary all green" claim | 1 | ? | Z-AUDIT |
| `GLOBAL.P3` | P3 | all | The fresh-start player plays the real-game score | FALSE-AS-SCOPED | `CONCEPTS.md:125`; `4x4/EPISTEMIC.md:25` | `d:GLOBAL.C4`, `e:GLOBAL.LEAK` | `GLOBAL.C4`, arena programme | 0 | ? | Z-NONCLAIMS |
| `4x4.P3` | P3 | 4×4 | The fresh-start player leaks 8–16% of games "even on proven-correct 2×2/3×2 tables" | MEASUREMENT | `4x4/EPISTEMIC.md:53-54` | `e:2x2.C1`, `e:3x2.C1` (inherited — §5-I13) | 4×4 arena expectations | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.T06` | T06 | 2×2/3×2 | Arena baseline leak band is 8–18% on proven-correct fresh-start tables | MEASUREMENT | `PROGRESS.md:114-115` | `e:2x2.C1`, `e:3x2.C1` | `4x4.B43` interpretation (§6-D5) | 0 | ? | Z-NONCLAIMS |
| `4x4.B39` | B39 | 4×4 | Original 4×4 parallel-artifact arena audit: 45.3% leak rate, max 144 pts | FALSE-AS-SCOPED (measurement artifact) | `arena-4x4-undef.md:4-8,27-44` | — | superseded by `4x4.B43` | 0 | ? | Z-NONCLAIMS |
| `4x4.B43` | B43 | 4×4 | With the arena UNDEF-sentinel guard: **3.4% clean leak** (123/3600), max 32 pts; 1,170/3,600 (32.5%) games touch a UNDEF slot and are out of scope | MEASUREMENT | `arena-4x4-undef.md:57-91` | `e:CODE.UNDEF` (retired 2026-08-03 T330 — evidence retired, needs re-derivation; the arena doc `arena-4x4-undef.md:57-91` remains as source), `e:4x4.PARALLEL` (retired 2026-08-03 T330 — evidence retired, needs re-derivation) | `GLOBAL.H2`, `4x4.X2` | 0 | ? | Z-NONCLAIMS |
| `4x4.B43-DIV` | B43 | 4×4 | 176 single-score + 300 ko-sensitive **real** divergence events survive the guard (down 16× from 7,825 pre-fix) | MEASUREMENT | `arena-4x4-undef.md:87-91` | `e:4x4.B43` | `4x4.C2` corroboration claim | 0 | ? | Z-NONCLAIMS |
| `4x4.M5` | M5 | 4×4 | The empty 4×4 goban is itself KO_SENSITIVE (bracket [−6,+16]) and **16 of 19 plies** in both saved regression games are flagged — the player *starts* in the unchainable region | PROVEN | `4x4/EPISTEMIC.md:199-205`; `ko-sensitive-chainability.md:126-140` | `e:4x4.M4`, `e:4x4.BRACKET` | `4x4.GTP-DEFECT`, `GLOBAL.H5a` weakness | 0 | ? | RETIRED |
| `4x4.KO-RULE-NULL` | Measurement 2 | 4×4 | Positional-superko bans changed the best available value at **0 of 19 plies** in both regression games (1 ban fired per game, at ply 14, never the best move) | PROVEN (these two games) | `ko-sensitive-chainability.md:102-118`; `4x4/EPISTEMIC.md:202-205` | — | `4x4.A-1`, `4x4.GTP-DEFECT` | 0 | ? | RETIRED |
| `4x4.GTP-DEFECT` | — | 4×4 | The GTP player's move rule (`Session.choose` extremum over stored child values) is **undefined where it mostly operates** at 4×4 | PROVEN | `PROGRESS.md:148-167`; `ko-sensitive-chainability.md:141-150` | `d:4x4.CHAIN-KO`, `e:4x4.M5`, `e:4x4.KO-RULE-NULL` | `GLOBAL.H5`, deliverable fork | 0 | ? | RETIRED |
| `4x4.GREEDY-BIAS` | — | 4×4 | The greedy extremum systematically selects the child whose false fresh-start premise is most flattering, so 3.4% is a **lower bound** on the greedy player's loss rate, not an estimate | CLAIMED | `PROGRESS.md:160-164`; `ko-sensitive-chainability.md:151-158` | `d:4x4.GTP-DEFECT`, `e:4x4.B43` | `GLOBAL.H2` | 0 | ? | RETIRED |
| `4x4.REGR-SYM` | Measurement 3 | 4×4 | The two 4×4 regressions are the same game up to the vertical mirror through ply 17; value traces identical | PROVEN | `ko-sensitive-chainability.md:121-124` | `e:GLOBAL.INVSYM` | `4x4.M5` sample size caveat | 0 | ? | RETIRED |
| `4x4.REGR-CLIFF` | Measurement 3 | 4×4 | Ply 16 collapse: stored −16 vs +16 one ply down — 32 points = 2n = the full goban swing | MEASUREMENT | `ko-sensitive-chainability.md:126-140` | `e:4x4.M4` | `GLOBAL.MAXGAP` | 0 | ? | RETIRED |
| `CODE.UNDEF` | — | n/a | `−128` (UNDEF) must be treated as "no fresh-start belief", never as a real score, by both `src/gtp.zig` and `src/arena.zig` | PROVEN | `arena-4x4-undef.md:20-56`; `0011:30-35` | — | `4x4.B43`, `4x4.B39` retraction | 0 | ? | RETIRED |
| `4x4.B16-GAME` | — | 4×4 | First in-the-wild GHI divergence (2026-07-22): a human beat the oracle by 16 on 4×4; history-exact replay shows White was never doomed — W C1 at ply 14 was the game-losing blunder, a 32-point swing | MEASUREMENT | `retrograde-4x4.md:103-152` | `e:GLOBAL.C4` | `GLOBAL.C4`, `4x4.GTP-DEFECT` | 0 | ? | Z-NONCLAIMS |
| `4x4.HISTPERF-CHEAP` | — | 4×4 | A history-perfect genmove is "trivially affordable at 4×4" — history-exact solves took 65k nodes at ply 1, sub-1k from ply 7 | MEASUREMENT | `retrograde-4x4.md:147-151` | `e:GLOBAL.ADR0010-CUT` | `GLOBAL.H3` (contradicted — §6-D11) | 0 | ? | RETIRED |

### 2.6 Ruleset (R) — foreclosures

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.R1` | R1 | all | Exact PSK solving is intractable | PROVEN (structural) | `CONCEPTS.md:129`; `AGENTS.md:47-49`; `ruleset-options.md:95-97` | `d:GLOBAL.S3b`, `e:2x2.R1`, `e:3x2.R1` | `GLOBAL.REFRAME`, the whole retrograde design, `GLOBAL.H1` | 0 | ? | RETIRED |
| `2x2.R1` | R1 | 2×2 | PSK exact-solve on the EMPTY 2×2 exceeds a 200M-node budget at **118,475,182** ban-set states | MEASUREMENT | `ruleset-options.md:91,163`; `retrograde-3x3.md:44-49` | — | `GLOBAL.R1`, `4x4.R1` | 0 | ? | RETIRED |
| `3x2.R1` | R1 | 3×2 | PSK exact-solve on the empty 3×2: **116,114,272** states, budget-exceeded | MEASUREMENT | `ruleset-options.md:92,164` | — | `GLOBAL.R1` | 0 | ? | RETIRED |
| `4x4.R1` | R1 | 4×4 | PSK intractable at 4×4 — "structural; measured at 2×2" | CLAIMED | `4x4/EPISTEMIC.md:22` | `d:GLOBAL.R1`, `e:2x2.R1` (inherited — §5-I3) | 4×4 generation-rule decision | 0 | ? | RETIRED |
| `GLOBAL.R2` | R2 | all | score-on-cycle is exactly as exact-intractable as PSK — byte-identical state counts (118,475,182 at 2×2; 116,114,272 at 3×2). "Not a coincidence, a proof of structure" | PROVEN (argument) + MEASUREMENT | `ruleset-options.md:156-181`; `AGENTS.md:52-53` | `e:2x2.R1`, `e:3x2.R1` (inherited to all sizes — §5-I4) | `GLOBAL.H1` long-cycle constraint, Option B foreclosure | 0 | ? | RETIRED |
| `GLOBAL.R3` | R3 | all | kill-X% collapses the ko-sensitive region | FALSE-AS-SCOPED | `CONCEPTS.md:130`; `AGENTS.md:50-51` | — | ruleset pivot | 0 | ? | RETIRED |
| `4x4.R3` | R3 | 4×4 | kill-X% census at 4×4, 4 thresholds: 21.32% (0) / 21.24% (50) / 21.63% (40) / **25.01%** (30) — it makes the ko-sensitive region WORSE | PROVEN (falsification) | `ruleset-options.md:107-127`; `4x4/EPISTEMIC.md:23,47-48` | `e:4x4.M1` | `GLOBAL.R3` | 0 | ? | RETIRED |
| `2x2.R3` | kill-X% | 2×2 | kill-50 makes 2×2 trivial with the score UNCHANGED (+1, 4795 nodes) | MEASUREMENT | `ruleset-options.md:91,98` | — | `GLOBAL.R3` nuance | 0 | ? | RETIRED |
| `3x2.R3` | kill-X% | 3×2 | kill-50 is too lenient at 3×2 (still intractable, 125M states); the threshold must scale with goban size | MEASUREMENT | `ruleset-options.md:92,99-101` | — | `GLOBAL.R3` nuance | 0 | ? | RETIRED |
| `GLOBAL.RPLY` | RETRO_PLY | 2×2/3×2 | The exact N-ply superko sweep is intractable for **every** N including N=1 (basic ko) and PSK — all rows hit the 200M-node budget | PROVEN (falsification) | `ruleset-options.md:53-71` | — | `GLOBAL.H1`, bounded-history route | 0 | ? | RETIRED |
| `GLOBAL.RPLY-TRAP` | — | all | Bounded-history N-ply is only bounded for *legality*; the score-on-cycle terminal drags the whole history back into the memo key | PROVEN (argument) | `ruleset-options.md:62-71` | `d:GLOBAL.R2` | `GLOBAL.H1` | 0 | ? | RETIRED |
| `GLOBAL.RPLY-RETRO` | — | all | The only tractable home for N-ply is the retrograde engine with the window **in the state**; that state space is sparse and defeats dense colex addressing | CLAIMED | `ruleset-options.md:73-81` | — | representation fork | 0 | ? | RETIRED |
| `GLOBAL.RNPLY-FORBID` | — | all | Bounded "N-ply superko (forbid-only)" does **not** terminate — a cycle longer than N is legal | PROVEN | `ruleset-options.md:42-51` | — | `GLOBAL.RPLY` | 0 | ? | RETIRED |
| `GLOBAL.MIGOS-RULE` | — | all | MIGOS II (van der Werf & Winands, ICGA 2009) plays basic ko + long-cycle-ties, **not** superko; the two rulesets legitimately disagree on cycle-dominated gobans | PROVEN | `retrograde-3x3.md:222-241` | — | all anchor comparisons, `GLOBAL.H1` | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.ANCHOR-DELTA` | — | 2×2/3×2 | Published 2×2 = 0 and 2×3 = 0 vs weizigo's PSK +1 / +1 — a ruleset-variant difference, not a bug | CLAIMED | `retrograde-3x3.md:234-238` | `d:GLOBAL.MIGOS-RULE`, `e:2x2.C1`, `e:3x2.C1` | `GLOBAL.H1` falsification target (§6-D8) | 0 | ? | RETIRED |
| `GLOBAL.REFRAME` | B05/B11 | all | The near-term deliverable is a **fresh-start score table + CLAIMED `[L,H]` bracket**, with the explicit non-promise that neither equals nor bounds the real-game PSK score | CLAIMED (adopted decision) | `PROGRESS.md:135-146,235-241`; `leak-crisis.md:150-154`; `AGENTS.md:59-62` | `n:GLOBAL.C2`, `n:GLOBAL.C3`, `n:GLOBAL.C4` (the reframe was adopted *because* these are false — §1 `n:`) | all downstream packaging | 3 | ? | Z |
| `GLOBAL.UD-1` | UD-1 | all | User decision 1 resolved as YES and acted on | CLAIMED | `PROGRESS.md:238-240` → `untracked/SUBAGENTS.md` (**not in git; see §7**) | `d:GLOBAL.REFRAME` | Track A regen | 0 | ? | RETIRED |
| `GLOBAL.UD-2` | UD-2 | all | User decision 2 resolved as YES and acted on; blocks the `4x4.S4` TODO | CLAIMED | `PROGRESS.md:238-240`; `4x4/EPISTEMIC.md:35,326-327` | `d:GLOBAL.REFRAME` | `4x4.S4` | 0 | ? | RETIRED |
| `GLOBAL.UD-3` | UD-3 | all | User decision 3 resolved as YES and acted on | CLAIMED | `PROGRESS.md:238-240` | `d:GLOBAL.REFRAME` | 4×4 bracket-only artifact (T14.1) | 0 | ? | RETIRED |
| `GLOBAL.PSK-GAP` | — | all | PSK is abandoned as the generation rule (2026-07-24) **but the 4×4 artifact and the GTP player are both still PSK** | PROVEN | `PROGRESS.md:178-181,224-228`; `open-hypotheses:56-61` | `d:GLOBAL.R1` | `GLOBAL.H1` | 0 | ? | RETIRED |

### 2.6a Ruleset axioms — minted by T271, 2026-08-02

Axioms A1–E3 from `docs/epic-01-markovian/AXIOMS.md` §2. Each is CLAIMED at birth — a written axiom is not proven by writing it. The theorem Z itself (`GLOBAL.Z`) and the two MIGOS adjudication rows (`GLOBAL.TIE-MIGOS`, `GLOBAL.FIXPOINT-VS-SEARCH`) are also registered here.

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.Z` | — | all | **Theorem Z:** For each goban size in {2×2, 3×2, 3×3, 4×4}, under ruleset R (area scoring, komi 0, basic ko k=1, loopy-game fixpoint with TIE=0), the table gives the exact game-theoretic fresh-start [L,H] bracket for every legal (position, side), with L==H where achieved, and explicit non-claims NC1–NC5 | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §1 | — | all Z-* tree nodes | 0 | ? | Z |
| `GLOBAL.AXIOM-GEOM` | — | all | **A1 — Goban geometry.** w×h grid of points; each empty, Black, or White | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | — | Z-R-MOVE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-STONE` | — | all | **A2 — Stone placement and alternation.** Black/White alternate; Black first; komi 0 | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | — | Z-R-MOVE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-CAPTURE` | — | all | **A3 — Capture.** Opposing groups with zero liberties removed after placement; liberties = empty orthogonal neighbours; group = maximal connected same-colour stones | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | — | Z-R-MOVE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-SUICIDE` | — | all | **A4 — Suicide prohibition.** Move illegal if own group has zero liberties after capture (A3 applied first) | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | — | Z-R-MOVE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-PASS` | — | all | **A5 — Pass.** Always legal; does not change the goban or capture; **clears the ko point** (sets it to `none`); exempt from ko restrictions (AXIOMS.md §2, amended by T275 — Amendment 1: "does not affect ko" restated) | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2; AXIOMS.md §7 Amendment 1 (T275) | — | Z-R-MOVE, Z-R-TIE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-FORCEDPASS` | — | all | **A6 — Forced pass.** A player with no legal placement passes (forced pass); indistinguishable from voluntary pass — clears ko, increments pass count, counts toward double-pass termination. At 4×4, 516,242 entries carry the terminal bit for one side (build T184, 2026-08-01) | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2, Amendment 3; `docs/evidence/ORACLE-V2/build-T184-2026-08-01.stdout:162` | `d:GLOBAL.AXIOM-PASS` | Z-R-MOVE, Z-R-SCORE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-BASICKO` | — | all | **B1 — Basic ko (k=1).** Illegal to capture exactly one opposing stone where the capturing stone has exactly one liberty after capture AND the resulting goban position is identical to the goban position **two plies earlier** — the position before the opponent's capture that created the ko shape (the ko point is the point of the captured stone). Amended by T275 (Amendment 1: one → two plies); the P₀/P₁/P₂ derivation is written out in AXIOMS.md §2 and proves a one-ply test "would forbid nothing" | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 (B-block, derivation); AXIOMS.md §7 Amendment 1 (T275) | — | Z-R-MOVE, Z-R-STATE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-KOSTATE` | — | all | **B2 — Ko state encoding.** Ko point = forbidden recapture point or `none`; set on ko capture, cleared on pass and non-ko-capture moves | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.AXIOM-BASICKO`, `d:GLOBAL.AXIOM-PASS` | Z-R-STATE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-KOPASS` | — | all | **B3 — Ko–pass interaction.** Pass clears ko point; pass always legal → ko cycle always breakable by passing | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.AXIOM-PASS`, `d:GLOBAL.AXIOM-KOSTATE` | Z-R-TIE | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-TERMINAL` | — | all | **C1 — Termination.** Game ends on consecutive double-pass; also terminal if both sides have only pass as legal move | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.AXIOM-PASS` | Z-R-SCORE | 0 | ? | Z-R-SCORE |
| `GLOBAL.AXIOM-AREA` | — | all | **C2 — Area scoring.** Black score = Black stones + surrounded empty points; White symmetric; game score = Black − White. Territory via Benson's unconditional-life theorem | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.S2`, `d:GLOBAL.ADR0003-AREA`, `d:GLOBAL.S4` | Z-R-SCORE | 0 | ? | Z-R-SCORE |
| `GLOBAL.AXIOM-TIE` | — | all | **C3 — Tie value.** Under loopy-game fixpoint semantics, cycle value = TIE = 0 (draw). Tie is a constant, not a function of which positions repeat → state is Markovian | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | — | Z-R-TIE, Z-CONVERGE | 0 | ? | Z-R-TIE |
| `GLOBAL.AXIOM-SCORESIGN` | — | all | **C4 — Score sign convention.** Scores Black-positive; side picks array, never sign; Black maximizes, White minimizes; colour inversion: value(−pos, −side) == −value(pos, side); for bounds L(−pos, −side) == −H(pos, side) | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.INVSYM` | Z-R-SIGN | 0 | ? | Z-R-SIGN |
| `GLOBAL.AXIOM-STATE` | — | all | **D1 — State tuple.** State = (position via colex, side ∈ {B,W}, ko_point ∈ {0…N−1} ∪ {none}, passes ∈ {0,1,2}) | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.S1` | Z-R-STATE, Z-STATE | 0 | ? | Z-R-STATE |
| `GLOBAL.AXIOM-FRESHSTART` | — | all | **D2 — Fresh-start root.** (empty goban, Black, ko=none, passes=0); all table values from this root | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | — | Z-STATE-REACH | 0 | ? | Z-R-STATE |
| `GLOBAL.AXIOM-PASSSTATE` | — | all | **D3 — Pass-state invariant.** passes ≥ 1 ⇒ ko_point = none. Pass captures nothing, so no ko point with nonzero passes | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.PASS-NOKO` | Z-R-STATE, Z-STATE-KEY | 0 | ? | Z-R-STATE |
| `GLOBAL.AXIOM-BELLMAN` | — | all | **E1 — Bellman operator.** Non-terminal: Black V = max over legal moves of V(child); White V = min. Terminal: V = area_score | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.AXIOM-TERMINAL`, `d:GLOBAL.AXIOM-AREA` | Z-CONVERGE | 0 | ? | Z-CONVERGE |
| `GLOBAL.AXIOM-LH` | — | all | **E2 — L/H fixpoint.** L = Φ(L), H = Φ(H), seeded from (−N, +N) where N = w·h; least/greatest fixpoints by Knaster–Tarski on finite lattice | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.FP1`, `d:GLOBAL.FP3` | Z-CONVERGE, Z-TABLE | 0 | ? | Z-CONVERGE |
| `GLOBAL.AXIOM-BRACKET` | — | all | **E3 — Bracket semantics.** L(s) ≤ H(s) always; L=H ⇒ unique fresh-start value; L<H ⇒ bracket-valued (history beyond k=1 matters) | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §2 | `d:GLOBAL.AXIOM-LH` | Z-TABLE | 0 | ? | Z-TABLE |
| `GLOBAL.TIE-MIGOS` | — | all | **MIGOS tie adjudication, Candidate 1 — REFUTED by primary sources (T274, absorbed T279).** The hypothesis that the +1-vs-+2 gap is a *tie-value* difference (TIE=0 vs MIGOS's long-cycle-tie value) is contradicted: MIGOS's documented long-cycle-tie value **is 0** (thesis §5.3.2; ICGA 2009 §3.3 "typically 0"), identical to our TIE=0, and MIGOS's own basic-ko 4×4 result is **+1 = ours** (thesis Table 5.1). The +2 arises from the pass-difference cycle-resolution **rule** (thesis Appendix A §A.4: repetition ends the game, scored by pass-difference; or SSK), a different game definition — not a different tie constant. Empirically confirmed by T274: no flat TIE constant reproduces the colour-symmetric (+2,−2) anchor at 4×4 (analytic from the measured bracket [L=+1,H=+16]/[−16,−1]; the small-goban sweep confirms L/H tables are TIE-independent and V=clamp(TIE,[L,H]) exactly). The register's `4x4.ANCHOR` citation 'thesis §6.4' was wrong — the 4×4 solve is thesis §5.4.1 (Table 5.1) + Appendix A §A.4. **The +2 acceptance criterion in `roadmap-2026-07-28.md:227-232` is not met by ruleset R and cannot be — the +2 anchor is a different game** | FALSE-AS-SCOPED (the minted mechanism is contradicted; the +2 anchor is a different game, not a different tie) | `docs/evidence/GLOBAL-TIE-MIGOS/tie-experiment-T274.md`; `findings/T274-tie-experiment.json`; `findings/T274-context.json` | — (the hypothesis was its own claim, refuted by primary-source reading; no derivation edge) | `4x4.BASICKO-TIE`, `PROGRESS.md` §4.2 corrections, `AXIOMS.md` §4 rewrite | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.FIXPOINT-VS-SEARCH` | — | all | **MIGOS tie adjudication, Candidate 2 — absorbed T279.** Under aligned rules (basic ko, tie 0) weizigo fixpoint (+1) and MIGOS search (+1, thesis Table 5.1) **agree**, so the +1-vs-+2 gap is not a fixpoint-vs-search discrepancy. The gap is a ruleset difference: MIGOS's +2 comes from the pass-difference cycle-resolution rule (a different game). Candidate 2(b) — a defect in our build — is not needed to explain the gap, though our value for our own game still awaits the #2 auditor. The row's framing ("computational-method difference") is preserved because `GLOBAL.TIE-MIGOS` was the primary hypothesis and it is now FALSE-AS-SCOPED; this row records the fallback finding that the two methods agree per primary sources. **Remains CLAIMED, not PROVEN:** the agreement rests on one seat's primary-source reading (T274) absorbed by T279, and our own +1 still awaits the #2 auditor — an absorption task cannot promote it | CLAIMED | `docs/evidence/GLOBAL-TIE-MIGOS/tie-experiment-T274.md`; `docs/epic-01-markovian/AXIOMS.md` §4 | `e:GLOBAL.TIE-MIGOS` (the tie-value explanation is refuted; this row records the residual finding) | `GLOBAL.TIE-MIGOS` context | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.AXIOM-AMEND1` | — | all | **AXIOMS.md Amendment 1 (2026-08-02, dspro/T275, Orcha verification)** — axiom-change event, recorded per AXIOMS.md:12-14 ("a dated entry here plus a register row … never a silent edit"): A5 restated ("does not affect ko" → "clears the ko point"); B1 ply count corrected (one → two); §4.3 "not a bug" withdrawn, falsification test registered as T274 | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §7 Amendment 1 | — | `GLOBAL.AXIOM-PASS`, `GLOBAL.AXIOM-BASICKO`, `GLOBAL.TIE-MIGOS` | 0 | ? | Z-R-MOVE |
| `GLOBAL.AXIOM-AMEND2` | — | all | **AXIOMS.md Amendment 2 (2026-08-02, Orchestrator)** — axiom-change event, recorded per AXIOMS.md:12-14 ("never a silent edit"): B1's two-ply derivation written out in §2 (P₀/P₁/P₂, checkable by reading rather than by trusting); the identity line restored to the DELEGATEE-prescribed template (`Model: not stated at dispatch` was correct — a blank is usable in the ledger, a guess corrupts it) | CLAIMED | `docs/epic-01-markovian/AXIOMS.md` §7 Amendment 2 | — | `GLOBAL.AXIOM-BASICKO` | 0 | ? | Z-R-MOVE |

### 2.7 Chainability (2026-07-27) and the M-facts

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.CHAIN-DEF` | — | all | *Chainable* [project term]: a region where `V0(P,s) == best_s({V0(child,−s)} ∪ {V1(P,−s)})`. Taking an extremum over stored child values is only defined on a chainable region | — (definition) | `ko-sensitive-chainability.md:24-33` | — | every chainability row | 0 | ? | RETIRED |
| `GLOBAL.CHAIN-LH` | M4 | 2×2/3×2/3×3/4×3/4×4 | The single-score (L==H) region **is chainable** — zero identity violations outside the KO_SENSITIVE flag at every size tested, under both the full and the ADR-0006 eye-pruned move sets | PROVEN (on the audited artifacts) | `ko-sensitive-chainability.md:60-69`; `PROGRESS.md:72-82,192-197` | `e:2x2.M4`…`e:4x4.M4` | `4x4.FP1-C3`, `GLOBAL.H4`, `GLOBAL.H5a` | 0 | ? | RETIRED |
| `GLOBAL.CHAIN-KO` | M4 | same | The ko-sensitive region is **not** chainable; violations are *exactly co-extensive* with the KO_SENSITIVE flag (16/16, 72/72, 688/688, 6,092/6,092, 11,402/11,402) — no unflagged slot ever violates | PROVEN | `ko-sensitive-chainability.md:70-71`; `PROGRESS.md:86-92` | `e:2x2.M4`…`e:4x4.M4` | `4x4.GTP-DEFECT`, `GLOBAL.H5` | 0 | ? | RETIRED |
| `GLOBAL.CHAIN-KIND` | — | all | Ko-sensitive violations are **definitional in kind** — each such slot is an independent fresh-start PSK solve owing its parent no agreement across a history-free edge; a nonzero rate is expected, 0% would indicate a broken tool | PROVEN | `ko-sensitive-chainability.md:71-79,198-211`; `corrections:175-201` | `n:GLOBAL.C2` | `4x4.M6` reading 1, `GLOBAL.C-1` | 0 | ? | RETIRED |
| `GLOBAL.MAXGAP` | — | 3×2/3×3/4×3/4×4 | For every goban with n ≥ 6 the worst misprice is exactly **2n** (12, 18, 24, 32) — the full goban swing; 2×2 is the exception (2, not 8) | CLAIMED | `ko-sensitive-chainability.md:94-100`; `PROGRESS.md:98-102` | `e:2x2.M4`…`e:4x4.M4` | none (explicitly not carried to 5×5) | 0 | ? | RETIRED |
| `2x2.M4` | M4 | 2×2 | 77.36% of checked slots ko-sensitive; 19.51% misprice within flag; max gap 2; **0** outside | MEASUREMENT | `ko-sensitive-chainability.md:50` (`bin/weizigo-chainability artifacts/oracle-2x2.wzo`) | — | `GLOBAL.CHAIN-LH`, `GLOBAL.C-1` | 0 | ? | RETIRED |
| `3x2.M4` | M4 | 3×2 | 41.18% ko-sensitive; 19.05% misprice; max gap 12; **0** outside | MEASUREMENT | `ko-sensitive-chainability.md:51` | — | `GLOBAL.CHAIN-LH`, `GLOBAL.C-1` | 0 | ? | RETIRED |
| `3x3.M4` | M4 | 3×3 | 35.04% ko-sensitive; 7.91% misprice; max gap 18; **0** outside | MEASUREMENT | `ko-sensitive-chainability.md:52` | — | `GLOBAL.CHAIN-LH` | 0 | ? | RETIRED |
| `4x3.M4` | M4 | 4×3 | 26.60% ko-sensitive; 3.58% misprice; max gap 24; **0** outside (exhaustive) | MEASUREMENT | `ko-sensitive-chainability.md:53` | — | `GLOBAL.CHAIN-LH` | 0 | ? | RETIRED |
| `4x4.M4` | M4 | 4×4 | 21.27% ko-sensitive; 4.08% misprice; max gap 32; **0** outside — 1:37 colex stride, 657,566 positions / 1,313,248 slots on `data/oracle-4x4.checkpoint.wzo` (258,280,358 B, sha256 `a2174fedd6a0591dc66b0b42ef1f52bdc28b97c448dbc5b043d96de3a3b1e118`) | MEASUREMENT | `4x4/EPISTEMIC.md:187-198`; `ko-sensitive-chainability.md:54,45` | `e:4x4.PARALLEL` | `4x4.FP1-C3`, `4x4.M6`, `GLOBAL.H4` | 0 | ? | RETIRED |
| `4x4.M6` | M6 | 4×4 | Writes-off regeneration **halves** the ko-sensitive misprice rate: 4.08% → 1.67% at stride 37; 3.81% → 1.47% at stride 997; 0 outside the flag on both artifacts at both strides | MEASUREMENT | `4x4/EPISTEMIC.md:206-245`; `ko-sensitive-chainability.md:163-197` | `e:4x4.M4`, `e:4x4.WRITESOFF` | `4x4.M6-FLOOR`, `4x4.M6-EXCESS`, `4x4.F2`, `4x4.F3` | 0 | ? | RETIRED |
| `4x4.M6-FLOOR` | M6 (i) | 4×4 | The definitional floor is **nonzero**: writes-off still shows 1.67%. **0% is not the target value for a correct artifact** | PROVEN (on the swept artifact) | `4x4/EPISTEMIC.md:222-226`; `ko-sensitive-chainability.md:198-211` | `d:GLOBAL.CHAIN-KIND`, `e:4x4.M6` | interpretation of every future sweep | 0 | ? | RETIRED |
| `4x4.M6-EXCESS` | M6 (ii) | 4×4 | The committed artifact's ≈2.4× excess over that floor **is** the ADR-0013 `ko_ref ≥ d` GHI bug | CLAIMED | `4x4/EPISTEMIC.md:227-231`; `ko-sensitive-chainability.md:213-234` | `d:4x4.F1`, `e:4x4.M6` | `4x4.F3` acceptance framing | 0 | ? | RETIRED |
| `4x4.M6-SCREEN` | — | 4×4 | The ko-sensitive misprice rate is a **cheap artifact-only discriminator** between sound and unsound generation — a screen, not a gate | CLAIMED | `4x4/EPISTEMIC.md:232-235`; `ko-sensitive-chainability.md:236-244` | `d:4x4.M6` | Track A validation workflow | 1 | ? | RETIRED |
| `4x4.WRITESOFF` | — | 4×4 | `untracked/oracle-4x4-writesoff-checkpoint.wzo` exists but its **build completion is NOT confirmed**; it is uncommitted and differs from the committed artifact by 2,394 filled slots (0.18%) at stride 37 | MEASUREMENT | `4x4/EPISTEMIC.md:236-242`; `ko-sensitive-chainability.md:246-254` | — | `4x4.M6`, `4x4.F3` | 0 | ? | RETIRED |
| `4x4.M1` | M1 | 4×4 | Ko-sensitive region = 10,367,922 / 48,636,330 = **21.32%** (exhaustive) | MEASUREMENT | `4x4/EPISTEMIC.md:186`; `ruleset-options.md:116` | `e:4x4.S3a`, `e:GLOBAL.ADR0009-NOEYE` | `4x4.R3`, `4x4.M4` cross-check | 0 | ? | RETIRED |
| `4x4.KO-CENSUS` | — | 4×4 | Ko-sensitive region is **99.997% single-ko** by static + bounded-dynamic census: 0-ko (65.0%), 1-ko (32.9%), 2-ko (2.04%) all single-ko on 1,500+ sampled positions; multi-ko concentrated in the 3-ko category (~250 side-positions, 0.0025% of 10,367,922). Verified byte-identical against B23 static census; dynamic cycle classifier (`src/ko_cycle_census.zig`) sampled every static-ko category with budget scaling (5K→20K nodes, 12→14 depth) and a positive control (3-ko = 94.4% multi-ko). Converts the open question from "can we handle 10.4M ko-sensitive slots?" into "can we certify a single-ko sub-solver?" | MEASUREMENT | `docs/research/ko-composition-census-2026-07-30.md`; `src/ko_cycle_census.zig` | `e:4x4.M1` (reads the same checkpoint) | `GLOBAL.H1`, Track A single-ko sub-solver strategy, `4x4.D3` scope | 0 | ? | RETIRED |
| `4x4.M2` | M2 | 4×4 | 19 sweeps to fixpoint at 4×4 (the measurement; `4x4.FP3` is the theorem) | MEASUREMENT | `4x4/EPISTEMIC.md:246-247`; `retrograde-4x4.md:21` | — | `4x4.FP1-C2`, 5×5 projection | 0 | ? | Z-CONVERGE-FINITE |
| `4x4.M3` | M3 | 4×4 | 649,517 ko-sensitive orbit reps; finisher 6.1 min; ~1,663 nodes/rep avg; max/root 349,349; total 1,080,118,252 nodes | MEASUREMENT | `4x4/EPISTEMIC.md:248`; `retrograde-4x4.md:23-25,33-34` | `e:GLOBAL.F1` (measured on the **writes-on** config) | `GLOBAL.H5c` cost, 5×5 projection | 0 | ? | RETIRED |
| `4x4.BRACKET` | — | 4×4 | Empty 4×4 bracket = **[−6, +16]** (22 wide out of 32); the published anchor +2 is in-bracket | MEASUREMENT | `4x4/EPISTEMIC.md:249`; `ruleset-options.md:213` | `e:4x4.FP1` | `4x4.M5`, `4x4.ANCHOR` | 0 | ~70% | RETIRED |
| `4x4.SINGLE` | — | 4×4 | Fresh-start single-score region = 38,268,408 / 48,636,330 = **78.68%** of slots | MEASUREMENT | `4x4/EPISTEMIC.md:250`; `ruleset-options.md:213` | `e:4x4.M1` | `GLOBAL.REFRAME` scope | 0 | ? | RETIRED |
| `4x4.TANGLE` | — | 4×4 | 3,702,442 ko-sensitive slots have a width-32 bracket = the full [−16,+16] range — over a third of the region carries zero information | MEASUREMENT | `ruleset-options.md:216-218` | `e:4x4.BRACKET` | deliverable honesty | 0 | ? | RETIRED |
| `4x4.ANCHOR` | — | 4×4 | `empty(B) 4×4 = +2` (dtt 13) agrees with the published MIGOS II anchor (van der Werf & Winands, ICGA 2009; van der Werf 2005 PhD thesis §6.4). **MIGOS II plays basic ko + long-cycle-ties, NOT PSK** (`GLOBAL.MIGOS-RULE`, `QA-025`). The agreement is cross-ruleset — see `4x4.CYCLE-INSENS` for the inference it licenses. A 15-ply self-play game on the artifact scores B+2. **Corrected 2026-07-29 (AUDIT-REF-DSPro-2026-07-29 §1): the original text claimed "under PSK," which is contradicted by `GLOBAL.MIGOS-RULE`.** | MEASUREMENT | `retrograde-4x4.md:74-84` | `e:GLOBAL.P1` (which is FALSE-AS-SCOPED as *validation*) | `4x4.C1` support, §4-O4 | 0 | ~70% | RETIRED |
| `4x4.CYCLE-INSENS` | — | 4×4 | "The 4×4 empty-goban score is evidently cycle-rule-insensitive, unlike 2×2/3×2" | CLAIMED | `retrograde-4x4.md:77-80` | `d:GLOBAL.MIGOS-RULE`, `e:4x4.ANCHOR` | `GLOBAL.H1` anchor argument (§5-I24) | 0 | ~70% | RETIRED |
| `4x4.VALBATTERY` | — | 4×4 | 4×4 validation summary (2026-07-21): 0 bracket-fails, 0 orbit-clashes, exhaustive symmetry PASS over all 43M slots, 0 unfilled legal slots, reload byte-identical | MEASUREMENT | `retrograde-4x4.md:86-88` | `e:GLOBAL.P2`, `e:CODE.ADR0011-GATE` | §4-O5 | 0 | ? | RETIRED |
| `4x4.COMPLETE-2026-07-21` | — | 4×4 | "The complete, validated 4×4 oracle — every legal (position, side) exact" (`data/oracle-4x4.wzo`, 258,280,358 B, sha256 `b42c3371…655f`) | FALSE-AS-SCOPED | `retrograde-4x4.md:1-13`; retracted by `PROGRESS.md:267-270`, `0013:126-128`, `AGENTS.md:54-57` | `d:GLOBAL.F1`, `d:GLOBAL.C1` | §4-O5, `GLOBAL.ADR0012-GATE` | 0 | ? | RETIRED |
| `4x4.PARALLEL` | — | 4×4 | `data/oracle-4x4-parallel.checkpoint.wzo` (258,280,358 B, sha256 `28afa11bf095554ed313a400a3a5eb871cc49c4bfdefe07e1f2e8f3037f3fc4a`) — writes-off finisher, **99.8% filled**, 83K UNDEF slots (mostly 2-ko+) | MEASUREMENT | `arena-4x4-undef.md:20-26`; `PROGRESS.md:211,244-245` | — | `4x4.B43`, `4x4.M4`, §6-D13 | 0 | ? | RETIRED |
| `4x3.M1` | M1 | 4×3 | Ko-sensitive fraction = 170,276 / 643,378 = **26.47%** | MEASUREMENT | `4x3/EPISTEMIC.md:40`; `ruleset-options.md:212` | `e:4x3.S3a` | `4x3.M4` cross-check (§6-D7) | 0 | ? | RETIRED |
| `4x3.M2` | M2 | 4×3 | 17 sweeps to convergence | MEASUREMENT | `4x3/EPISTEMIC.md:41` | — | `4x3.FP1` | 0 | ? | Z-CONVERGE-FINITE |
| `4x3.M3` | M3 | 4×3 | Full 4×3 writes-on solve ~4.7 s (census), ~31 s with the sound dependency guard; ~16.6× node-count increase vs 3×3 | MEASUREMENT | `4x3/EPISTEMIC.md:42` | — | `4x4.D3` pilot extrapolation | 0 | ? | RETIRED |
| `4x3.BRACKET` | — | 4×3 | Empty 4×3 bracket = **[−1, +12]** (width 13 of 28); published anchor **+4** is in-bracket | MEASUREMENT | `4x3/EPISTEMIC.md:43-44`; `ruleset-options.md:212` | `e:4x3.FP1` | `4x3.C1` support | 0 | ~56% | RETIRED |
| `4x3.TANGLE` | — | 4×3 | 54,388 4×3 slots have a width-24 bracket = the entire [−12,+12] range | MEASUREMENT | `ruleset-options.md:228-230` | `e:4x3.BRACKET` | deliverable honesty | 0 | ? | RETIRED |
| `3x3.M1` | — | 3×3 | Ko-sensitive = 8,698 / 25,350 = 34.3%; single-score 16,652 (65.7%) | MEASUREMENT | `ruleset-options.md:211`; `retrograde-3x3.md:66` | — | §6-D7 | 0 | ? | RETIRED |
| `3x3.BRACKET` | — | 3×3 | Empty 3×3 bracket = **[+2, +9]** (width 7); all five published anchors are in-bracket | MEASUREMENT | `retrograde-3x3.md:102-110`; `ruleset-options.md:211` | `e:3x3.B1` | `3x3.C3` (the leak went to −9, **outside** the bracket) | 0 | ~42% | RETIRED |
| `3x3.ANCHOR` | — | 3×3 | Anchors PIN and MATCH after bracket-guided finishing: empty +9/−9, centre +9, side +3, corner −9 | MEASUREMENT | `retrograde-3x3.md:183-185`; `0008:45-47` | `e:3x3.F2` | `3x3.C1` support | 0 | ~42% | RETIRED |
| `GLOBAL.SWEEPS` | — | 2×2→4×4 | Sweep growth 2 → 6 → 12 → 19 is strongly sub-linear in slot count; the ko-sensitive fraction keeps FALLING (72 → 39 → 34 → 21.3%) | MEASUREMENT | `retrograde-4x4.md:21-22,30-32` | — | 5×5 projection (§5-I16 class) | 0 | ? | RETIRED |
| `2x2.EXACT` | Finding 3/5 | 2×2 | The 2×2 pipeline is complete: 9 orbit reps solved, 82 slots by symmetry, 0 bracket-fails, 0 orbit-clashes, exhaustively symmetric | MEASUREMENT | `retrograde-3x3.md:74-82` | `e:GLOBAL.INVSYM` | `2x2.C1` | 0 | ? | Z-TABLE-FAITHFUL |
| `3x2.EXACT` | Finding 3 | 3×2 | History-exact ground truth completed on **68 of 600** roots at 3×2 (2×2: **8 of 114**), all with zero mismatches and every score in-bracket | MEASUREMENT | `retrograde-3x3.md:50-52,141` | — | `2x2.C1`, `3x2.C1` (§6-D9) | 0 | ? | Z-TABLE-FAITHFUL |
| `3x3.FWD-SPOT` | Finding 7 | 3×3 | 400 sampled certified deep 3×3 roots re-solved no-memo forward: **295 exceeded budget**, 105 completed, 105/105 matched | MEASUREMENT | `retrograde-3x3.md:128-135` | — | `3x3.C1` support | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.FWD-INTRACT` | Finding 1/3 | 3×3 | Forward fresh-start filling of the 3×3 table was measured INTRACTABLE (years); the exact state space explodes before the position space does | PROVEN | `retrograde-3x3.md:17-21,39-58` | `d:GLOBAL.R1` | the retrograde design | 0 | ? | RETIRED |
| `GLOBAL.FIN-NEARTERM` | Finding 6 | 3×3 | The plain (ADR-0009) finisher rescues near-terminal ko-sensitive slots, **not** the opening: empty(B) 3×3 exceeded 2.0e9 nodes seeded with all 8,326 certified scores | MEASUREMENT | `retrograde-3x3.md:84-100` | — | `GLOBAL.ADR0010-CUT` motivation | 0 | ? | RETIRED |
| `GLOBAL.FIN-BRACKET` | Finding 8 | 2×2/3×2/3×3 | Bracket cutoffs collapse the finisher by ~6 orders of magnitude; empty(B) 3×3 pins in 1,854 nodes | MEASUREMENT | `retrograde-3x3.md:165-179` | `e:GLOBAL.ADR0010-CUT` | `GLOBAL.H5c` | 0 | ? | RETIRED |
| `4x4.DRIVER` | — | 4×4 | Driver saga: aspiration dies on wide brackets (>5e8 nodes, abandoned on the empty root); bare MTD is worse; MTD + per-root bounds memo solves all 649,517 reps with zero skips | MEASUREMENT | `retrograde-4x4.md:36-62` | — | `4x4.M3`, `GLOBAL.H3` context | 0 | ? | RETIRED |

### 2.7a Basic-ko + TIE=0 fresh-start results (QA-026 / EXP-4/5/6, DSPro, 2026-07-29)

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `2x2.BASICKO-TIE` | — | 2×2 | Fresh-start value of 2×2 under basic-ko + TIE=0: root = 0 (TIE, L=−4 H=+4), 258 reachable states, 4 sweeps, L=Φ(L)/H=Φ(H) 0 failures, colour-inversion 0/2430. **Brute-force cross-check in the calibration section of the PROVENANCE is withdrawn (T102 buffer-aliasing, `GLOBAL.BRUTE-ALIASING`); fixpoint results independently verified by T102 and T104** | MEASUREMENT | `docs/evidence/QA-026/PROVENANCE.md`; `docs/evidence/QA-026/exp4-solve-2026-07-29.stdout`; `docs/audits/2026-07-30-audit-2x2-mismatch.md` | `e:GLOBAL.INVSYM`, `n:GLOBAL.BRUTE-ALIASING` | `QA-026` | 0 | ? | Z-TABLE |
| `3x2.BASICKO-TIE` | — | 3×2 | Fresh-start value of 3×2 under basic-ko + TIE=0: root = 0 (TIE, L=−6 H=+6), 2,586 reachable states, 10 sweeps, L=Φ(L)/H=Φ(H) 0 failures, colour-inversion 0/2586. **Brute-force cross-check withdrawn (T102 buffer-aliasing). T138 (2026-07-31, `docs/evidence/QA-023/census-reconciliation.md`): the 2,586 census is the EXP-4 bug-free retrograde-engine build (2220/298/34/34); the +36 delta from the QA-023 corrected kernel (42-seed, 2232/322/34/34) is exactly the 36 empty-goban-with-ko-point phantom seeds (12→L==H, 24→pin_T), excluded by the true-game-root (4-seed) convention.** | MEASUREMENT | `docs/evidence/QA-026/PROVENANCE.md`; `docs/evidence/QA-026/exp4-solve-2026-07-29.stdout`; `docs/audits/2026-07-30-audit-2x2-mismatch.md` | `e:GLOBAL.INVSYM`, `n:GLOBAL.BRUTE-ALIASING` | `QA-026` | 0 | ? | Z-TABLE |
| `3x3.BASICKO-TIE` | — | 3×3 | Fresh-start value of 3×3 under basic-ko + TIE=0: root = **+9** (L==H==9), matches the MIGOS II anchor, 73,758 reachable states, 0 UNDEF, 16 sweeps, colour-symmetric. Root is NOT TIE — scored +9, L==H==9. **Brute-force cross-check in stdout §7 withdrawn (T102 buffer-aliasing); fixpoint independently verified** | MEASUREMENT | `docs/evidence/QA-026/3x3/PROVENANCE.md`; `docs/evidence/QA-026/3x3/exp5-solve-2026-07-29.stdout`; `docs/audits/2026-07-30-audit-2x2-mismatch.md` | `e:GLOBAL.INVSYM`, `e:GLOBAL.MIGOS-RULE`, `n:GLOBAL.BRUTE-ALIASING` | `QA-026`, `3x3.ANCHOR` | 0 | ? | Z-TABLE |
| `4x4.BASICKO-TIE` | — | 4×4 | Fresh-start value of 4×4 under basic-ko + TIE=0: root = **+1**, bracket **[+1,+16]**, 147M states, 31 sweeps. T104 verified H=+16 genuine — 0 violations over 99,133,036 states, 0 map misses, exhaustive inversion clean — and concluded the +2 gap vs the MIGOS II anchor is a **ruleset difference in tie resolution (TIE=0 vs MIGOS's implementation-specific long-cycle-tie value)**, not a bug. **Corrected 2026-08-02 (T271): the prior 'basic ko vs PSK' explanation is contradicted by `GLOBAL.MIGOS-RULE` (MIGOS plays basic ko, not PSK); the surviving explanation is the tie-semantics difference (`GLOBAL.TIE-MIGOS`).** **Corrected 2026-08-03 (T279 absorption): the tie-semantics explanation is refuted by primary sources (T274) — MIGOS's long-cycle-tie value is 0, identical to our TIE=0 (thesis §5.3.2; ICGA 2009 §3.3), and MIGOS's own basic-ko 4×4 result is +1 = ours (thesis Table 5.1); the surviving explanation of the +1-vs-+2 gap is a **different game** (pass-difference cycle resolution, thesis Appendix A §A.4), not tie semantics and not a build defect.** The row is corrected-as-of-T271 and stale-as-of-T279; the T279 correction supersedes the T271 text. Record +1 as the reading; do not record it as contradicting the +2 anchor without stating the ruleset difference (`GLOBAL.TIE-MIGOS` FALSE-AS-SCOPED) | MEASUREMENT | `docs/evidence/QA-026/4x4/PROVENANCE.md`; `docs/evidence/QA-026/4x4/exp6-solve-2026-07-29.stdout` | `e:GLOBAL.MIGOS-RULE`, `e:GLOBAL.TIE-MIGOS`, `e:4x4.BRACKET` | `QA-026`, `4x4.ANCHOR`, `GLOBAL.H1` | 0 | ? | Z-TABLE |
| `GLOBAL.PASS-NOKO` | — | all | Structural invariant of the basic-ko state graph: **`passes ≥ 1 ⇒ ko_point = none`** — a pass captures nothing, so no ko point can accompany a nonzero pass count; the solver encodes every pass child with `KO_NONE` directly (`src/exp6_solve.zig:964`, pinned at `082433e`). Independently re-derived in the oracle-v2 M1 design re-audit (T146; ephemera archived, finding carried by the canonical design §2.5). Consequences: the `passes ≥ 1` slot set is bounded (no ko column), yielding the ≤ 36-entries-per-group bound in the WZO2 segregated index at 4×4; and pass edges are strictly monotone in `passes`, so **a pass edge cannot close a cycle** — cycle-reachability computed on the `(board, side, ko)` projection (51,419,046 nodes at 4×4) is sound for verify-battery I5 (T134 §structural, option A vs B). New row minted 2026-07-31 (Fable/Consul absorption catch-up) | PROVEN (code + independent re-derivation) | `src/exp6_solve.zig:964`; `docs/epic-01-markovian/sprints/oracle-v2/pass0/design-M1.md` (§2.5 invariant) | — | `4x4.I5-FEAS`, WZO2 group-index sizing, verify-battery I5 node count | 0 | ? | Z-R-STATE |

### 2.8 Open hypotheses (H) — the 2026-07-27 register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.H1-MARKOV` | — | all | The state-representation half of the former conjoined `GLOBAL.H1`: under simple ko + a fixed-value long-cycle verdict, the state `(position, side, ko_point, passes)` is **Markovian** (sufficient for exact solving). **Split 2026-07-29 per `CLAIMS-SPLIT-CONJUNCTS`** — the computational half (`GLOBAL.H1-COMPUTABLE`) is a separate row because it depends on `GLOBAL.LONGCYCLE` (now FALSE-AS-SCOPED). **UNTESTED.** C1 has never been tested with contrasting histories: the history generator misses the shortest arrival in 93% of states with ~62% shared prefixes (`2B-3-AUDIT`). Cross-reference `QA-023`: the Markovian claim survives; the value formula fell (`qa023-c2-adjudication-2026-07-29.md` §3). | UNTESTED | `open-hypotheses:30-118`; `PROGRESS.md:169-183`; `docs/audits/2b-3-audit-*.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md` §3 | `n:GLOBAL.C2`, `n:GLOBAL.C3`, `n:GLOBAL.C4` (the pivot is motivated by their falsity), `d:GLOBAL.CHAIN-KO` (the mismatch this diagnoses) | project direction; a new ADR; `GLOBAL.H1-CENSUS`, `3x3.H1-CENSUS`, `4x3.H1-CENSUS` GO/NO-GO; `GLOBAL.R1`, `GLOBAL.R2`, `GLOBAL.RPLY`, `GLOBAL.RPLY-TRAP`, `GLOBAL.MIGOS-RULE`, `GLOBAL.ANCHOR-DELTA`, `GLOBAL.PSK-GAP` | 0 | ? | Z-R-TIE |
| `GLOBAL.H1-COMPUTABLE` | — | all | The computational half of the former conjoined `GLOBAL.H1`: a table over `(position, side, ko_point)` under simple ko + long-cycle-ties would be **chainable by construction** (computable by the existing converge machinery). **Split 2026-07-29 per `CLAIMS-SPLIT-CONJUNCTS`.** **FALSE-AS-SCOPED (3×2).** The existing converge machinery with a pointwise tie-pin does NOT compute the history-conditioned value (`2B-PROBE-FIX`, `2B-6`, `PINRULE-SUFFICIENCY`/`QA023-KERNEL-AUDIT`). On the corrected kernel, C1 is falsified under ADR-0019 truncation semantics. Whether ANY pointwise function of `(L,TIE,H)` can compute the value is open. | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2026-07-29-2b-6-full-review.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `docs/audits/2026-07-29-qa023-kernel-audit.md`; `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md` | `d:GLOBAL.LONGCYCLE` | any simple-ko build; `QA-023` (the "computable" half of the restatement); `GLOBAL.ONEMISMATCH-CURE` | 0 | ? | Z-R-TIE |
| `GLOBAL.H1-CENSUS` | H1 census | 4×4 | Reachable `(position, ko_point, side)` triple count at 4×4 is a small multiple of the 48,636,330 slots (naive dense bound: 3^16 × 17 × 6 B = **4.39 GB**, 17× the current artifact). **Measured exactly 2026-07-28 (EXP-3): 51,419,046 reachable triples = 1.057× the 48,636,330 slots; 29,497,329 distinct `(b, ko)` addresses = 4.031% of the naive dense 731,794,257; 176,983,974 B = 177 MB at 6 B/address = 0.69× the current PSK artifact; 29 sweeps to fixpoint. GO on dense addressing.** No sampling, no striding. **The 354 MB with-passes figure is arithmetic (177 MB × 2 sides), not an independent measurement** | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:23,228-241`; calibration at 4×4: `4x4-ko-disabled.txt` (known-good), `4x4-broken-every_capture.txt` (known-bad, +91%) | `e:GLOBAL.S3a` (the OEIS A094777 legal-count known-good the census reproduces: 24,318,165) | `GLOBAL.H1` GO/NO-GO, `4x4.D3` budget (≤ 32 GB placeholder → measured 177 MB; 354 MB with-passes is 177 MB × 2, arithmetic not measured) | 0 | ? | Z-STATE-REACH |
| `3x3.H1-CENSUS` | — | 3×3 | Reachable `(position, side, ko_point)` census at **3×3** under the standard basic-ko detector, exact: **22,736** reachable triples, **13,997** distinct `(b, ko)` addresses = **7.111%** of the naive dense 196,830, 83,982 B at 6 B/address, 16 sweeps. `ko_point = none` on 12,101 of 13,997 addresses (86.4%). New row minted 2026-07-28 — the ID was already cited by `docs/infra/dispatch/EXP-3.md` and `docs/status/CURRENT.md` with no register row | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/3x3-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:21,201-218`; calibration at 3×3: `3x3-ko-disabled.txt`, `3x3-broken-every_capture.txt` (+60%), `3x3-broken-every_move.txt` (+84%) | `e:GLOBAL.S3a` (OEIS A094777 known-good reproduced at 3×3: 12,675) | `GLOBAL.H1` GO/NO-GO | 0 | ? | Z-STATE-REACH |
| `4x3.H1-CENSUS` | — | 4×3 | Reachable `(position, side, ko_point)` census at **4×3** under the standard basic-ko detector, exact: **638,266** reachable triples, **375,281** distinct `(b, ko)` addresses = **5.432%** of the naive dense, 2,251,686 B at 6 B/address, 25 sweeps. New row minted 2026-07-28; ID previously dangling. **Calibration caveat, stated not hidden:** the broken-detector known-bads were run at 3×3 and 4×4 only, **not at 4×3**, and 4×3's legal-count known-good (321,689) is the project's own ground truth rather than a published figure. The known-bad is inherited as a property of the *detector code* (one binary, goban size a compile-time parameter) per **ADR-0016** clause 2 | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/4x3-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:22,220-226` | `e:4x3.S3a` (the 4×3 legal count 321,689, independently reproduced by the census enumerator), `d:GLOBAL.ADR0016-INHERIT` (the calibration inheritance this row relies on) | `GLOBAL.H1` GO/NO-GO | 0 | ? | Z-STATE-REACH |
| `4x4.G-CENSUS` | — | 4×4 | The group count **G** at 4×4 — the number of distinct **boards** (colex indices) the WZO2 segregated index ranges over (the implementation groups by board alone, `src/artifact2.zig:316-319`, matching design §F1; this row's earlier "(board, ko)" wording was looser than the code) — is **measured, bracketed within 2.2%**: **23,802,969 ≤ G ≤ 24,318,165** (lower witness: standard-detector census distinct `(b, ko = none)` addresses; upper witness: the legal position count = OEIS A094777(4) = 24,318,165); third witness 23,813,121 (ko-disabled census) lies inside the bracket. Supersedes the oracle-v2 spec/design sentence that G is "not directly measured by any census" (T142/T146 finding). Structural cross-check: N/G = 99,133,036 / ≈23.8M ≈ **4.16** entries/group vs the structurally predicted 4, residual explained by the 5,694,360 ko-cell addresses — two independent measurements agreeing with a structural argument to 4%. Caution: EXP-3's 102,838,092 is 2 × 51,419,046 by arithmetic and is **not** an independent cross-check. Finding surfaced by the T142/T146 audits (ephemera archived); derivation carried by the canonical design §F2. New row minted 2026-07-31 (Fable/Consul absorption catch-up). **The bracket is measured; the artifact-G test of it is still pending — the WZO2 builder has never run (`CODE.WZO2-UNRUN`)** | MEASUREMENT | `docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/4x4-ko-disabled.txt`; `docs/epic-01-markovian/sprints/oracle-v2/pass0/design-M1.md` (§F2 byte-budget derivation) | `e:GLOBAL.H1-CENSUS`, `e:GLOBAL.S3a` | WZO2 F2 byte budget (515.5–532.9 MB vs the 600 MB R9 ceiling), `4x4.D3` budget | 0 | ? | Z-COMPLETE-ENUM |
| `GLOBAL.LONGCYCLE` | — | all | "Long cycle = tie" is a loopy-game fixpoint computable by the existing converge machinery — **UNVERIFIED and must not be asserted**; any candidate must resolve cycles without knowing which earlier gobans were seen, or it has smuggled score-on-cycle back in. **FALSIFIED at 3x2 2026-07-29 (2B-PROBE-FIX + 2B-6): the existing converge machinery with a pointwise tie-pin does NOT compute the history-conditioned value. Whether ANY pointwise function of (L,TIE,H) can is open — task `PINRULE-SUFFICIENCY`.** **⚠ 2026-07-29 (night) — SCOPE SPLIT. `fixpoint_kernel`'s White-branch defect is VERIFIED by two independent seats (`Kimi-k3/PINRULE-SUFFICIENCY` found it; `Kimi-k2.7/QA023-KERNEL-AUDIT` reproduced all three evidence lines from scratch in Python, no Zig imported). Corrected kernel validated three ways: agrees with `smoke_fixpoint_2x2`, Bellman residuals 0/0, colour-inversion violations 0. Corrected 3x2 census `2232/322/34/34` replaces the buggy `948/1532/142/0`. **T138 (2026-07-31, `docs/evidence/QA-023/census-reconciliation.md`) reconciled the 2232/322/34/34 corrected kernel census (42-seed) against EXP-4's 2220/298/34/34 (retrograde engine, bug-free): the +36 delta = 36 empty-goban-with-ko-point phantom seeds (12→L==H, 24→pin_T), excluded by the true-game-root (4-seed) convention. cycle-reachable spread: 1,724→1,704→1,678, with 1,678 authoritative.** **On the CORRECTED kernel the verdict differs by semantics:** for the **history-conditioned** rule (first-revisit truncation, ADR-0019) this is **FALSE at 3x2** — C1 witness `(178,0,6,0)`, goban `[B,W,B,_,W,_]`, Black to move: two valid arrivals give truncation values **-3** and **-6** while the corrected fixpoint gives `L=H=-6`. For **fresh-start (shortest-arrival)** semantics the corrected tables remain consistent (`396/396` agreements in PINRULE-SUFFICIENCY; spot-checked independently) — a different object, and **UNTESTED** rather than true. Remaining gap, named by the auditor itself: the ~22-node witness tree was **not dumped and hand-verified** — task `QA023-C1-WITNESS`. Evidence: `docs/audits/2026-07-29-qa023-kernel-audit.md`, `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`.** | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2026-07-29-2b-6-full-review.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `open-hypotheses:92-103` | `d:GLOBAL.R2` (the foreclosure constraint) | `GLOBAL.H1`, any simple-ko build | 0 | ? | Z-R-TIE |
| `GLOBAL.H2` | H2 | 4×4 | The greedy player's loss rate strictly exceeds the arena's random-persona leak rate | UNTESTED | `open-hypotheses:122-166` | `d:4x4.GREEDY-BIAS`, `e:4x4.B43` | relabelling or retiring the 3.4% figure | 0 | ? | RETIRED |
| `GLOBAL.H3` | H3 | 4×4 | There is an empty-point count below which memo-free, bracket-free, history-exact 4×4 search under the real history is affordable at play time | UNTESTED | `open-hypotheses:170-214` | `n:GLOBAL.F1` (memo-free *because* the sound memo does not exist) | `GLOBAL.H5b` | 0 | ? | RETIRED |
| `GLOBAL.H3-LOWERBOUND` | H3 context | 2×2/3×2 | The 2026-07-27 re-measurement (empty 2×2 = 2.3M nodes / 132 ms; empty 3×2 did not finish in 100 s) is a **lower bound on achievable performance**, not a measurement of the method — the probe used a linear history scan and neither `zobrist.zig` nor the `scount`/`armed` prune | MEASUREMENT | `open-hypotheses:172-182`; `ko-sensitive-chainability.md:269-274` | — | `GLOBAL.H3` | 0 | ? | RETIRED |
| `GLOBAL.H4` | H4 | 4×4 | FP1 acceptance check 3 has two residual gaps: (a) the `lo`/`hi` bracket tables were never checked (WZO1 carries no bracket columns); (b) 4×4 was a 1:37 sample | CLAIMED (partial) | `open-hypotheses:217-261`; `PROGRESS.md:77-81,221-223` | `d:4x4.FP1-C3` | `4x4.FP1` | 0 | ? | Z-CONVERGE-FIX |
| `GLOBAL.H4a` | H4(a) | 4×4 | V0/V1 identity on the in-memory `Retro(4,4).Tables.lo`/`.hi` quads | UNTESTED | `open-hypotheses:224-228,233-235` | `d:4x4.D3` (needs a build) | `GLOBAL.H4`, `4x4.FP1` | 0 | ? | Z-CONVERGE-FIX |
| `GLOBAL.H4b` | H4(b) | 4×4 | Exhaustive (stride 1) chainability sweep at 4×4 | UNTESTED | `open-hypotheses:229-231,236-239` | — | `GLOBAL.H4`, removes `4x4.M4`'s sampling caveat | 0 | ? | Z-CONVERGE-FIX |
| `GLOBAL.H5` | H5 | 4×4 | The GTP player can be made to stop asserting mispriced numbers **without resolving any open epistemic question** | CLAIMED | `open-hypotheses:265-313` | `d:4x4.GTP-DEFECT` | deliverable decision | 0 | ? | RETIRED |
| `GLOBAL.H5a` | H5(a) | 4×4 | Restricting table steering to the chainable L==H region is **sound but weak** — on 4×4 it gives no table guidance from move one | CLAIMED | `open-hypotheses:274-279` | `d:GLOBAL.CHAIN-LH`, `e:4x4.M5` | player fork | 0 | ? | RETIRED |
| `GLOBAL.H5a-CHILD` | H5(a) correction 1 | 4×4 | **A 1-ply Bellman-identity check at the current node is NOT sufficient** to license table steering — the **chosen child** must be checked too. Ruled 2026-07-28 (D-3, Opus) as a condition of H5(a) shipping. The demonstrating instance is `4x4.A-3`: at ply 14 the node's own V0 was −3 while the child the player chose was −16, so a node-only check passes exactly where the player is about to be wrong. **Implementation shipped (EXP-9, Opus 5, 2026-07-29):** child-side refuse-on-divergence check + settled-area fallback in `src/gtp.zig`; a sign defect in the draft was found and fixed (pinned by a new antisymmetry test); +6.8%/genmove. **Acceptance 4 PARTIAL** — the A2 mechanism fires at ply 13 not ply 7 (structural reason in `docs/research/h5a-player-mitigation-2026-07-28.md` §5). **CLAIMED, not verified-optimal.** | CLAIMED | ruling D-3, 2026-07-28; EXP-9 2026-07-29 (`docs/research/h5a-player-mitigation-2026-07-28.md`); `corrections:99-132`; `regressions/4x4-black-win-after-ko.txt:74`; `open-hypotheses:274-279` | `n:4x4.A-3` (the requirement exists *because* "the player is fresh-start-perfect" is false at the chosen child; if `4x4.A-3` were rehabilitated the node-only check would suffice and this row would lose its reason to exist), `e:GLOBAL.CHAIN-LH`, `e:QA-014` | H5(a) implementation, `GLOBAL.H5` player fork | 0 | ? | RETIRED |
| `GLOBAL.H5a-FALLBACK` | H5(a) correction 2 | all | **"Refuse" must NOT mean pass.** When the identity check fails, the player falls back to a **history-free quantity** — settled area / Benson-alive territory — which is sound by theorem rather than by table lookup. Ruled 2026-07-28 (D-3, Opus) as the second condition of H5(a) shipping. Passing is a *move* with a value; refusing to price a position is not. **Implementation shipped (EXP-9, Opus 5, 2026-07-29):** the fallback is the settled-area / Benson-alive quantity in `src/gtp.zig`. **CLAIMED, not verified-optimal** (same EXP-9 run as `GLOBAL.H5a-CHILD`; same PARTIAL caveat). | CLAIMED | ruling D-3, 2026-07-28; EXP-9 2026-07-29 (`docs/research/h5a-player-mitigation-2026-07-28.md`); `open-hypotheses:281-284` (the H5(b) history-free-by-theorem argument this reuses); `0004:16-19,31-34` | `d:GLOBAL.S2`, `d:GLOBAL.ADR0004-TERM`, `e:GLOBAL.H5b` | H5(a) implementation, `GLOBAL.H5` player fork, `src/gtp.zig` genmove | 0 | ? | RETIRED |
| `GLOBAL.H5b` | H5(b) | 4×4 | History-exact search to a Benson-settled horizon is sound (the settled area score is history-free by theorem) | CLAIMED | `open-hypotheses:281-284` | `d:GLOBAL.S2`, `d:GLOBAL.ADR0004-TERM`, `d:GLOBAL.H3` | player fork | 0 | ? | RETIRED |
| `GLOBAL.H5c` | H5(c) | 4×4 | Bracket-cut search is tractable (≤3.5e5 nodes for the empty 4×4 root vs >5e8) but **NOT shippable as sound** — cutting on `[L,H]` under a real history *is* claim C3 | PROVEN (as an implication) | `open-hypotheses:286-291`; `ko-sensitive-chainability.md:276-281` | `d:GLOBAL.C3`, `e:GLOBAL.FIN-BRACKET` (retired 2026-08-03 T330 — evidence retired; needs re-derivation; was sole `e:` source, no surviving register artifact) | §4-O1 (this is the edge that orphans the finisher) | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.H5d` | — | all | Bounded-history state is the representational route to a real-game claim — a new ADR, not a bug fix | CLAIMED | `open-hypotheses:288-289`; `ko-sensitive-chainability.md:288-289`; `AGENTS.md:71-73` | `n:GLOBAL.C2` | future work | 0 | ? | RETIRED |
| `GLOBAL.ONEMISMATCH-DIAG` | — | all | The diagnostic half of the former conjoined `GLOBAL.ONEMISMATCH`: the leak crisis, C2, C3, C4 and the chainability collapse are plausibly all symptoms of a **single mismatch** (non-Markovian rule, Markovian table) — an interpretation offered to organise the findings, **not a proved theorem**. **Split 2026-07-29 per `CLAIMS-SPLIT-CONJUNCTS`.** The cure half (`GLOBAL.ONEMISMATCH-CURE`) is a separate row. | CLAIMED | `PROGRESS.md:169-183` | — | framing only | 0 | ? | RETIRED |
| `GLOBAL.ONEMISMATCH-CURE` | — | all | The cure half of the former conjoined `GLOBAL.ONEMISMATCH`: the cure follows from the mismatch — that a simple-ko table resolves the symptoms. This assumed the long-cycle fixpoint works and the state is computable by the existing converge machinery (`GLOBAL.H1-COMPUTABLE`). **Split 2026-07-29 per `CLAIMS-SPLIT-CONJUNCTS`.** **FALSE-AS-SCOPED (3×2).** `GLOBAL.H1-COMPUTABLE` is FALSE-AS-SCOPED; the computational machinery does not produce the history-conditioned value. Has never been directly tested (its test is EXP-4…7, gated — `AUDIT-DSPro` §2.3). | FALSE-AS-SCOPED | `AUDIT-DSPro` §2.3; `docs/evidence/QA-023/probe-fix-2026-07-29.md` | `d:GLOBAL.H1-COMPUTABLE` | none (diagnostic only) | 0 | ? | Z-R-TIE |

### 2.9 Corrections ledger (2026-07-27)

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `4x4.A-1` | A-1 | 4×4 | "With PSK history from the capture/ko fight, W A4 gave Black +16" — the game's history removed White's winning move | FALSE-AS-SCOPED | `corrections:19-62`; commit `753584f`. **Remediated:** `regressions/README.md` now carries the corrected wording (verified 2026-07-28; `corrections:60-62`'s line-21 citation is stale) | `e:4x4.KO-RULE-NULL` | `4x4.GTP-DEFECT` (the corrected cause) | 0 | ? | RETIRED |
| `4x4.A-2` | A-2 | 4×4 | "The blunder is the C2 falsification in action" | FALSE-AS-SCOPED (category error — every blundering node is KO_SENSITIVE, i.e. outside C2's scope) | `corrections:66-96` | `e:GLOBAL.CHAIN-KO` | corrected attribution = `GLOBAL.C4` + unchainability | 0 | ? | Z-NONCLAIMS |
| `4x4.A-3` | A-3 | 4×4 | "The engine is *fresh-start perfect*, not *history perfect*" | FALSE-AS-SCOPED (the player is not fresh-start-perfect in the ko-sensitive region: node's own V0 = −3, chosen child = −16) | `corrections:99-132`; `regressions/4x4-black-win-after-ko.txt:74`. **Remediated:** `src/gtp.zig:42` now states "neither history-perfect NOR fresh-start-perfect" and `regressions/README.md:72,81` carries the correction (verified 2026-07-28; `corrections:107,130-132`'s `gtp.zig:37` citation is stale) | `e:4x4.M4` | `4x4.GTP-DEFECT` | 0 | ? | RETIRED |
| `GLOBAL.B-1` | B-1 | all | ADR-0013's Consequences: "The history-perfect genmove (GTP player) shares this machinery; it inherits the fix automatically" | FALSE-AS-SCOPED (as of the code at 2026-07-27) | `corrections:136-171`; `0013:129-130`; `src/gtp.zig:154-196,90-93,121-132`; `src/artifact.zig:23-53,140,181` | — | any plan assuming a finisher fix improves play | 0 | ? | RETIRED |
| `GLOBAL.C-1` | C-1 | all | (Transient) the chainability violations in the committed 4×4 artifact were the ADR-0013 bug resurfacing | FALSE-AS-SCOPED | `corrections:175-201` | `e:2x2.M4`, `e:3x2.M4` (calibration on known-good artifacts) | `GLOBAL.CHAIN-KIND` | 0 | ? | RETIRED |
| `GLOBAL.CALIB-LESSON` | C-1 lesson | all | A self-consistency check with no *passing* calibration case cannot distinguish "bug" from "definition" — every input looks guilty | PROVEN (methodological) | `corrections:197-201` | — | auditor practice | 0 | ? | Z-AUDIT |

### 2.10 Format, artifacts, and process claims

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `CODE.ADR0011-FMT` | — | all | WZO1 = 32-byte header + **six** frozen columns `vb\|vw\|fb\|fw\|db\|dw`; the reader REFUSES on any header mismatch; **no `lo`/`hi` bracket columns exist** | PROVEN | `0011:21-37`; `corrections:153-158`; `src/artifact.zig:23-53` | `d:GLOBAL.S1` | `GLOBAL.H4a`, `GLOBAL.B-1`, `4x4.FP1-C3` scope caveat | 0 | ? | Z-TABLE |
| `CODE.ADR0011-GATE` | — | all | `retro.saveArtifact` refuses to write unless the same process passed: finisher completed every orbit, 0 bracket-fails, 0 orbit-clashes, exhaustive symmetry PASS, **no UNDEF on any legal slot** — then reloads and byte-verifies | PROVEN | `0011:39-46` | `d:GLOBAL.P2` | `4x4.VALBATTERY`, §6-D13 | 0 | ? | Z-TABLE-CONSISTENCY |
| `CODE.ADR0011-DTT` | — | all | DTT is **best-effort** where optimal lines cross unfinished V1 slots; a later V1-finishing pass would tighten a side-file column without moving addresses | CLAIMED | `0011:63-65`; `0009:138-146` | — | DTT-based tie-breaks in `src/gtp.zig` | 1 | ? | RETIRED |
| `GLOBAL.ADR0009-DTT` | — | all | DTT = *fastest optimal resolution* (both sides play score-optimal and cooperate on speed), computed by a monotone-decreasing min-sweep; well-defined on the cyclic graph | PROVEN | `0009:138-146` | — | `CODE.ADR0011-DTT` | 0 | ? | RETIRED |
| `GLOBAL.ADR0012-GATE` | — | 3×3/4×4/6×3 | Any engine change must first reproduce the recorded **sha256** artifacts end-to-end on 3×3 / 4×4 / 6×3; no green gate, no big goban | CLAIMED (orphaned — depends on the retracted `4x4.COMPLETE-2026-07-21`; re-point to the Track A writes-off artifact when complete. T128 triage §C1a-8) | `0012:157-159`; `0012:46-49` | `d:4x4.COMPLETE-2026-07-21` (FALSE-AS-SCOPED — retired 2026-08-03 T330; re-point pending the Track A writes-off artifact, not yet citable — see `4x4.WRITESOFF`) | §4-O6 | 0 | ? | Z-TABLE-CONSISTENCY |
| `GLOBAL.ADR0012-PAR` | — | all | Converged tables are **byte-identical regardless of thread schedule** (unique least/greatest fixpoints; chaotic-iteration convergence of monotone maps), so final-hash verification survives parallelism | CLAIMED | `0012:160-166` | `d:GLOBAL.FP1`, `d:GLOBAL.FP3` | `4x4.PARALLEL`, all parallel builds | 0 | ? | Z-TABLE-CONSISTENCY |
| `GLOBAL.ADR0012-5X5` | — | 5×5 | 5×5 is feasible: ~53e9 canonical-legal slots, ~106 GB working files, ≤40 GB RAM, ~4–6 days on 10 cores. "A real plan, not a wish" | CLAIMED (projection; ADR status is *proposed*, measurements pending) | `0012:3,124-131` | `d:GLOBAL.SWEEPS`, `d:GLOBAL.F4-COST` | 5×5 roadmap (on hold) | 0 | ? | RETIRED |
| `4x4.I5-FEAS` | — | 4×4 | Verify-battery invariant **I5** (Tarjan SCC cycle-reachability) at 4×4 is **feasible under the runner's 4 GB RSS cap**: iterative Tarjan with rank-support bitsets and on-the-fly adjacency over the 51,419,046-node `(board, side, ko)` graph, three phases (350 MB → 392 MB → 1,078 MB), projected peak RSS **1.2–1.5 GB** (≈3.3× headroom), pre-Phase-3 RSS self-check, four fallback tiers — **tier F3 downgrades I5 from an exhaustive to a sampling claim and must be recorded as such if triggered**. Calibration measurements shipped in the memo and independently re-run by T137 (`scc2x2.py` reproduced): 2×2 true-root graph V=255/E=434, 96 SCCs (1 non-trivial), max SCC=160, 0 self-loops; all-seed V=282/E=508; 3×2 true-root V=2,583 with **1,678 cycle-reachable** non-terminals and max SCC = **1,676** — the reference denominators I5 is judged against (a result matching the phantom-inclusive 1,724 or 1,704 is `reference-bad`, not `artifact-bad`, per the T138 reconciliation). Discharges audit findings B2/C2. New row minted 2026-07-31 (Fable/Consul absorption catch-up). **Calibration status 2026-08-01 (T171, see `3x2.I5-CAL`): node counts reproduced exactly, edge counts and max-SCC NOT reproduced; the RSS projection remains wholly unvalidated — the harness RSS field is a stub returning null (`src/verify_battery.zig:369`) and no run has measured memory at any goban size** | CLAIMED (projection; the calibration section is MEASUREMENT) | `docs/epic-01-markovian/sprints/verify-battery/archive/i5-feasibility.md`; `docs/evidence/QA-023/census-reconciliation.md` | `d:GLOBAL.PASS-NOKO` (pass edges cannot close a cycle — the node-count soundness), `e:GLOBAL.H1-CENSUS` (the 51.4M node count) | verify-battery I5, G3 acceptance | 0 | ? | Z-STATE-REACH |
| `3x2.I5-CAL` | — | 2×2/3×2 | **T171's Tarjan implementation reproduces the committed I5 calibration references only PARTIALLY** (measured 2026-07-31, recorded in the rescued run log): node counts exact — 2×2 V=**255**, 3×2 V=**2,583**, non-trivial SCCs 1/1 ✓; edge counts NOT reproduced — 2×2 E=**566** vs reference 434 (+30%), 3×2 E=**7,364** vs 5,510 (+34%); max-SCC at triple projection **112**/**1000** vs references 160/1,676 — a projection-level mismatch never reconciled. **The committed 3×2 test gate `[988, 1012]` (`src/vb_graph.zig:1011-1014`) is self-calibrated, not reference-calibrated: 988 appears in no committed document, the committed Python reproductions yield 1,676, and the tolerance was chosen to admit the implementation's own 1000.** The 2×2 test asserts V only — E=434 and max-SCC=160 are asserted nowhere. No test compares against 1,678/1,724/1,704, so the T138 `reference-bad` convention is **untested**; the two tests that touch a real artifact are hard-skipped (`src/vb_graph.zig:1021,1033`) — the commit message's "8/8" = 10 declared − 2 skipped. Two CRITICAL pass-edge omissions (BFS and Tarjan/rev_adj) were found and fixed during T171's own audit — pre-fix V was 114, not 255 | MEASUREMENT (with the not-reproduced verdicts stated) | `docs/epic-01-markovian/sprints/verify-battery/archive/T171-final.md`; `docs/epic-01-markovian/sprints/verify-battery/archive/T171-audit.md`; `src/vb_graph.zig:988-1015` | `e:4x4.I5-FEAS` (the reference table this run was judged against) | I5 G3 acceptance — **blocked until the E/max-SCC discrepancy is reconciled against a committed reference** | 0 | ? | Z-AUDIT |
| `CODE.WZO2-CHAINSHORT` | — | n/a | **The WZO2 GTP path disables the chainability instrument.** `src/gtp.zig:286-288` (pinned `200b974`): `chainable_at_pos` returns `true` unconditionally when an Artifact2 is loaded ("Bellman identity holds by solver construction"); additionally a lookup miss silently falls back to an area-score terminal row (L=H=area, DTT=0) with no counter and no log. Consequence: **the UNCHAINABLE/refusal rate under WZO2 reads 0 by fiat, not by measurement** — spec A1 (v1 baseline: 10/10 plies refused) cannot be satisfied or falsified by this code path, converting the sprint's headline falsifiable prediction ("the full Markov key eliminates refusals") into an unfalsifiable assertion. The v1 branch retains the real check. T129/QA-027 is the precedent that "holds by construction" claims fail exactly where asserted | SUPERSEDED (2026-08-03, T269: true when written — the WZO2 chainability check WAS short-circuited; T261 later confirmed the code was fixed, `chainable_at_pos` now runs the real chain check for WZO2 in `src/gtp.zig`, so the row no longer describes the code. The register had no status for "true when written, overtaken by events" — this is its first use) | `src/gtp.zig:286-288` | — | spec A1, M4b acceptance, any WZO2 self-play measurement, `QA-020` successors | 0 | ? | RETIRED |
| `CODE.WZO2-UNRUN` | — | 4×4 | **[SUPERSEDED 2026-08-01 (Orcha/T193): the artifact was built (T192, `f851102`) and M4a did execute (T193) — and FAILED. Hazard class (a) is confirmed by `CODE.WZO2-PASSBIT`; hazard (b), the 4 GB write-time memory plan, is discharged (peak RSS 3887 MB). The row's prediction that "kanban done means code written, not run" was correct and is now paid off. Text below is as written 2026-08-01 (Fable/T177) and kept for the record.]** **Oracle-v2 P2 (T165–T167) delivered code only — no WZO2 artifact exists and no acceptance check has ever executed.** No `.wzo2` file anywhere; the builder (`zig-out/bin/weizigo-oracle-v2-build`) compiled but never ran; `docs/evidence/ORACLE-V2/` (spec-mandated M4a deliverable) does not exist. Every register prediction remains UNTESTED: G vs the `4x4.G-CENSUS` bracket, the 515.5–532.9 MB F2 budget vs the 600,000,000 B ceiling, DTT max vs the 254 clamp. Known hazards awaiting the first run: (a) **DTT sweep-cap/value-clamp aliasing** — `MAX_DTT_SWEEPS = 254` equals the value clamp (`src/oracle_v2_build.zig:188,240`), so a genuine DTT > 254 terminates the loop silently with states left at FAR(255), indistinguishable from cycle sentinels; no assertion on the final-changes count; (b) the write-time memory plan is untested — L/H tables + ~99M-key hash map + compact list (~793 MB) + entry rows (~397 MB) + file bytes (~516 MB) live concurrently, and whether this fits the 4 GB runner cap is open (the likely reason the run was never attempted); (c) M2a's byte-identity acceptance (v1 pipeline unchanged) was **not re-verified** after the T165 refactor of `src/exp6_solve.zig` moved the v1 writer into `main()`. Kanban "done" here means *code written*, not *run* — all three tasks were stamped done in the same second | SUPERSEDED (2026-08-03, T269: true when written 2026-08-01 — the artifact was built (T192) and M4a ran (T193) the same day, so "no artifact exists and no acceptance has run" stopped being true within hours; superseded by `CODE.WZO2-PASSBIT`. The row's own prose said the register had no status for "true when written, obsolete now" — SUPERSEDED is that status) | `src/oracle_v2_build.zig:188,240,469`; `src/artifact2.zig:42,177,316-319` | — | `4x4.G-CENSUS` test, F2 gate, `4x4.D3` budget, M4b | 0 | ? | RETIRED |
| `CODE.WZO2-PASSBIT` | — | 4×4 | **The first 4×4 WZO2 artifact was invalid: the builder encoded `passes=1` entries with `passes=0` in the key_byte.** `src/oracle_v2_build.zig:387` (pinned `f851102`) passed `0` where the pass count belongs, so `passes=0` and `passes=1` rows for the same `(board, side, ko = KO_NONE)` shared one sort key. M4a acceptance against the 518.1 MB artifact `a892d689…` (T193, instrument `src/oracle_v2_accept.zig` as wired by T182) **FAILED two of four checks**: A3 colour inversion 16,314,978 violations / 99,133,036 checked (16.5%), A9 reproducibility 24,252,631 entry-order violations; A5 round-trip PASS (0 / 1,021,991 sampled, stride 97) and A6 calibration PASS (all 3 fixtures caught). **Control: the 3×3 WZO2 artifact passes all four checks**, confining the defect to the 4×4 path and distinguishing a builder bug from a harness bug. One-character fix committed `5deec6b`; the artifact must be rebuilt and M4a re-run (T212) before oracle-v2 G3. Note the interaction with `GLOBAL.PASS-NOKO`: because `passes ≥ 1 ⇒ ko = none`, the collision is confined to the `KO_NONE` key bytes (0x40/0x42) — which is why exactly one violation per `(board, side)` appears in A9, ≈24.3M of them. Minted 2026-08-01 (Orcha/T193 absorption) | PROVEN (measured, both failing checks reproduced with counts; root cause read in the source and fixed) | `docs/evidence/ORACLE-V2/m4a-accept-T193-2026-08-01.md`; `docs/evidence/ORACLE-V2/m4a-accept-T193-2026-08-01.stdout`; `src/oracle_v2_build.zig:387` (`5deec6b`) | `d:GLOBAL.PASS-NOKO` | `CODE.WZO2-UNRUN`, oracle-v2 G3, `4x4.G-CENSUS` artifact test, F2 byte budget | 0 | ? | Z-STATE-KEY |
| `SPRINT-M4a-ACCEPT` | — | 4×4 | **M4a acceptance passes 4/4 on the rebuilt 4×4 WZO2 artifact** (`0c3366f0…`, T212, 2026-08-02): A3 colour inversion 0 violations / 99,133,036 checked; A5 round-trip 0 mismatches / 1,021,991 sampled at stride 97; A6 calibration all 3 fixtures caught; A9 reproducibility 0 entry-order violations. Reverses T193's FAIL after the passes-bit fix. **Scope caveat, load-bearing:** these four checks verify *internal consistency of the entries present*. They do not check completeness, and the artifact's absent `passes=1` entries are provably unreachable (`CODE.WZO2-PASS1-LAW`, confirmed independently by T266 and T277). A5's 1% stride sampling was never verified coprime to the group-size distribution (T215 self-report), so A5 PASS is materially weaker evidence than A3/A9 | PROVEN (measured, denominators stated) | `docs/evidence/ORACLE-V2/m4a-accept-T212-2026-08-01.md` | `d:CODE.WZO2-PASSBIT` | oracle-v2 G3 | 0 | ? | Z-TABLE-CONSISTENCY |
| `WZO2-4X4-VALID` | — | 4×4 | **Proposed by T212 as PROVEN and REFUTED on corrected grounds (T261→T266→T277, absorbed T279).** T212's findings proposed that the 4×4 WZO2 artifact at `0c3366f0…` is valid on the strength of M4a passing 4/4. It is not: the artifact is not a verified perfect oracle — structural completeness is established (`CODE.WZO2-PASS1-LAW`, the absent passes=1 entries are provably unreachable), but closure under the kernel move generator (C-A1/C-A2) and L/H value-correctness remain untested. The original refutation cited ~6.77M missing entries (51.7× overstated; true count = 131,068 unreachable) and a W+2 self-play (explained by the display-path defect `CODE.GTP-LHSIDE` and the pre-T265 ko rule, not by missing entries). **Still FALSE-AS-SCOPED — on corrected grounds.** The proposal was reasonable when made; recorded rather than deleted so the reasoning chain survives: passing every check we had did not make the artifact valid, because no check tested completeness or value-correctness | FALSE-AS-SCOPED (as "valid"; the artifact is structurally complete and internally consistent, but closure and L/H values are untested) | `findings/T261-m4b-triage.json`; `docs/evidence/ORACLE-V2/incompleteness-T266.md`; `docs/evidence/ORACLE-V2/incompleteness-verify-T277.md` | `d:CODE.WZO2-PASS1-LAW` (corrected from `CODE.WZO2-INCOMPLETE`) | oracle-v2 G3 | 0 | ? | Z-COMPLETE-ENUM |
| `CODE.WZO2-INCOMPLETE` | — | 4×4 | **REFUTED (T266, verified independently by T277, absorbed T279) — the artifact is NOT incomplete in the way claimed.** The T261 scan's ~6.77M figure was 51.7× overstated: the absent `passes=1` side-entries are exactly the **131,068 single-colour gobans** (65,534 all-Black + 65,534 all-White) and are **provably unreachable** — a single-colour goban can only arise from a placement by the opposite colour, which would leave at least one stone of that colour. Exhaustive scan over all 24,318,165 groups (T266; independently re-derived by T277): zero counter-examples in either direction, instrument calibrated with a seeded shift mutant. The W+2 self-play contradiction was the pre-T265 GTP ko rule + the display-path defect (`CODE.GTP-LHSIDE`), not missing entries — self-play at HEAD ends B+1. The artifact is **structurally complete at the entry level**; the passes=1 pass clause (`CODE.WZO2-PASS1-LAW`) and the single-colour-side law hold with zero exceptions. **The artifact is still not verified**: closure (C-A1/C-A2) and L/H value-correctness remain untested. **(Term "monochrome" superseded by "single-colour goban" per glossary, T285, 2026-08-03.)** | FALSE-AS-SCOPED (the stated claim is wrong as measured; the artifact's structural completeness is established but value-correctness is not) | `docs/evidence/ORACLE-V2/incompleteness-T266.md`; `docs/evidence/ORACLE-V2/incompleteness-verify-T277.md`; `findings/T266-incompleteness.json`; `findings/T277-verify-refutation.json` | `d:CODE.WZO2-PASSBIT` (the passes-bit bug was real; the artifact is accessible to all reachable entries) | oracle-v2 G3, A1 self-play, `4x4.G-CENSUS` artifact test | 0 | ? | Z-COMPLETE-ENUM |
| `WZO2.I2-CLEAN` | — | 3×3, 4×4 | **I2 colour-inversion holds exhaustively on both WZO2 artifacts** (independent re-implementation, T270, absorbed T279). 4×4 (`0c3366f0…`): 0 violations / 0 not_found / 99,133,036 checked. 3×3 (`d79c17cd…`): 0 violations / 0 not_found / 49,428 checked. Confirms T212's registered A3 result (SPRINT-M4a-ACCEPT) with a fully independent instrument per rule R8. **Calibration reading: I2 is blind to the passes=1 asymmetry** — the missingness is colour-symmetric (absent entries come in flip-pairs, so every present entry's inverse is present), so I2 must never be cited as covering the completeness defect class. The WZO2 artifact does NOT share the v1 basic-ko inversion defect (`4x4.V1-INVSYM-BROKEN`, ~11.66M violations ≈ 48%) | MEASUREMENT | `docs/evidence/BATTERY/i2-wzo2-T270.md`; `docs/evidence/BATTERY/i2-wzo2-T270/3x3-raw.json`; `docs/evidence/BATTERY/i2-wzo2-T270/4x4-raw.json`; `findings/T270-i2-wzo2.json` | `e:SPRINT-M4a-ACCEPT` (re-derived independently), `d:GLOBAL.INVSYM` | I2 battery cell, WZO2 artifact integrity | 0 | 0 / 99,133,036 (4×4); 0 / 49,428 (3×3) | Z-TABLE-CONSISTENCY |
| `CODE.WZO2-PASS1-LAW` | — | all | **The single-colour-side law: a WZO2 `passes=1` side-entry is absent exactly when the goban is single-colour in the opposite colour (T266, absorbed T279; term "monochrome" superseded by "single-colour goban" per glossary, T285, 2026-08-03).** Derivation: `passes=1` states have exactly one in-edge — a pass from `passes=0` (the census seeds only `passes=0` roots; placements always yield `passes=0`); the pass child is `(board, 1-side, KO_NONE, passes+1)`; a `passes=0` state is entered only by a placement, which always leaves ≥1 stone of the mover's colour. Hence `(P, s, KO_NONE, 1)` is reachable iff `(P, 1-s, ko, 0)` is, which requires a stone of colour `1-s` on P. Verified exhaustively over every group of both shipped artifacts: 3×3 — 1,020 one-sided, 1,020 single-colour, 0 counter-examples; 4×4 — 131,068 one-sided, 131,068 single-colour, 0 counter-examples. Stored `passes=1` counts equal `2*n_groups − single_colour` exactly at both sizes. Instrument calibrated with a shift mutant caught by three separate checks. **Consequence: there is nothing to fill and no rebuild is needed** | PROVEN (derivation from source + exhaustive scan of both artifacts, independently verified by T277, instrument calibrated) | `docs/evidence/ORACLE-V2/incompleteness-T266.md`; `docs/evidence/ORACLE-V2/incompleteness-verify-T277.md`; `docs/evidence/ORACLE-V2/t266_scan.py` | — (root claim: independently verified by exhaustive scan; the law stands regardless of the disposition of `CODE.WZO2-INCOMPLETE`) | oracle-v2 G3, `WZO2-4X4-VALID` corrected grounds | 0 | ? | Z-COMPLETE-PASSES |
| `CODE.ACCEPT-KOKEY` | — | n/a | **`src/oracle_v2_accept.zig:150-165` carries a second, unfixed copy of the pre-T265 ko rule (T266, absorbed T279), and that — not artifact coverage — is what fails A1/A2/A8.** Its `koAfterCapture` sets a ko point on any single-stone capture; the solver (`src/exp6_solve.zig:899-910`) and post-T265 `src/gtp.zig:731-743` set one only when the capturing stone is in atari with no friendly neighbour. The checker therefore builds keys the artifact was never built with and goes off-manifold. All ten sampled A1 refusals are at `passes=0` with a non-none ko — none at `passes=1`, none at `ko=none`. One refusal traced end-to-end (3×3 colex=14717, ko=6): the group is complete, no ko point arises under the correct rule, A1's walk cannot reach it. Fourth member of the producer/consumer key-disagreement family after T178, T193, T265. Fix scope for T273 | PROVEN (source comparison + checker's own refusal output + one end-to-end trace, confirmed by T277) | `docs/evidence/ORACLE-V2/incompleteness-T266.md`; `docs/evidence/ORACLE-V2/incompleteness-verify-T277.md`; `findings/T266-incompleteness.json` | — (root claim: source-level finding verified by direct comparison; stands independently of `CODE.WZO2-INCOMPLETE`) | T273 (fix), A1/A2/A8 battery cells, oracle-v2 G3 | 0 | ? | Z-STATE-KEY |
| `CODE.GTP-LHSIDE` | — | n/a | **`src/gtp.zig:1222-1225` displays the bracket for the wrong side to move on every genmove (T266, absorbed T279).** The `lh_suffix` block calls `bounds2(&s.pos, …, side)` after `applyMove`, querying the post-move position with the mover still named as side to move. On the opening move that state is single-colour and legitimately absent (the reproducible `colex=12 side=1 ko=16 passes=0` miss). Everywhere else the wrong-side query silently succeeds and prints a wrong bracket. Display/telemetry only: the move choice from `choose_with_check` is unaffected. Reproduced at HEAD `63e245f`; four plies cross-checked against direct artifact lookups. Fix scope for T283. **(Term "monochrome" superseded by "single-colour goban" per glossary, T285, 2026-08-03.)** | PROVEN (reproduced at HEAD, four plies cross-checked; independently confirmed by T277) | `docs/evidence/ORACLE-V2/incompleteness-T266.md`; `docs/evidence/ORACLE-V2/incompleteness-verify-T277.md`; `findings/T266-incompleteness.json` | `d:CODE.WZO2-PASS1-LAW` (the single-colour-side law explains why the wrong-side query's miss is real but irrelevant) | T283 (fix), GTP display path, self-play diagnostics | 0 | ? | RETIRED |
| `CODE.CLAIMLINT-C7-NEWROWS` | — | n/a | **Claimlint's C7 reads only the FIRST `new_rows` entry per findings file and mis-parses its status (T266, absorbed T279).** (1) *Truncation.* The hand-rolled brace scanner breaks out of `new_rows` after the first row object closes: `if (nr_depth == 0 and nr_count > 0) break;` (`src/claimlint.zig:1676` at HEAD `c344f02`). Proved by A/B on T266's file: ordering determines which row surfaces, and `new-rows touched` reports 2 (one from T172-gap5.json + one from this file) regardless of how many rows the file holds. (2) *Status mis-parse.* After matching the key `status`, `ns` is left on that key's closing quote and the skip set omits `'"'`, so every new row's proposed status reads as `: ` regardless of content. Both are one-line fixes. C7's count is a **floor**, not a census; do not treat "C7 clean" as "everything absorbed". Fix scope for T269 | PROVEN (A/B experiment on four-row findings file + source read) | `docs/evidence/ORACLE-V2/incompleteness-T266.md`; `findings/T266-incompleteness.json` | — | T269 (fix), absorption queue, C7 gate decision | 0 | ? | Z-AUDIT |
| `CODE.GTP-KOKEY` | — | all | **The GTP engine and the solver disagreed on when a ko point exists — the third producer/consumer key mismatch.** `gtp.zig` `koAfterCapture` set a ko on **any** single-stone capture; `exp6_solve.zig:285,575` sets one only when the capturing stone is itself in atari with no friendly neighbours (`liberties == 1 and friendly == 0`). The engine therefore built lookup keys the solver never enumerated, missed the table, fabricated an area-score terminal row, failed the Bellman comparison, refused as UNCHAINABLE, and played the greedy history-free fallback — losing both human games and filling its own two-point eye in one. **One wrong ko determination puts a game off-manifold**: every later lookup misses regardless of its own ko field, which is why misses appeared at `ko=0` and `ko=16`. Fixed `626ec55`; verified by replaying both human transcripts — misses 14→0 and 12→0, refusals 2→0 in each. Family: T178 (exp6 rank vs colex), T193 (passes bit), this. **No test asserts that the key the consumer constructs equals the key the producer wrote**; that invariant is still owed | PROVEN (root cause read in source, fix verified by transcript replay) | `docs/evidence/ORACLE-V2/ko-key-mismatch-T265.md`; `docs/evidence/ORACLE-V2/human-game-{1,2}.gtp`; `src/gtp.zig` (`626ec55`) | — | engine trustworthiness, A1 self-play | 0 | ? | Z-STATE-KEY |
| `4x4.V1-INVSYM-BROKEN` | — | 4×4 | **The v1 4×4 basic-ko artifact violates colour-inversion symmetry on roughly half its positions.** `data/oracle-4x4-basicko-tie-area.wzo`: **11,658,047 deduplicated violations of `V(-pos,-side) == -V(pos,side)` out of ~24.3M legal positions ≈ 48%** (T260, 2026-08-02). Verified by an independent Python re-implementation of the colex bijection and inversion per rule R8 — the checker does not import `src/`. Violations cluster at low colex indices (few stones), e.g. colex 6, 11, 14, 20, 24. Checkpoint and parallel-checkpoint artifacts pass I2 with 0 violations; only the basic-ko artifact fails. **I2 is now confirmed clean on the WZO2 artifact as well (`WZO2.I2-CLEAN`; T270, 2026-08-02: 0/99,133,036 at 4×4, 0/49,428 at 3×3, independently re-implemented)** — the WZO2 artifact does NOT share this defect. Any claim resting on the v1 4×4 basic-ko artifact needs re-examination | PROVEN (independent re-implementation, deduplicated count; I2 on WZO2: T270) | `docs/evidence/BATTERY/triage-T260.md`; `findings/T260-fleet-triage.json`; `docs/evidence/BATTERY/i2-wzo2-T270.md` | — | every claim citing `data/oracle-4x4-basicko-tie-area.wzo` | 0 | ? | Z-TABLE-CONSISTENCY |
| `CODE.WZO1-DTT-UNSET` | — | all | **The DTT column was never computed for the WZO1 artifacts produced by the PSK retrograde engine — every value is the `@memset(dtt, DTT_FAR)` initialiser (255).** Confirmed at 2×2, 3×2, 3×3 and 4×3 by battery invariant I7, and by Python spot-check of `data/oracle-4x4-basicko-tie-area.wzo` (first and last 10K entries: `unique == {255}`). Decisive contrast: `data/reuse-baseline/oracle-4x4.wzo`, also WZO1 format from a different build, carries **31 distinct DTT values including 0** — so the column is populable and simply was not populated. The battery's own test already asserted this artifact must fail I7. **The checker is correct; the artifacts are empty.** The initialiser is the defect: pre-filling with FAR makes "never computed" indistinguishable from the legitimate answer "no finite distance". Proposed remedy: a distinct UNSET sentinel, so an unpopulated cell identifies itself | PROVEN (I7 across four gobans + independent spot-check + positive contrast artifact) | `docs/evidence/BATTERY/triage-T260.md`; `docs/evidence/BATTERY/fleet.md` | — | any claim resting on WZO1 DTT, A8 | 0 | ? | RETIRED |
| `CODE.BATTERY-STUBBED` | — | all | **Every verify-battery output produced before 2026-08-02 came from `stubCheck()` returning `skipped` — the battery had never actually run.** `src/verify_battery.zig` dispatched all invariants to a stub; the real implementations in `vb_table.zig`, `vb_fixpoint.zig` and `vb_graph.zig` were never wired into the binary. The residue is visible in `docs/evidence/BATTERY/2x2-psk-stub.jsonl` and `3x2-psk-stub.jsonl`, where every entry is `skipped` or `not-applicable`. T258 wired the modules and produced the first real execution: 60 cells, 36 PASS / 8 FAIL / 6 ERR / 10 n/a. **Consequence: any claim citing battery evidence dated before 2026-08-02 rests on a stub, not a measurement** | PROVEN (source inspection + the stub output files) | `docs/evidence/BATTERY/fleet.md`; `findings/T258-context.json` | — | every pre-2026-08-02 battery citation | 0 | ? | Z-AUDIT |
| `CODE.M4A-HARNESS` | — | n/a | **The M4a acceptance harness (`src/oracle_v2_accept.zig`, 1,178 lines, 22 unit tests) is orphaned and part-defective.** (a) It is in **no build graph** — absent from `build.zig` and from `src/main.zig`'s test imports — so its 22 tests have never been shown to compile, let alone pass; (b) **fixture (c) of A6 is a broken positive control**: `:628` calls `checkDttNonConstant(entries, …)` on the original uncorrupted slice instead of the `corrupted` copy built at `:614-627`, so on real data A6 would report a defect for the wrong reason — the same 2B-5 positive-control class the sprint doc names as its own scar; (c) **A9 is silently relaxed vs spec**: implemented as embedded-hash self-consistency, not clean-clone reproducibility, with no R8 call-out; (d) A5's sampling stride 97 (~1.02M of ~99.1M entries) is printed at runtime but recorded nowhere. Scope note: only A3/A5/A6/A9 are in this harness; A1/A2/A4/A7/A8 are M4b/O-8, deferred | PROVEN (by inspection) | `src/oracle_v2_accept.zig:19-20,493,628,682-700`; `build.zig:172-180` | — | M4a/M4b acceptance validity, `CODE.WZO2-UNRUN` | 0 | ? | Z-AUDIT |
| `CODE.VB-STUBS` | — | n/a | **The verify-battery harness is not wired to any invariant module and has produced zero real verification runs.** `src/verify_battery.zig:26-27` imports only `vb_common`; every invariant routes through `stubCheck()` (`:357-373`) returning `skipped`/`not-applicable` with `value=null`, `rss_hwm_after_mb=null` (RSS measurement stubbed out — Zig 0.16 API friction), `duration_ms=0`. I11 (`src/vb_fixpoint.zig:545-547`) and I8 (`:540`) are permanent `not_applicable` stubs. The JSON-Lines writer is hand-rolled **without string escaping** (std.json abandoned under Zig 0.16 churn). Test inventory: **36 declared** (19 vb_table + 7 vb_fixpoint + 10 vb_graph), 34 executable (2 hard-skipped), ~31 asserting (two vb_fixpoint tests are print-only — downgraded when the committed 2×2/3×2 artifacts turned out to be **PSK `rules_id=1`, not basic-ko**, so I7/I9 expectations mismatched the fixtures); the absorb commits' "43 tests" is unreconciled with the code. None of the 36 run under `zig build test` (the test root never imports `vb_*`); the 4×4 must-fail test reads git-ignored `data/` and silently no-ops on a clean clone | PROVEN (by inspection) | `src/verify_battery.zig:26-27,357-373`; `src/vb_fixpoint.zig:502-547`; `docs/epic-01-markovian/sprints/verify-battery/archive/T168-notes.md` | — | every future battery result, G3 acceptance, `4x4.I5-FEAS` RSS validation | 0 | ? | Z-AUDIT |
| `CODE.VB-BLINDGAPS` | — | n/a | **T172's blind reimplementation of the verify-battery design found five specification gaps** (verdict: "YES, with five documented gaps"; analysis rescued to the sprint archive). **GAP-5, CRITICAL: invariant I11 (move-set consistency) requires a solver-side dump file whose format is specified NOWHERE** — the design schema names `solver_dump_path` but never defines the format, and design §5's L/H-dump paragraph defines itself circularly as "the same shape as I11's dump"; I11 cannot be independently re-implemented. T172's on-record recommendation "resolve GAP-5 before dispatching V-8" was **not honoured** — V-8/T170 shipped `checkI11()` as a permanent `not_applicable` stub, silently converting a critical spec gap into dead scope. The remaining four: GAP-3 (moderate — spec I7 requires a DTT-recurrence check the result schema has no field for), GAP-1 (moderate — I4's Φ from TIE-pinned children may not equal the true fixpoint value; design notes it, spec §4 does not), GAP-4 (minor — I10 `tie_not_median` is dead code under V=median(L,TIE,H)), GAP-2 (minor — I6 `legal_both_sides`/`legal_one_side_only` ambiguous between partition and overlapping counts). GAP-5 also blocks the WZO1 L/H-dump option in the pending human bracket-verification decision | PROVEN (blind-reimplementation audit, committed) | `docs/evidence/CODE.VB-BLINDGAPS/T172-blind-analysis.md`; `src/vb_fixpoint.zig:545-547` | — | I11, V-8/M3, the WZO1-brackets human decision, spec/design amendment before G3 | 0 | ? | Z-AUDIT |
| `GLOBAL.ADR0012-LAYER` | — | 5×5 | Single 5×5 layers exceed RAM raw (peak layer k=17 ≈ 1.42e11 slots = 142 GB at 1 B/slot) → layered streaming alone does not save 5×5 | PROVEN (arithmetic) | `0012:91-95` | — | `GLOBAL.ADR0012-5X5` | 0 | ? | RETIRED |
| `GLOBAL.ADR0012-V1` | — | all | V1 is never stored — recomputed inline during a slot's own update; the quad shrinks 4 → 2 scores per fixpoint per slot | PROVEN | `0012:99-102` | `d:GLOBAL.ADR0005-PASS` | RAM-lean engine | 0 | ? | RETIRED |
| `GLOBAL.ADR0002-SEQ` | — | 5×5 | `collision_size`/`seq_table_size` for 9–16 stones are **2^(n−1) worst-case bounds, not measured** | UNTESTED | `0002:36-38`; `0005:127-130` | — | 5×5 forward-search feasibility | 0 | ? | RETIRED |
| `GLOBAL.ADR0007-AB` | — | all | Alpha-beta / proof-number search cannot populate an oracle — it returns the root score plus bounds and prunes whole subtrees unvisited | PROVEN | `0007:25-28` | — | the retrograde design | 0 | ? | RETIRED |
| `GLOBAL.ADR0007-BACKEDGE` | — | all | Captures create back-edges (k stones → k−3), so retrograde must be a **fixpoint iteration, not a single topological sweep** | PROVEN | `0007:30-33`; `0009:41-46` | — | `GLOBAL.FP3`, the whole out-of-core design | 0 | ? | RETIRED |
| `GLOBAL.ADR0009-SUCC` | — | all | Values propagate by successor sweeps, never predecessor generation — un-capture inversion is a large unvalidatable kernel and would not buy a one-sweep guarantee anyway | PROVEN (design argument) | `0009:28-46` | `d:GLOBAL.ADR0007-BACKEDGE` | `src/retro.zig` | 0 | ? | RETIRED |
| `GLOBAL.ADR0014-PURE` | — | all | `score.zig` consults **no oracle values**; every public function carries an epistemic tag; the report does not claim the fresh-start value and does not bound the real-game PSK score | PROVEN | `0014:16-25,65-71` | `d:GLOBAL.ADR0003-AREA`, `d:GLOBAL.S2` | scoring UI | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.ADR0016-INHERIT` | — | all | **ADR-0016 (D-2, 2026-07-28):** per-goban epistemic independence applies to **empirical** claims (never inherit) and not to **structural** ones — code or mathematics — which may inherit **with the inheritance argument written down**; status does not upgrade on inheritance; `mixed` and cross-ruleset are **unruled** and do not inherit. Supersedes the rule as stated in `AGENTS.md` and `CONCEPTS.md:65-71`; the `AGENTS.md` amendment is **outstanding** (another agent owned that file) | CLAIMED (adopted rule — a decision, not a fact) | `docs/decisions/0016-per-board-independence-empirical-vs-structural.md`; `critique-2026-07-28.md:373` | `e:QA-015` | §5 inheritance audit, §6-D2/D3/D4, `4x3.H1-CENSUS` (first application) | 0 | ? | Z-NONCLAIMS |
| `GLOBAL.ADR0015-BURDEN` | — | all | **ADR-0015 (D-5, 2026-07-28):** ADR-0010's premise that the `[L,H]` bracket "holds under ANY arrival history" is **refuted as stated** — for an empty-goban root the finisher's own search path *is* a real game line, so E2's falsifying histories lie inside the family ADR-0010 claims to cover. `GLOBAL.F2` stays orphaned; the burden is on ADR-0010 and is **undischarged**. A ruling about an *argument*, not a new measurement: it does not establish that the bracket fails at any goban other than 3×3. **Challenge attempted and FAILED (EXP-10, Fable 5, 2026-07-29 — ADR-0017):** the search-path family is **not** exempt — T13's 12 pointwise mismatches at 3×2 ride exactly the finisher's search-shaped histories (8/12 empty-rooted); ADR-0015 **stands, strengthened.** A three-seat blind review (`QA-018-REVIEW-A/B/C`: GLM-5.2, DeepSeek Pro, Kimi-k2.7) returned **unanimously** that ADR-0017's 'refutation failed' verdict is SOUND; all three convicted the two planted calibration defences (6 MTD self-verification, 7 `bracket_fail` gate) as WRONG. **Confirmed by ADR-0018 (the human's `QA-018-RULING`, 2026-07-29): ADR-0015 stands; F2 remains orphaned.** The finisher remedy is a new task (`F2-REMEDY`) — not a brackets-off regen, which inherits the same premise through CERTCORE-dependent seeds. | CLAIMED | `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`; `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md`; `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md`; `0010:16-18,70-93`; `src/retro.zig:464`; `critique-2026-07-28.md:376` | `n:GLOBAL.C3` (the ruling is justified by C3 being FALSE; if C3 were rehabilitated ADR-0010's premise would stand and this ADR would lose its reason to exist), `e:3x3.C3`, `e:QA-019` | `GLOBAL.F2` orphan status, `QA-018`, `GLOBAL.ADR0010-CUT`, artifact promotion, the brackets-off regen decision | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.F2-REMEDY` | — | all | The finisher-replacement is the **median build**: `converge` on `(board, side, ko_point, passes)` under basic ko + constant tie `T`, then `V = median(L, T, H)` (proof-v2 Thm 5.1); no forward search, no brackets, no seed inheritance — F2 is **dissolved, not rehabilitated** (the F2 relationship is *supersession*, recorded here, not a graph edge). **Design only** (`docs/research/f2-remedy-design-2026-07-29.md`, Fable 5, 2026-07-29); gated on EXP-2B (the QA-023 computational half) and EXP-4 (2×2/2×3 = 0 falsifier). | CLAIMED | `docs/research/f2-remedy-design-2026-07-29.md`; `docs/evidence/QA-023/proof-v2-2026-07-28.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md` | `d:QA-023`, `d:QA-023.M1` | the new-rule build (EXP-4/5/6), the certified-fraction measurement (EXP-7), the PSK divergence (EXP-8 under the new rule) | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.ADR0014-DEAD` | — | all | `dead_stone_estimate` and `territory_japanese` are conservative heuristics, deliberately under-claiming; not a life/death oracle | CLAIMED | `0014:37-38,42-48,68-71` | `d:GLOBAL.S2` | scoring UI honesty | 0 | ? | RETIRED |
| `4x4.D3` | D3 | 4×4 | Writes-off 4×4 tractability — **a measurement, not a truth claim**. Target wall ≤ 8 h, memory ≤ 32 GB (placeholder, unconfirmed with the user) | UNTESTED | `4x4/EPISTEMIC.md:175-183,328` | `e:4x3.M3` (pilot extrapolation; retired 2026-08-03 T330 — evidence retired, needs re-derivation) | `4x4.F2`, `4x4.F3`, `4x4.F4`, `GLOBAL.H4a`, `GLOBAL.H1-CENSUS` budget | 0 | ? | Z-TABLE-FAITHFUL |
| `GLOBAL.B15` | B15 | 2×2/3×2 | Track A 2×2/3×2 regen complete and **byte-identical**. **The byte-identity targets are the committed hashes in `artifacts/SHA256SUMS` (oracle-2x2.wzo, oracle-3x2.wzo) — the completed *action* stands on those files independent of `GLOBAL.F3`'s soundness (T128 triage: decouple the action from the premise; the `d:` edge records only that the regen *used* the writes-off path; disposition per the T128 triage, absorbed 2026-07-31). Original `PROGRESS.md:238-240,244-245` cite rotted when T127 rewrote that file** | CLAIMED | `artifacts/SHA256SUMS` | `d:GLOBAL.F3` | `2x2.C1`, `3x2.C1` (§6-D10) | 0 | ? | Z-TABLE-CONSISTENCY |
| `GLOBAL.T14.1` | T14.1 | 4×4 | 4×4 bracket-only artifact produced 2026-07-27 | CLAIMED | `PROGRESS.md:238-240` | — | `GLOBAL.REFRAME` packaging | 0 | ? | RETIRED |
| `GLOBAL.ONEWRITER` | — | n/a | Concurrent edits to `retro.zig`/`oracle.zig`/`rules.zig`/`solve.zig` silently corrupt; one writer per engine file | CLAIMED | `AGENTS.md:96-97,150-171` | — | all parallel dispatch | 0 | ? | RETIRED |
| `GLOBAL.RELEASEFAST` | — | n/a | Asserts are no-ops in ReleaseFast — correctness runs must use `-Doptimize=ReleaseSafe` | PROVEN | `AGENTS.md:110-111` | — | every measurement's validity | 0 | ? | RETIRED |
| `GLOBAL.BATTERY-GAPS` | — | all | **Phase 1 battery requirement-tree coverage gaps (T290, absorbed T293): six of twenty Z-tree nodes lack a battery invariant.** G1 `Z-R-STATE` (state-key correctness — no check that producer and consumer agree; this is the T178/T193/T265 defect family: three suffered defects, zero battery coverage); G2 `Z-STATE-REACH` (closure C-A1/C-A2 — no check that reachable set is correctly computed); G3 `Z-STATE-KEY` (consumer-side key agreement, same family as G1); G4 `Z-TABLE-ROUNDTRIP` (write-then-read fidelity); G5 `Z-CONVERGE-SEED` (seeding provenance — build documentation, not artifact property; accepted gap); G6 `Z-CONVERGE-MONO` (monotonicity — mathematical proof accepted). G1, G3 are the critical ones: Z-R-STATE and Z-STATE-KEY have **no battery coverage at all**, and the T178/T193/T265 defect family (three producer/consumer key disagreements) is the project's most expensive bug class. G1–G4 are specified and runnable after Phase 2 kernel; G5–G6 are accepted gaps. | CLAIMED | `docs/epic-01-markovian/sprints/verify-battery/pass1/spec.md` §2; `docs/evidence/ORACLE-V2/ko-key-mismatch-T265.md`; `docs/evidence/ORACLE-V2/incompleteness-T266.md` | `d:CODE.GTP-KOKEY` (the T265 instance), `d:CODE.ACCEPT-KOKEY` (the fourth instance), `e:AXIOMS.md` §3 (requirement tree) | verify-battery Phase 2, T291 design, G1/G3 acceptance | 0 | ? | Z-AUDIT |
| `GLOBAL.BATTERY-PASS1-ACCEPTANCE` | — | all | **Phase 1 verify-battery acceptance criteria A1–A6 re-based on Amendment 1 (T290, absorbed T293).** Known-bad fixtures are synthetic mutants (mutation testing — DeMillo/Lipton/Sayward 1978), not live artifacts; regression artifacts are golden masters whose pass condition is unchanged from a documented baseline (§7 of the spec). v1 artifact (`data/oracle-4x4-basicko-tie-area.wzo`) is a regression input with documented I7 failure as baseline, not a known-bad calibration fixture. A5 raised from one to two independent re-implementations (QA-023 chain lesson: five audit links, four passed the artefact through). Exit code discipline refined to four classes including measurement-only (exit 4). | CLAIMED | `docs/epic-01-markovian/sprints/verify-battery/pass1/spec.md` §4, §6, §7 | `d:GLOBAL.BATTERY-GAPS`, `d:GLOBAL.ADR0020-VERIFY-PASS` | Phase 1 battery acceptance, T291 design, T292 implementation | 0 | ? | Z-AUDIT |
| `CODE.KEY-AGREEMENT` | — | n/a | **Key-agreement invariant wired into `zig build test` (T267, absorbed T293).** Engine (`src/gtp.zig`) and builder (`src/oracle_v2_build.zig`) produce identical `(colex, side, ko, passes, terminal)` keys on all goban sizes (2×2, 3×2, 3×3, 4×4) for human-game sequences and self-play. Engine ko rule independently re-implemented using `rules.Rules.neighbors` (not alias of `solverKoGeneric` — per QA-023 standing rule). Seeded-defect control (`626ec55^` old ko rule) caught disagreements on 3×2 self-play, confirming sensitivity. 13 differential tests pass in `zig build test`. **Caveat:** self-play with first-legal-move policy may under-cover cycle-intensive ko positions; the ko-sensitive region is lightly exercised. The ko-key portion covers G1 (`Z-R-STATE`) partially — it verifies ko agreement but not full state-key parity for all four key components under adversarial move selection. | CLAIMED | `docs/evidence/GLOBAL.DIFFERENTIAL/T267-key-agreement/PROVENANCE.md`; `src/differential.zig` (tests 6–13); `build.zig` (differential wired into `test_step`) | `d:CODE.GTP-KOKEY`, `e:GLOBAL.BATTERY-GAPS` (partial coverage of G1) | key-agreement G1 acceptance, producer/consumer trust, `zig build test` | 0 | ? | Z-STATE-KEY |
| `CODE.STANDING-ABSORB` | — | n/a | **The absorption backlog is a standing trigger, not an Orchestrator habit (T294, absorbed 2026-08-03 by STANDING-ABSORB).** `managent standing` carries STANDING-ABSORB, which auto-registers a dispatchable kanban task when claimlint's C7 unabsorbed-findings count exceeds 5. The count is read from `bin/weizigo-claimlint`'s own summary (the same run the C3 trigger uses; never reimplemented — one implementation of the count, the kernel doctrine), and the per-file composition is surfaced from claimlint's own `UNABSORBED … in <file>` lines. Threshold rationale (src/managent/main.zig:4117): 0 is the permanently-red-gate failure (GRAND-AUDIT §1c); 1–4 is the in-flight noise band (a finished task's findings are legitimately unabsorbed until ratified); 5 is a session-sized job and fires with margin on the smallest fully decomposable genuine backlog observed (10, 2026-08-03: C7=21 = 10 genuine + 11 context dumps repeating their findings files) without firing on noise. Trigger is absolute (count > threshold), not change-based. Controls: null (empty findings → C7=0, no trigger, explicit at/below-threshold statement) and seeded (6 synthetic unabsorbed claims → C7=6, trigger fires, names count, registers dispatchable task) both PASS, wired into `zig build test` via tools/regression-managent-standing.sh — the standing mechanism previously had no controls at all. Re-verified live during absorption 2026-08-03: `managent standing` fired with C7=10 and the correct per-file composition | PROVEN | `docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md`; `src/managent/main.zig:4117,4151,4366`; `tools/regression-managent-standing.sh`; `docs/infra/dispatch/STANDING-ABSORB.md`; `findings/T294-standing.json` | `d:CODE.CLAIMLINT-C7-NEWROWS` (the count's correctness rests on claimlint's C7 parsing) | the absorption queue, C7 gate decision | 0 | ? | RETIRED |
| `CODE.STANDING-C3-DEAD` | — | n/a | **The pre-existing STANDING-REEVIDENCE trigger cannot fire (T294, absorbed 2026-08-03).** `cmdStanding` searches claimlint output for the marker "C3: " (src/managent/main.zig:4140,4176), but claimlint's summary prints "C3 PROVEN w/o committed evid. N" — no line containing "C3: " exists in its output (verified by grep over a full claimlint run, 2026-08-03; re-verified during absorption). `c3_debt` therefore parses as 0 every run and the change-based condition (`c3_debt > c3_prior and c3_prior > 0`) can never hold. The trigger is dead code as written. Not fixed by T294 — reported so the Orchestrator can decide (neighbouring triggers are the Orchestrator's call per the T294 brief's note) | PROVEN | `src/managent/main.zig:4140,4176`; `bin/weizigo-claimlint` summary line format (grep for "C3: " over full output returns nothing, 2026-08-03); `docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md` (observation recorded) | — | STANDING-REEVIDENCE effectiveness, C3 debt trigger decision | 0 | ? | RETIRED |
| `CODE.STANDING-STATE-FRAGILE` | — | n/a | **The standing triggers' persisted was/now priors survive only until the next kanban write (T294, absorbed 2026-08-03).** `parseStateJson` skips every `_`-prefixed key (src/managent/main.zig:581) and `writeState` re-serializes only task keys, so `persistStandingState`'s textual `_standing` insertion (main.zig:4475) is dropped by any subsequent add/claim/done. Live state 2026-08-03: tasks.json carries no `_standing` key despite the Orchestrator's fired-trigger report (re-verified during absorption: `grep -c "_standing"` → 0). Consequence: the change-based triggers (REEVIDENCE, CONSOLIDATE, CLEANUP, HOLISTIC-AUDIT) lose their prior baseline whenever the kanban is written between standing runs. STANDING-ABSORB is unaffected (absolute trigger, no prior). Not fixed by T294 — reported | PROVEN | `src/managent/main.zig:581` (metadata keys skipped in parseStateJson); `src/managent/main.zig:4475` (persistStandingState naive textual insertion); `docs/infra/managent/tasks.json` (no `_standing` key, 2026-08-03); `docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md` | — | the change-based standing triggers (REEVIDENCE, CONSOLIDATE, CLEANUP, HOLISTIC-AUDIT) | 0 | ? | RETIRED |
| `4x4.WZO2-A2-EXHAUSTIVE` | — | 4×4 | **A2 Bellman fixpoint identity holds on all 99,133,036 stored entries of oracle-4x4-v2.wzo2 (0c3366f0), measured exhaustively (T309, absorbed 2026-08-03).** L_violations=0, H_violations=0, missing_child=0. Runtime 50.6s, peak RSS 866 MB. ReleaseFast binary sha256 ff1a5787c793acf03efef36b6fe9ccf70154e018c56817d39a25357398698ac6. The sampled baseline was representative — the exhaustive run found no violations the samples missed. **Held at CLAIMED, not PROVEN, per DIRECTION Amendment 2 edge 5: an exhaustive acceptance run is a measurement, not mutation adequacy — promotion past CLAIMED requires the mutants covering the checked function to be killed, which this run does not provide** | CLAIMED (exhaustive measurement; PROVEN proposal held at CLAIMED per DIRECTION Amendment 2 edge 5) | `findings/T309-exhaustive-acceptance.json`; `untracked/oracle-v2/oracle-4x4-v2.wzo2` | `e:CODE.WZO2-BUILD-REPRO` (the artifact measured is the canonical reproducible one) | oracle-v2 G3, WZO2 acceptance A2 cell | 0 | 0 | Z-CONVERGE-FIX |
| `4x4.WZO2-A5-EXHAUSTIVE` | — | 4×4 | **A5 round-trip identity (decode(encode(x)) == x) holds on all 99,133,036 stored entries of oracle-4x4-v2.wzo2 (0c3366f0), measured exhaustively (T309, absorbed 2026-08-03).** mismatches=0. Runtime 0.18s, peak RSS 866 MB. The exhaustive run closes the stride-97 sampling gap (SPRINT-M4a-ACCEPT's A5 was 1,021,991 sampled at stride 97 — never verified coprime to the group-size distribution, T215 self-report). **Held at CLAIMED, not PROVEN, per DIRECTION Amendment 2 edge 5: an exhaustive acceptance run is a measurement, not mutation adequacy — promotion past CLAIMED requires the mutants covering the checked function to be killed, which this run does not provide** | CLAIMED (exhaustive measurement; PROVEN proposal held at CLAIMED per DIRECTION Amendment 2 edge 5) | `findings/T309-exhaustive-acceptance.json`; `untracked/oracle-v2/oracle-4x4-v2.wzo2` | `e:CODE.WZO2-BUILD-REPRO` (the artifact measured is the canonical reproducible one) | oracle-v2 G3, WZO2 acceptance A5 cell | 0 | 0 | Z-TABLE-ROUNDTRIP |
| `4x4.WZO2-A8-EXHAUSTIVE` | — | 4×4 | **A8 DTT consistency holds on all 99,133,036 stored entries of oracle-4x4-v2.wzo2 (0c3366f0), measured exhaustively (T309, absorbed 2026-08-03).** DTT consistency violations=0, terminal_dtt0_errs=0, non_constant=true, far=0. Runtime 55.9s, peak RSS 866 MB. Distribution unchanged from the sampled baseline — the samples were representative. **Held at CLAIMED, not PROVEN, per DIRECTION Amendment 2 edge 5: an exhaustive acceptance run is a measurement, not mutation adequacy — promotion past CLAIMED requires the mutants covering the checked function to be killed, which this run does not provide** | CLAIMED (exhaustive measurement; PROVEN proposal held at CLAIMED per DIRECTION Amendment 2 edge 5) | `findings/T309-exhaustive-acceptance.json`; `untracked/oracle-v2/oracle-4x4-v2.wzo2` | `e:CODE.WZO2-BUILD-REPRO` (the artifact measured is the canonical reproducible one) | oracle-v2 G3, WZO2 acceptance A8 cell | 0 | 0 | Z-TABLE-CONSISTENCY |
| `CODE.WZO2-BUILD-REPRO` | — | 4×4 | **The WZO2 4×4 builder reproduces its artifact byte-for-byte across runs (T310, absorbed 2026-08-03).** A 2026-08-03 rebuild (binary `weizigo-oracle-v2-build f25e615-dirty built 2026-08-03T02:24:49Z`, ReleaseFast) produced SHA-256 `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a` (518,123,097 bytes) at `untracked/v02/oracle-4x4-v2.wzo2` — byte-identical to the 2026-08-01 artifact from T212 (commit `144148c`) across six intervening commits touching the builder's import closure. 31 fixpoint sweeps, converged:true; every per-sweep L_changed/H_changed digit-for-digit identical; root (empty,B) L=+1 H=+16, (empty,W) L=−16 H=−1; 99,133,036 entries; 24,318,165 groups; DTT 10 sweeps, FAR=0; wall 3,789.4 s, peak RSS 3,887 MB, RUNNER_RC=0. Every WZO2 acceptance check A1–A9 reproduces its baselined cell exactly (fast battery gate PASS; slow sweep BASELINE COMPARISON: PASS). Corollaries: T226's genericNeighbors delegation is behaviour-preserving on this path; the artifact header carries no build stamp (T264's sha/date/dirty banner reaches the log/manifest but not the artifact bytes — `artifact2.Header` has no stamp fields). **Scope: reproducibility of the builder only — NOT value correctness (G3b), NOT the T273 kernel, NOT WZO1. At CLAIMED: promotion past CLAIMED needs mutation adequacy for the code involved (DIRECTION Amendment 2 edge 5), which this run does not provide** | CLAIMED | `docs/evidence/ORACLE-V2/rebuild-2026-08-03.md`; `docs/evidence/ORACLE-V2/rebuild-T310-2026-08-03.log` (SHA-256 ffa0e7ad59d39e3e1915b2472870d633141f5f620b5899047db36fe48a6436b9); `findings/T310-rebuild-reproducibility.json` | — | oracle-v2 G3, the WZO2 acceptance battery, `4x4.WZO2-A2-EXHAUSTIVE`/`A5`/`A8` artifact identity | 0 | ? | Z-TABLE-CONSISTENCY |
| `CODE.T312-PARALLEL-FIXPOINT` | — | 4×4 | The 4×4 fixpoint solver supports parallel Jacobi iteration with --threads N. Serial Gauss-Seidel at N=1 (byte-identical to pre-T312). Parallel Jacobi at N>1 — provably convergent (monotone operator on complete lattice), deterministic. Race controls wired into zig build test. T312, absorbed T337 S4, 2026-08-04 | CLAIMED | `findings/T312-parallel-fixpoint.json`; `src/t312_race_control.zig`; `src/exp6_solve.zig` | `d:CODE.WZO2-BUILD-REPRO` | — | 0 | 0% (4 tests, seeded defect caught) | Z-TABLE-CONSISTENCY |
| `CODE.WZO2-RELEASESAFE-INV` | — | 4×4 | ReleaseSafe rebuild produces byte-identical WZO2 artifact with zero safety-check panics. Serial path only. T313, absorbed T337 S4, 2026-08-04 | CLAIMED | `findings/T313-releasesafe-invariance.json`; `docs/evidence/ORACLE-V2/releasesafe-rebuild-2026-08-03.md` | `e:CODE.WZO2-BUILD-REPRO` | — | 0 | ? | Z-TABLE-CONSISTENCY |
| `CODE.PARALLEL-FIXPOINT-MEASURED` | — | 4×4 | T312 parallel fixpoint measured on Apple M5 Max. All artifacts byte-identical to T310 reference. Speedup 2.91× at N=16, flattening at N=12. RSS 3,887±1 MB. T314, absorbed T337 S4, 2026-08-04 | MEASUREMENT | `findings/T314-parallel-measurement.json`; `docs/research/parallel-fixpoint-measurement-2026-08-03.md` | `e:CODE.WZO2-BUILD-REPRO`, `e:CODE.T312-PARALLEL-FIXPOINT` | — | 0 | 0% | Z-TABLE-CONSISTENCY |
| `CODE.MANAGENT-MODEL-VALIDATION` | — | n/a | Canonical model label validation in managent — canonical_models[] single source of truth, canonicalizeModelTag, rejection of non-canonical labels at agent/claim/done. T317 item 2, absorbed T337 S4, 2026-08-04 | CLAIMED | `findings/T317-managent-attribution.json`; `src/managent/main.zig` | — | model-perf ledger integrity | 0 | 0 | RETIRED |
| `CODE.MANAGENT-LOST-UPDATE` | — | n/a | Lost-update safety in managent store — lock→re-read→writeStateLocked→unlock for add/claim/agent/dispatch/amend. T317 item 4, extended by T337 S0/S6, absorbed T337 S4, 2026-08-04 | CLAIMED | `findings/T317-managent-attribution.json`; `src/managent/main.zig` | — | kanban integrity | 0 | 0 | RETIRED |
| `CODE.MANAGENT-AMEND` | — | n/a | Append-only amendment path for done/failed tasks — managent amend preserves original verdict in amendments[] array. T317 item 6, first real use T326 (T337), absorbed T337 S4, 2026-08-04 | CLAIMED | `findings/T317-managent-attribution.json`; `src/managent/main.zig` | — | verdict correction path | 0 | 0 | RETIRED |
| `CODE.MANAGENT-ARCHIVE` | — | n/a | managent archive command with dry-run, eligibility checks, idempotency, cmdWhy dual-store search. T319, absorbed T337 S4, 2026-08-04 | CLAIMED | `findings/T319-kanban-archive.json`; `src/managent/main.zig` | — | kanban hygiene | 0 | 0 | RETIRED |
| `CODE.REGRESSION-WIRING` | — | n/a | Orphaned regression scripts wired into zig build test — managent-done-git, managent-memory-safety. Extended by T337 S5 (4 more scripts). T322 + T337 S5, absorbed T337 S4, 2026-08-04 | CLAIMED | `findings/T322-orphaned-controls.json`; `build.zig` | — | suite coverage | 0 | 0 | RETIRED |

### 2.11 Q&A register (`QA-nnn`) — imported 2026-07-28

The 28 Q&A claims minted by `critique-2026-07-28.md` §7 and
`roadmap-2026-07-28.md` §5, imported verbatim with edges. Before this import
they were a **second dependency graph with no edges**: `weizigo-claimlint` C4
found 14 of them cited across `docs/` and the dispatch briefs with no register
row, so a status change anywhere in §2.1–§2.10 could not reach them and a
falsification of one of them could not reach anything. `QA-023` in particular is
the load-bearing claim of the entire roadmap and the only claim in the project
with a claim-ID-named evidence directory.

**Statuses are mapped, not re-adjudicated.** The source tables use words this
register does not (`UNKNOWN`, `DISCREPANCY`, `PROPOSED`, `ORPHANED`). The
mapping — `UNKNOWN`/`DISCREPANCY` → `UNTESTED`, `PROPOSED` → `CLAIMED` with the
source word kept in the cell, `ORPHANED` → the source status plus the `d:` edge
that makes §4.1 compute it — is recorded in `claimlint-2026-07-28.md` §9. Flat
`FALSE` is kept as written (§1); re-labelling it `FALSE-AS-SCOPED` would be a
status change this file is not entitled to make.

**Eight rows are aliases** of claims that already have a row — `QA-002`,
`QA-003`, `QA-007`, `QA-010`, `QA-011`, `QA-013`, `QA-018`, `QA-025`. Each says
so and carries `d:<canonical>` rather than duplicating the canonical's evidence,
so a status change to the canonical propagates instead of leaving two rows to
drift apart.

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `QA-001` | QA-001 | 2×2–4×4 | "V0 satisfies the one-ply Bellman identity by construction, everywhere" (raised by GLM) — **refuted**: 11,402/11,402 violations at 4×4, all KO_SENSITIVE, max gap 32 = 2n | FALSE | `critique-2026-07-28.md:359`; `ko-sensitive-chainability.md:70-71` | `e:GLOBAL.CHAIN-KO` | `GLOBAL.CHAIN-KO` (the correct statement) | 0 | ? | Z-CONVERGE-FIX |
| `QA-002` | QA-002 | 4×4 | **Alias of `4x4.A-3`.** "The player is fresh-start-perfect (unsound only for the real game)" — refuted at ply 14: stored −3, played child −16 | FALSE | `critique-2026-07-28.md:360`; `regressions/4x4-black-win-after-ko.txt:74` | `d:4x4.A-3` | `4x4.GTP-DEFECT` | 0 | ? | RETIRED |
| `QA-003` | QA-003 | 4×4 | **Alias of `4x4.A-2`.** "The 4×4 collapse is 'the C2 falsification in action'" — category error: C2 is scoped to L==H, every blundering node is L<H | FALSE | `critique-2026-07-28.md:361`; `corrections:66-96` | `d:4x4.A-2` | corrected attribution = `GLOBAL.C4` + unchainability | 0 | ? | Z-NONCLAIMS |
| `QA-004` | QA-004 | 4×4 | "The empty 4×4 goban is really L==H / the KO_SENSITIVE flag is over-broad there" — refuted: bracket [−6,+16] | FALSE | `critique-2026-07-28.md:362`; `4x4/EPISTEMIC.md:249` | `e:4x4.M5`, `e:4x4.BRACKET` | `QA-005` | 0 | ? | Z-TABLE |
| `QA-005` | QA-005 | 4×4 | "A KO_SENSITIVE flag implies the identity fails at that node" — refuted: only 4.08% of flagged 4×4 slots violate, the empty goban does not, plies 1–7 are clean. **Flagged = unguaranteed, not wrong** | FALSE | `critique-2026-07-28.md:363`; `ko-sensitive-chainability.md:54` | `e:4x4.M4` | the reading of every KO_SENSITIVE count in this file | 0 | ? | RETIRED |
| `QA-006` | QA-006 | 4×4 | "The chainability violations are purely definitional" (Opus, earlier) — refuted: writes-off 1.67% vs writes-on 4.08% at two strides. There is a floor **and** an excess | FALSE | `critique-2026-07-28.md:364`; `ko-sensitive-chainability.md:163-197` | `e:4x4.M6` | `4x4.M6-FLOOR`, `4x4.M6-EXCESS` | 0 | ? | RETIRED |
| `QA-007` | QA-007 | 4×4 | **Alias of `4x4.M6-EXCESS`.** "The excess above the definitional floor is the ADR-0013 `ko_ref ≥ d` bug" — upgrade path is `RETRO_CONSIST` on both artifacts, not a substitute for the auditor | CLAIMED | `critique-2026-07-28.md:365`; `4x4/EPISTEMIC.md:227-231` | `d:4x4.M6-EXCESS` | `4x4.F3` acceptance framing | 0 | ? | RETIRED |
| `QA-008` | QA-008 | 4×4 | "`untracked/oracle-4x4-writesoff-checkpoint.wzo` is a completed Track A regen" — asked of GLM 2026-07-28, unanswered. Blocks promoting `QA-007` and cheapening F2/F3 | UNTESTED | `critique-2026-07-28.md:366`; `4x4/EPISTEMIC.md:236-242` | `e:4x4.WRITESOFF` | `QA-007`, `4x4.F3` | 0 | ? | RETIRED |
| `QA-009` | QA-009 | 3×3 | "E2's 3×3 leak count is a **discrepancy**: 50/8000 (`PROGRESS.md`) vs 25/4000 (`leak-crisis.md`)" — **refuted 2026-07-28 (D-1, Opus): it is not a discrepancy.** They are two real runs: 25/4,000 is the original E2, 50/8,000 is B06's re-run; identical rate (0.625%) and identical maximum (12 pts) because the second **replicated** the first. Both are now separate register rows and neither was collapsed | FALSE | `critique-2026-07-28.md:367`; ruling D-1, 2026-07-28, recorded in §6-D1 of this file | `e:3x3.E2-RUN1`, `e:3x3.E2-RUN2` | §6-D1 (resolved), `3x3.C3`'s run size | 0 | ? | Z-NONCLAIMS |
| `QA-010` | QA-010 | all | **Alias of the split `GLOBAL.ONEMISMATCH` pair:** `GLOBAL.ONEMISMATCH-DIAG` (CLAIMED) and `GLOBAL.ONEMISMATCH-CURE` (FALSE-AS-SCOPED at 3×2). "PSK's non-Markovian / Markovian mismatch explains C2, C3, C4 and the collapse" — an interpretation, not a theorem. Formerly a single alias row; split 2026-07-29 per `CLAIMS-SPLIT-CONJUNCTS`. | CLAIMED | `critique-2026-07-28.md:368`; `PROGRESS.md:169-183` | `d:GLOBAL.ONEMISMATCH-DIAG` | framing only | 0 | ? | RETIRED |
| `QA-011` | QA-011 | all | **Alias of the split `GLOBAL.H1` pair:** `GLOBAL.H1-MARKOV` (UNTESTED) and `GLOBAL.H1-COMPUTABLE` (FALSE-AS-SCOPED at 3×2). "Under simple ko the state `(position, side, ko_point)` is Markovian, so the table is chainable by construction" — the original conjoined text restated both halves. Formerly a single alias row; split 2026-07-29 per `CLAIMS-SPLIT-CONJUNCTS`. | CLAIMED | `critique-2026-07-28.md:369`; `open-hypotheses:30-118` | `d:GLOBAL.H1-MARKOV` | `QA-023` (the rule-complete restatement) | 0 | ? | Z-R-TIE |
| `QA-012` | QA-012 | all | Values converge as the ko-history dial `j`/`k` increases, and the `j`→`j+1` delta **measures** residual suboptimality. Requires ≥2 affordable rungs. **EXP-8 (2026-07-29, Kimi-k2.7) built the divergence harness + perturbation calibration (`docs/research/psk-divergence-2026-07-29.md`), but the new-rule-vs-PSK value divergence is BLOCKED on the new-rule tables (EXP-4/5/6, behind EXP-2B); the numbers it produced (2×2 random: 28/56 value divergences, 50% CI [0.37,0.63]) compare the existing PSK table against history-exact PSK — the C2 history-dependence gap in reachable play, NOT the rule-divergence gap.** | UNTESTED | `critique-2026-07-28.md:370`; `roadmap-2026-07-28.md:302-307`; `docs/research/psk-divergence-2026-07-29.md`; `docs/evidence/QA-012/` | `d:QA-023`, `d:QA-026` | the measured-gap deliverable | 0 | ? | Z-NONCLAIMS |
| `QA-013` | QA-013 | all | **Alias of `GLOBAL.LONGCYCLE`.** "Long cycles under simple ko can be resolved as a loopy-game fixpoint with loops pinned to the tie value" — highest design risk in the roadmap; must not reintroduce score-on-cycle. **FALSIFIED at 3x2 2026-07-29: the tie-pinned loopy-game fixpoint over-pins TIE where the true value is the static pass-out score. The register's own 'highest design risk' annotation was correct.** **⚠ 2026-07-29 (night) — SCOPE SPLIT. `fixpoint_kernel`'s White-branch defect is VERIFIED by two independent seats (`Kimi-k3/PINRULE-SUFFICIENCY` found it; `Kimi-k2.7/QA023-KERNEL-AUDIT` reproduced all three evidence lines from scratch in Python, no Zig imported). Corrected kernel validated three ways: agrees with `smoke_fixpoint_2x2`, Bellman residuals 0/0, colour-inversion violations 0. Corrected 3x2 census `2232/322/34/34` replaces the buggy `948/1532/142/0`. **T138 (2026-07-31, `docs/evidence/QA-023/census-reconciliation.md`) reconciled the 2232/322/34/34 corrected kernel census (42-seed) against EXP-4's 2220/298/34/34 (retrograde engine, bug-free): the +36 delta = 36 empty-goban-with-ko-point phantom seeds (12→L==H, 24→pin_T), excluded by the true-game-root (4-seed) convention. cycle-reachable spread: 1,724→1,704→1,678, with 1,678 authoritative.** **On the CORRECTED kernel the verdict differs by semantics:** for the **history-conditioned** rule (first-revisit truncation, ADR-0019) this is **FALSE at 3x2** — C1 witness `(178,0,6,0)`, goban `[B,W,B,_,W,_]`, Black to move: two valid arrivals give truncation values **-3** and **-6** while the corrected fixpoint gives `L=H=-6`. For **fresh-start (shortest-arrival)** semantics the corrected tables remain consistent (`396/396` agreements in PINRULE-SUFFICIENCY; spot-checked independently) — a different object, and **UNTESTED** rather than true. Remaining gap, named by the auditor itself: the ~22-node witness tree was **not dumped and hand-verified** — task `QA023-C1-WITNESS`. Evidence: `docs/audits/2026-07-29-qa023-kernel-audit.md`, `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`.** | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2026-07-29-2b-6-full-review.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `critique-2026-07-28.md:371`; `open-hypotheses:92-103` | `d:GLOBAL.LONGCYCLE` | `QA-023`, `QA-026` | 0 | ? | Z-R-TIE |
| `QA-014` | QA-014 | 4×4 | A per-node Bellman-identity check (~16 lookups) lets the player refuse **exactly** when its rule is undefined | UNTESTED | `critique-2026-07-28.md:372`; `ko-sensitive-chainability.md:24-33` | `d:GLOBAL.CHAIN-LH`, `e:4x4.GTP-DEFECT` | `GLOBAL.H5` player fork, the certification deliverable | 0 | ? | RETIRED |
| `QA-015` | QA-015 | n/a | Per-goban independence should distinguish *empirical* claims (never inherit) from *structural / code* claims (inherit, with the argument written down) | CLAIMED (**DECIDED 2026-07-28** — D-2, Opus + GLM; the rule now lives in ADR-0016, and `mixed` was **not** ruled on) | `critique-2026-07-28.md:373`; `docs/decisions/0016-per-board-independence-empirical-vs-structural.md` | — | `GLOBAL.ADR0016-INHERIT`, §5 inheritance audit, the pending `AGENTS.md` amendment | 0 | ? | Z-NONCLAIMS |
| `QA-016` | QA-016 | 4×4 | "`data/oracle-4x4-parallel.checkpoint.wzo` can state the 4×4 answer" — refuted: `vb[empty] = −128` (UNDEF) by byte inspection, the **root** is unfilled. "99.8% complete" measures the wrong thing when the missing slot is the root | FALSE | `critique-2026-07-28.md:374`; `arena-4x4-undef.md:20-26` | `e:4x4.PARALLEL`, `e:CODE.UNDEF` | roadmap §4 P4 (fitness, not percentage) | 0 | ? | RETIRED |
| `QA-017` | QA-017 | 3×3/4×3/4×4 | The engine steers **into** the unchainable region: `mixed` policy — engine-to-move nodes 21.24% flagged, nodes it *creates* 47.33%; 4×3 31.49/49.13; 3×3 38.76/59.00 | CLAIMED | `critique-2026-07-28.md:375`; `reachable-kosensitivity-2026-07-28.md` | `e:GLOBAL.CHAIN-KO`, `e:4x4.M4` | `4x4.GREEDY-BIAS`, `GLOBAL.H2` | 0 | ? | RETIRED |
| `QA-018` | QA-018 | all | **Alias of `GLOBAL.F2`.** "The bracket-guided finisher (F2) is sound" — recorded ORPHANED (O1) at source: it derives from "brackets hold under ANY arrival history" (`0010:16-18`, `src/retro.zig:464`), which is C3. **Adjudicated 2026-07-28 (D-5, Opus → ADR-0015): the orphan is real — the fresh-start-root defence fails, because the finisher's own search path from an empty-goban root is a real game line. The burden is on ADR-0010 and is undischarged; the row stays orphaned. EXP-10 (2026-07-29, Fable 5) attempted to refute ADR-0015 and FAILED (ADR-0017): the orphan **stands**. A three-seat blind review (`QA-018-REVIEW-A/B/C`) returned **unanimously** that ADR-0017's verdict is SOUND; **ADR-0018 (the human's `QA-018-RULING`, 2026-07-29) confirms the orphan.** F2 stays CLAIMED-and-orphaned; the finisher remedy is a new task (`F2-REMEDY`), not a brackets-off regen** | CLAIMED | `critique-2026-07-28.md:376`; `0010:16-18`; `src/retro.zig:464`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`; `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md`; `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md` | `d:GLOBAL.F2`, `e:GLOBAL.ADR0015-BURDEN` | every shipped ko-sensitive value | 0 | ? | Z-TABLE-FAITHFUL |
| `QA-019` | QA-019 | all | "ADR-0013 Track A (`memo_writes=false`) escapes `QA-018`" — refuted: `bracketed` and `memo_writes` are independent and `saveArtifact` hardcodes `bracketed=true`; the 1.67% writes-off floor is **also** bracket-derived | FALSE | `critique-2026-07-28.md:377`; `src/retro.zig:2407` | `e:GLOBAL.F3`, `e:4x4.M6-FLOOR` | Track A scope, `4x4.F3`, artifact promotion | 0 | ? | Z-TABLE-FAITHFUL |
| `QA-020` | QA-020 | 3×3/4×3/4×4 | "The 4×4 engine can certify some of its own moves in self-play" — refuted: **0%**. 14 plies, 7,000/7,000 nodes flagged, one distinct game line, 144 tie-break variants find no certifiable node. Same at 4×3. **Re-tested at 4×4 under basic-ko + TIE=0 (DSPro/T129, 2026-07-31): 10.71% by direct V-domain Bellman check — still far from self-certifying. PSK gave 0% (flag-based); the new rule gives 10.71% (direct identity); non-chainable both ways, for different reasons** | FALSE | `critique-2026-07-28.md:378`; `reachable-kosensitivity-2026-07-28.md`; `docs/evidence/QA-027/4x4/PROVENANCE.md` | `e:4x4.M5`, `e:GLOBAL.CHAIN-LH` | `GLOBAL.H5a` ("sound but weak"), the certification deliverable | 0 | ? | RETIRED |
| `QA-021` | QA-021 | 4×4 | FP1 acceptance check 3 passes **exhaustively** at 4×4 on the shipped `vb`/`vw` columns: 48,599,962 slots, 422,990 violations, **all** KO_SENSITIVE, **zero** outside, 87 s. Upgrades `4x4.FP1-C3`'s 1:37 sample. Does **not** cover `lo`/`hi` — WZO1 has no bracket columns | PROVEN | `critique-2026-07-28.md:379`; `ko-sensitive-chainability.md:109,116` | `e:4x4.M4` (retired 2026-08-03 T330 — vestigial edge; QA-021 is the exhaustive PROVEN upgrade of 4x4.M4's 1:37 sample, not dependent on it) | `4x4.FP1-C3`, `GLOBAL.H4b` (discharged), `GLOBAL.H4` (gap (b) closed, gap (a) open) | 0 | ? | Z-CONVERGE-FIX |
| `QA-022` | QA-022 | n/a | "Load-bearing evidence for T13, T02/B1, T07 and B05 is retrievable" — refuted: all four were cited under git-ignored `untracked/`, all deleted, none ever in git. T13's numbers survive; its probe source does not | FALSE | `docs/evidence/README.md`; `critique-2026-07-28.md:380`; §7 of this file | `e:3x2.T13` | roadmap §4 P1, §7, `weizigo-claimlint` C2/C3 | 0 | ? | Z-AUDIT |
| `QA-023` | QA-023 | all | Under basic ko + a **fixed-value** long-cycle verdict, `(board, side_to_move, ko_point, passes)` is a sufficient **Markovian** state for exact solving — the score-on-cycle path-dependence does not apply, because a constant verdict is not a function of *which* goban repeated. **Load-bearing for the whole roadmap.** Its central obligation is to distinguish itself from `GLOBAL.R2` (score-on-cycle ≡ PSK) and `GLOBAL.RPLY-TRAP` (the cycle terminal drags history back into the key); **no `depends-on` edge is written deliberately** — writing one would prejudge which of those two it stands or falls with, and EXP-2 Part A is what decides | CLAIMED | `roadmap-2026-07-28.md:302`; `docs/evidence/QA-023/proof.md` (Part A; the computational half is 2×2-only, which `EXP-2-AUDIT-PREREG.md` rejects outright as INCOMPLETE). EXP-2A done 2026-07-28 (Fable 5; REPAIRABLE-GAPS→repaired); EXP-2B (the 3×2 computational half) COMPLETE 2026-07-29 via 2B-0…2B-6. **DO NOT MARK THIS ROW FALSE. The computational half SPLITS: C1 (this row's actual assertion — state-sufficiency) is UNTESTED-FOR-WANT-OF-CONTRAST, because the history generator misses the shortest arrival in 93% of states and its histories share ~62% of prefixes (`2B-3-AUDIT`); C2 (that the common value equals `median(L,TIE,H)`) is FALSIFIED — but C2 is `QA-026`'s content, NOT this row's. C2's failure is not evidence against state-sufficiency: on every eligible state all within-budget histories agree, including on the six C2 counterexamples. The reference-semantics §1 restatement conjoins C1 and C2, so §1-as-a-whole is false; that is a fact about the restatement. Adjudicated by 2B-6 (independent) confirming the Orchestrator: `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`.** **⚠ 2026-07-29 (night) — SCOPE SPLIT. `fixpoint_kernel`'s White-branch defect is VERIFIED by two independent seats (`Kimi-k3/PINRULE-SUFFICIENCY` found it; `Kimi-k2.7/QA023-KERNEL-AUDIT` reproduced all three evidence lines from scratch in Python, no Zig imported). Corrected kernel validated three ways: agrees with `smoke_fixpoint_2x2`, Bellman residuals 0/0, colour-inversion violations 0. Corrected 3x2 census `2232/322/34/34` replaces the buggy `948/1532/142/0`. **T138 (2026-07-31, `docs/evidence/QA-023/census-reconciliation.md`) confirmed the +36-state delta vs EXP-4's `2220/298/34/34` is exactly the 36 empty-goban-with-ko-point phantom seeds (12 into L==H, 24 into pin_T); the cycle-reachable spread 1,724/1,704/1,678 reduces to the same phantom convention, with 1,678 the true-game-root value.** **On the CORRECTED kernel the verdict differs by semantics:** for the **history-conditioned** rule (first-revisit truncation, ADR-0019) this is **FALSE at 3x2** — C1 witness `(178,0,6,0)`, goban `[B,W,B,_,W,_]`, Black to move: two valid arrivals give truncation values **-3** and **-6** while the corrected fixpoint gives `L=H=-6`. For **fresh-start (shortest-arrival)** semantics the corrected tables remain consistent (`396/396` agreements in PINRULE-SUFFICIENCY; spot-checked independently) — a different object, and **UNTESTED** rather than true. Remaining gap, named by the auditor itself: the ~22-node witness tree was **not dumped and hand-verified** — task `QA023-C1-WITNESS`. Evidence: `docs/audits/2026-07-29-qa023-kernel-audit.md`, `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`.** Note also that the 2B-4 probe numbers (390/1080) were artefacts of a σ-in-arrival defect, 1,133/1,133 collisions (`docs/evidence/QA-023/probe-defect-2026-07-29/`) | — (deliberate — see the claim) | `QA-012`, `QA-026`, `QA-027`, EXP-4…EXP-8, the whole roadmap | 0 | ? | Z-R-TIE |
| `QA-024` | QA-024 | 3×3/4×3/4×4 | PSK binds beyond basic ko at a negligible rate in real play, for repeats that are **not** ko cycles. **Legality half measured by EXP-1 (0 binding). Value half: EXP-8 (2026-07-29) built the harness but the new-rule-vs-PSK value divergence is BLOCKED on new-rule tables (EXP-4/5/6); the PSK-vs-history-exact-PSK numbers EXP-8 produced quantify the C2 history-dependence gap, not this claim.** | CLAIMED | `roadmap-2026-07-28.md:303`; `psk-binding-rate-2026-07-28.md:366-380` (EXP-1: consistent at exactly zero, with a recommended re-scoping); `docs/research/psk-divergence-2026-07-29.md` (EXP-8: harness built, value half blocked) | — | the measured-gap deliverable | 0 | ? | RETIRED |
| `QA-025` | QA-025 | all | **Alias of `GLOBAL.MIGOS-RULE`.** MIGOS II is a *program*, not a ruleset; its ruleset is Chinese area scoring + basic ko + long-cycle ties | PROVEN | `roadmap-2026-07-28.md:304`; `retrograde-3x3.md:222-241` | `d:GLOBAL.MIGOS-RULE` | every anchor comparison, `QA-023` | 0 | ? | Z-TABLE-FAITHFUL |
| `QA-026` | QA-026 | all | The existing L/H `converge` machinery is directly reusable under a fixed-value cycle rule, with loops pinned by **`V = median(L, T, H)`** — not v1's false `L<H ⇒ V=T` (the proof-v2 §5.3 gadget falsifies it; corrected in the F2-REMEDY design, 2026-07-29). **FALSIFIED at 3x2 2026-07-29 (2B-PROBE-FIX, independently confirmed by 2B-6): six states — all White-to-move, passes=1, no ko — where `median(L,TIE,H)` pins TIE=0 while the history-conditioned value is the pass-out `area_score` (+1, +3 or -6). proof-v2 Thm 5.1 is therefore FALSE as stated. Per-goban scope: 3x2.** **⚠ 2026-07-29 (night) — SCOPE SPLIT. `fixpoint_kernel`'s White-branch defect is VERIFIED by two independent seats (`Kimi-k3/PINRULE-SUFFICIENCY` found it; `Kimi-k2.7/QA023-KERNEL-AUDIT` reproduced all three evidence lines from scratch in Python, no Zig imported). Corrected kernel validated three ways: agrees with `smoke_fixpoint_2x2`, Bellman residuals 0/0, colour-inversion violations 0. Corrected 3x2 census `2232/322/34/34` replaces the buggy `948/1532/142/0`. **T138 (2026-07-31, `docs/evidence/QA-023/census-reconciliation.md`) reconciled the 2232/322/34/34 corrected kernel census (42-seed) against EXP-4's 2220/298/34/34 (retrograde engine, bug-free): the +36 delta = 36 empty-goban-with-ko-point phantom seeds (12→L==H, 24→pin_T), excluded by the true-game-root (4-seed) convention. cycle-reachable spread: 1,724→1,704→1,678, with 1,678 authoritative.** **On the CORRECTED kernel the verdict differs by semantics:** for the **history-conditioned** rule (first-revisit truncation, ADR-0019) this is **FALSE at 3x2** — C1 witness `(178,0,6,0)`, goban `[B,W,B,_,W,_]`, Black to move: two valid arrivals give truncation values **-3** and **-6** while the corrected fixpoint gives `L=H=-6`. For **fresh-start (shortest-arrival)** semantics the corrected tables remain consistent (`396/396` agreements in PINRULE-SUFFICIENCY; spot-checked independently) — a different object, and **UNTESTED** rather than true. Remaining gap, named by the auditor itself: the ~22-node witness tree was **not dumped and hand-verified** — task `QA023-C1-WITNESS`. Evidence: `docs/audits/2026-07-29-qa023-kernel-audit.md`, `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`.** | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2026-07-29-2b-6-full-review.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `roadmap-2026-07-28.md:305`; `docs/research/f2-remedy-design-2026-07-29.md`; `docs/evidence/QA-023/proof-v2-2026-07-28.md` | `d:QA-023`, `d:GLOBAL.LONGCYCLE`, `e:docs/evidence/QA-023/proof-v2-2026-07-28.md` | EXP-4, any simple-ko build, the F2-REMEDY median build | 0 | ? | Z-CONVERGE-FIX |
| `QA-027` | QA-027 | all | Under a Markovian rule the certified fraction is **100% by construction** — and it is a falsifier, not a formality. **FALSIFIED at 4×4 2026-07-31 (DSPro/T129, EXP-7 re-run on the T113 artifact): certified fraction = 10.71% (3,000/28,000 fresh-start nodes; 25,000 V-domain Bellman violations; 2,000 games, seed 20260728; oracle-rt identical). Mechanism: the L/H fixpoint converged, but the pinned `V = median(L, TIE, H)` does not distribute over `best_child` at bracket-valued states — the empty-goban root `[L=+1, H=+16]` violates directly (stored V=+1 vs best_child=+16). At 3×3 the root is single-valued (L=H=+9) and the measured fraction is 100.00% — the falsification bites exactly where brackets appear. This falsifies the *V-derivation*, NOT `QA-023` state-sufficiency: the Bellman identity holds for L and H separately by fixpoint construction; whether a different derivation (V=H maximizing / V=L minimizing) yields a chainable table is open (T129 §5). The flag column is non-degenerate, contrary to the brief's all-zero expectation: 981,071 slots per side have L<H (flag-read fraction 8.82%). Calibration: known-good 3×3 reproduces 100.00% exactly; known-bad perturbation detected (100% → 96.15%); PSK-table-under-new-rule known-bad INCONCLUSIVE (returned 100%, does not invalidate the instrument).** | FALSE-AS-SCOPED (at 4×4; 3×3 measured 100.00%) | `roadmap-2026-07-28.md:306`; `docs/research/newrule-certified-fraction-4x4-2026-07-31.md`; `docs/evidence/QA-027/4x4/PROVENANCE.md` | `d:QA-023` | EXP-7, the certification deliverable, `GLOBAL.F2-REMEDY` (the median build's V is the derivation shown non-chainable) | 0 | ? | Z-CONVERGE-FIX |
| `QA-028` | QA-028 | all | Opus's "Reading A" history-window ladder (`critique-2026-07-28.md` §5) is tractable — **withdrawn**: `RETRO_PLY` already falsified it, and the cycle terminal drags the full history back into the memo key | FALSE | `roadmap-2026-07-28.md:307`; `ruleset-options.md:42-71` | `e:GLOBAL.RPLY`, `e:GLOBAL.RPLY-TRAP` | representation fork | 0 | ? | RETIRED |

---

## 3. Edge summary

Counted from the `depends-on` column of §2 on 2026-07-28: **231 edges**, of
which **117 are `derives-from`** and **114 are `evidenced-by`**. The near
50/50 split is itself the finding — half this graph propagates falsification
and half propagates only doubt, and the project had no way to tell them apart.

**Recounted 2026-07-28 by `weizigo-claimlint`, after the `n:` audit, the §2.11
import and the C5 shadow sweep: 267 edges — 119 `d:`, 134 `e:`, 14 `n:`.**
**Recounted again the same day after the eight promotion rows were added:
290 edges — 122 `d:`, 152 `e:`, 16 `n:`** (the two new `n:` edges are
`GLOBAL.H5a-CHILD n:4x4.A-3` and `GLOBAL.ADR0015-BURDEN n:GLOBAL.C3`, both
healthy: each parent is FALSE, which is the state that justifies the child).
The tool prints this line on every run, so it is maintained rather than
remembered. Two things moved in the first recount:
the `n:` audit re-labelled **14 `d:` edges on 9 rows** as derives-from-negation
(they recorded "justified *because* the parent is false" as "derives from the
parent"), and §2.11 added 35 edges. **The in-degree ranking below is unchanged
in order** — the QA rows are leaves or aliases, and the `n:` re-labelling moves
edges between kinds without adding or removing any. What it *did* change is
§4.1: the orphan count fell from **23 to 9**, because 14 of the 23 were claims
standing on a refutation, not on a refuted premise — then rose to **10** when
the C5 sweep found `3x3.C1`'s real dependency hiding behind a measurement.

The three-way split is now the finding: **122 edges propagate falsification
forwards, 152 propagate only doubt, and 16 propagate it backwards.** A project
driven by falsifications needs the third kind; without it, every position
adopted *because* something fell reads as an orphan of the thing it replaced.

**Formal in-degree** below counts only edges written in the `depends-on`
column of a §2 row. It undercounts real dependence, because many dependents
named in the `dependents` column are downstream consequences that do not have
a row of their own (an artifact, a deliverable, a packaging decision). Both
numbers are given where they differ.

| claim | status | formal in-degree | why it matters |
|---|---|---|---|
| `GLOBAL.C3` | FALSE-AS-SCOPED | **9** (all `derives-from`) | every bracket cut, the whole finisher, every shipped ko-sensitive value |
| `4x4.M4` | MEASUREMENT | **9** (all `evidenced-by`) | the single most-cited datum in the project; one 1:37 sample carries `4x4.FP1-C3`, `GLOBAL.CHAIN-LH`, `GLOBAL.CHAIN-KO`, `4x4.M6` |
| `GLOBAL.F1` | FALSE-AS-SCOPED | **7** (6 `d:` + 1 `e:`) | every committed ko-sensitive column |
| `GLOBAL.INVSYM` | PROVEN | **7** (all `evidenced-by`) | every symmetry battery, orbit propagation, the E2 policy fix |
| `GLOBAL.S2` | PROVEN | **6** | terminal detection, eye-prune, H5(b) |
| `GLOBAL.C2` · `GLOBAL.C4` · `GLOBAL.FP1` · `GLOBAL.S4` · `GLOBAL.AUDITOR` | mixed | **5** each | — |

**Two of the top five, and three of the top eight, are FALSE-AS-SCOPED.** That
is the shape of the debt. The other structural risk is `4x4.M4`: nine claims
rest on a single 1:37 colex sample of one checkpoint file, which is exactly why
`GLOBAL.H4b` (one command, a few minutes) is cheap and worth running.

---

## 4. Consequence analysis

### 4.1 Orphaned claims

*Still marked PROVEN or CLAIMED, but with a `derives-from` ancestor that is
FALSE-AS-SCOPED.* Broken chains spelled out; `⟵d` reads "derives from".

**O1 — `GLOBAL.F2` (bracket-guided finisher sound) · CLAIMED**

    GLOBAL.F2 (CLAIMED, CONCEPTS.md:110-112, 0010:70-81)
      ⟵d GLOBAL.ADR0010-CUT ("bracket cutoffs are valid under any ban set", 0010:29-30)
        ⟵d GLOBAL.C3 (bracket bounds the score under any arrival history)
          ⟵ FALSE-AS-SCOPED at 3×3 (E2, leak-crisis.md:74)

This is the deepest orphan and the one the project has not stated. The
project's *own* documents supply the edge: `open-hypotheses:286-291` says
"cutting on `[L,H]` under a real history **is** claim C3, and C3 is
FALSE-AS-SCOPED at 3×3", and `ko-sensitive-chainability.md:276-281` repeats it —
but both apply it only to a hypothetical *play-time* search (`H5(c)`), never to
the finisher that actually generated every shipped ko-sensitive value.

**Nuance to preserve, not resolve.** E2 falsified C3 for *real-game* arrival
histories. The finisher's cuts apply under the ban set accumulated from a
fresh-start root down the search path — a nonempty arrival history, but a
different family of them. Whether "C3 for search-path histories" is the same
claim as "C3 for real-game histories" is exactly the question this register
cannot settle. ADR-0010 itself asserts they are the same ("a score bracket that
holds under ANY arrival history … the same structural claim as ADR-0009
certification", `0010:16-18`). If ADR-0010 is right, `GLOBAL.F2` is orphaned.

**Everything below inherits O1.**

**O2 — `4x3.C1` (fresh-start scores correct at 4×3) · CLAIMED**

    4x3.C1 (CLAIMED, 4x3/EPISTEMIC.md:32)
      ⟵d 4x3.F2 ⟵d GLOBAL.F2 ⟵d GLOBAL.C3   [FALSE at 3×3]
      ⟵d GLOBAL.F1 ("the same finisher path that was proven buggy at 3×2")
                                              [FALSE-AS-SCOPED]

The 4×3 file states the second edge itself and still records the status as
CLAIMED rather than withdrawing it. Note also that `4x3.C1`'s supporting
evidence is `4x3.ANCHOR` (+4 in-bracket) — and `GLOBAL.P1` ("an anchor match
implies real-game correctness") is FALSE-AS-SCOPED, so the anchor is
`evidenced-by`, not `derives-from`, and survives as weak support only.

**O3 — `3x3.C1` (fresh-start scores correct at 3×3) · CLAIMED**

    3x3.C1 (CLAIMED, PROGRESS.md:210)
      ⟵d 3x3.F2 ⟵d GLOBAL.F2 ⟵d GLOBAL.C3   [FALSE at 3×3 — same goban]
      ⟵d GLOBAL.F1                            [FALSE-AS-SCOPED]

Sharpest instance: the 3×3 table is finisher-produced with bracket cuts, and
3×3 is the very goban where the bracket was shown not to bound. `PROGRESS.md:210`
still lists 3×3 C1 as a `TODO` to promote, not as debt.

**O4 — `4x4.ANCHOR` used as validation · MEASUREMENT quoted as support**

    "empty(B) 4×4 = +2 matches the published anchor" (retrograde-4x4.md:74-84)
      quoted in support of 4x4.C1
      ⟵d GLOBAL.P1 ("anchor match ⇒ real-game correctness")  [FALSE-AS-SCOPED]
      and produced by an artifact ⟵d GLOBAL.F1                [FALSE-AS-SCOPED]

The measurement stands; its use as validation is orphaned. `4x4.CYCLE-INSENS`
("the 4×4 empty-goban score is evidently cycle-rule-insensitive",
`retrograde-4x4.md:77-80`) rests on the same single agreement and is CLAIMED on
one data point.

**O5 — `4x4.COMPLETE-2026-07-21` · asserted as PROVEN in an un-retracted doc**

    retrograde-4x4.md:1-13 — "the complete, validated 4×4 oracle —
      every legal (position, side) exact"
      ⟵d GLOBAL.F1 (generated writes-on)      [FALSE-AS-SCOPED, 2026-07-23]
      ⟵d GLOBAL.C1 as real-game correctness   [FALSE via C2/C4]

`PROGRESS.md:267-270`, `0013:126-128` and `AGENTS.md:54-57` all retract it, but
`retrograde-4x4.md` — a `research/` note, i.e. a historical record — still opens
with the claim and no erratum banner. Recorded here as a *documentation* orphan;
whether `research/` notes should carry retraction banners is a method question
for the user.

**O6 — `GLOBAL.ADR0012-GATE` (the sha256 regression gate) · CLAIMED (orphaned)**

    0012:46-49,157-159 — "must reproduce the 4×4 artifact BYTE-IDENTICAL
      (sha256 recorded in retrograde-4x4.md)"
      ⟵d 4x4.COMPLETE-2026-07-21               [FALSE-AS-SCOPED, O5]

    The standing pre-big-goban gate targets a hash of an artifact generated with the
    unsound (writes-on) guard. Reproducing it byte-identically would now be evidence of
    reproducing the bug. T128 triage (2026-07-31): re-point the gate to the Track A
    writes-off artifact when complete. Until then, the gate is CLAIMED-and-orphaned —
    the structure is correct (gate makes sense, just has no valid target).

**O7 — `GLOBAL.CERTCORE` (ADR-0009 Decision 2) · stated as a Decision**

    0009:65-67 — "where L == H, the score cannot depend on any cycle rule …
      equals the fresh-start score (and the mid-game score under ANY ban set)"
      ⟵d GLOBAL.FP2 ⟵d GLOBAL.FP2-bounded      [FALSE at 3×2, T13]

ADRs are append-only, so the sentence stands. `0009:78-89` (the honesty clause)
already flags it as "strong structural evidence, not a theorem", but the
Decision heading does not. No superseding ADR retires it.

**O8 — `0013:128` — "The certified `L==H` core is unaffected and remains correct"**

    0013:126-128 (written 2026-07-23)
      ⟵d GLOBAL.C2                             [FALSE at 3×2, 2026-07-26]

Read as "remains fresh-start correct" it survives; read as written — in a
Consequences section about trustworthiness — it asserts more than C1. Same
append-only situation as O7, and adjacent to `GLOBAL.B-1`, the other ADR-0013
Consequences bullet already convicted (`corrections:136-171`).

**O9 — `4x4.M3` quoted as the finisher cost basis · MEASUREMENT**

    4x4.M3 (6.1 min, ~1,663 nodes/rep, 1,080,118,252 nodes)
      measured on the writes-on config ⟵e GLOBAL.F1   [FALSE-AS-SCOPED]

An `evidenced-by` edge, so by the rule in §1 this becomes **UNTESTED for the
writes-off configuration**, not false. It is quoted as the cost of "the
finisher" in `open-hypotheses:286-291` and `0013:64-65` without that
qualification, and ADR-0013 explicitly warns that "writes off forfeits the
within-search bounds reuse that made MTD probes incremental".

**O10 — `4x4.F1` and `4x3.F1` · CLAIMED via inheritance**

Both are *claims that something is unsound*, derived from a falsified parent by
inheritance rather than measurement. Logically they are the safe direction to
err in, but they are still CLAIMED-by-inheritance rows and appear in the
inheritance audit as §5-I1 and §5-I2.

**Not orphaned — recorded so the boundary is clear.** `4x4.M1` (21.32%),
`4x4.M2` (19 sweeps), `4x4.BRACKET`, `4x4.SINGLE`, `4x3.M1`, `3x3.M1`,
`GLOBAL.SWEEPS` and every other converge-derived number are produced by the L/H
fixpoint iteration, which does **not** use the finisher memo
(`0009:28-46`, `0013:50-65`). They survive `GLOBAL.F1` intact. Likewise
`GLOBAL.CHAIN-LH` and `GLOBAL.CHAIN-KO` survive, because `4x4.M6` shows zero
outside-flag violations on the writes-off artifact too.

### 4.2 Load-bearing unknowns

*UNTESTED claims ranked by dependent count — where one experiment buys most.*

**Counting rule:** the `dependents` figure below is the number of distinct
downstream items named in the register's `dependents` column, which includes
consequences without a §2 row of their own (an artifact, a deliverable, a
packaging decision). Formal in-degree — edges written in a `depends-on`
column — is given in brackets where it is lower.

| rank | claim | status | dependents | what one experiment buys |
|---|---|---|---|---|
| 1 | `4x4.D3` — writes-off 4×4 tractability | UNTESTED | 7 [4]: `4x4.F2`, `4x4.F3`, `4x4.F4`, `GLOBAL.H4a`, artifact promotion, `4x4.C1` upgrade, `PROGRESS.md:243-245` Track A | It is a **measurement, not a truth claim** (`4x4/EPISTEMIC.md:175`), and it is the single gate on the entire Track A branch. Cheap proxies already specified: a D3-4×3 pilot and a `RETRO_ONE_SWEEP=1` per-sweep unit × 19 |
| 2 | `4x4.F3` (with `4x4.F2` riding the same regen) — writes-off finisher sound at 4×4 | UNTESTED | 6 [1]: `4x4.C1`, `4x4.F4`, `4x4.M6-EXCESS` → PROVEN, artifact promotion to `data/`, the 4×4 deliverable, `GLOBAL.B15` generalisation | The **#2 auditor** on a completed writes-off regen is the only thing that converts `4x4.M6`'s screen into a verdict. `4x4.M6` already supplies cheap corroboration (4.08% → 1.67%) but explicitly does not discharge it |
| 3 | `4x4.FP1-C1` + `4x4.FP1-C2` — the seed and zero-change checks | UNTESTED | 5: `4x4.FP1`, `4x4.BRACKET` meaning, `4x4.C3`, `GLOBAL.F2` at 4×4, the shipped bracket half of the deliverable | Both are **post-hoc reads of existing build logs and the on-disk artifact** (`4x4/EPISTEMIC.md:71-75`) — no new build. Check 3 already passes (`4x4.M4`). This is the cheapest way to finish an acceptance test that is two-thirds done |
| 4 | `4x4.S3b` — ko-legality under PSK history at 4×4 | UNTESTED | 5: `4x4.R1`, `4x4.C1`, `4x4.C2`, `4x4.C3`, `4x4.M1` | The load-bearing sub-claim that separates a legal-*position* count from a legal-(position, history)-*pair* count. OEIS A094777 does **not** attest it (`4x4/EPISTEMIC.md:135-140`), and **no falsification test is designed yet** — the only top-5 entry with no experiment on paper |
| 5 | `GLOBAL.LONGCYCLE` — "long cycle = tie" is a computable loopy-game fixpoint | UNTESTED | 4: `GLOBAL.H1`, `GLOBAL.H1-CENSUS` interpretation, any simple-ko build, the post-PSK roadmap | H1's census can return GO and still leave the project unable to build anything: `open-hypotheses:92-103` states plainly that this "is UNVERIFIED and must not be asserted", and `GLOBAL.R2` forecloses every resolution rule that needs to know which earlier gobans were seen |

**Runners-up** (rank 6–8, same method): `4x4.C1` (5 dependents, but no
tractable experiment exists — the exact solver is intractable at 4×4 from
empty, so it is folded into the C2-probe harness); `GLOBAL.H1-CENSUS` (4
dependents, and the cheapest single experiment in the whole project at ~183 MB
and minutes of wall time — it can change the project's *direction* rather than
its confidence); `4x4.S2-impl` (3 dependents, Wave-0 cheap, independent of every
artifact).

**One honourable mention that the rule as written excludes.**
`GLOBAL.ADR0006-EYE` (the eye-prune weak-dominance claim) carries a formal
in-degree of only **4**, but its `dependents` column names **8** downstream
items, and the list is the alarming part — it includes every
forward search the project has ever used as ground truth: the 2×2/3×2 exact
solver behind `2x2.C1`/`3x2.C1`, the finisher behind every shipped ko-sensitive
value, the T13 C2-probe, the E2 range-aware player, and the eye-pruned move set
in `4x4.M4`. It is excluded from the ranking because its status is CLAIMED, not
UNTESTED: ADR-0006 gives an argument (`0006:34-49`) and ADR-0009 notes that any
retrograde-vs-forward disagreement would falsify it (`0009:118-123`). But it has
**never been the subject of a direct falsification test**, its only cited
direct validation is a single position (`dead_white`, Black +25, `0006:59-61`),
and `consistency-audit.md:48-49` names "the eye-prune is sound" as one of
exactly three invariants that writes-off correctness rests on. If the user wants
one more experiment beyond the five above, this is the one with the widest blast
radius.

---

## 5. Inheritance audit — flagged, not resolved

`AGENTS.md:8-13` and `CONCEPTS.md:65-71` forbid using a claim at one goban size
as evidence at another. The project also inherits when convenient. Both are
recorded below. **Kind** is this register's reading of *what the inherited thing
is about*, offered as a starting point only:

- **structural** — the inherited statement is about code or mathematics, so
  "goban size" may not be the right unit of scope at all. Plausibly legitimate.
- **empirical** — the inherited statement is about a goban. Forbidden by the
  rule as written.
- **mixed** — a structural claim whose only evidence is empirical, at other
  sizes.

**No ruling is made** on any individual row below. The user and Opus decide.

**2026-07-28 — the *rule* is now ruled on, the rows are not.** D-2 (Opus + GLM)
found the per-goban-independence rule as stated to be **mis-stated**, and
**ADR-0016** replaces it: *empirical* claims never inherit; *structural*
claims — code or mathematics — may, **with the inheritance argument written
down**, and a status does not upgrade on inheritance. The `kind` column below is
therefore the operative classification rather than a suggestion. Two limits,
stated because they are easy to over-read:

- **`mixed` was NOT ruled on** (I3, I4, I18, I19) and **cross-ruleset** (I24) was
  not either. Both fall under the empirical default: no inheritance is licensed.
- **Each row still needs its argument written down, or its inheritance
  withdrawn**, by the owner of the goban file it lives in. ADR-0016 does not
  discharge a single row below, and this register still does not adjudicate them.

| # | claim | what was measured, where | what was inherited, to where | kind | self-flagged? |
|---|---|---|---|---|---|
| I1 | `4x4.F1` | `ko_ref ≥ d` guard: **45/378** auditor violations at **3×2**, 0 with writes off (`consistency-audit.md:25-34`) | Asserted at **4×4**: "the guard is the same code at 4×4; the bug is structural, not size-dependent" — and the 4×4 auditor sample **did not finish** (`4x4/EPISTEMIC.md:49-52`) | **structural** (a claim about a source-level guard) | yes — listed under Falsifications with the caveat |
| I2 | `4x3.F1` | same 3×2 measurement | Asserted at **4×3**: "the same unsound guard used to generate the committed 4×3 artifact" (`4x3/EPISTEMIC.md:35,48-50`) | **structural** | yes |
| I3 | `4x4.R1` | PSK exact-solve: **118,475,182** ban-set states on the empty **2×2**, budget-exceeded (`ruleset-options.md:91`) | Asserted at **4×4** as "R1 ✅ PSK intractable (structural; measured at 2×2)" (`4x4/EPISTEMIC.md:22`) and globally as a foreclosure (`AGENTS.md:47-49`) | **mixed** — the growth argument is structural, the evidence is one goban | partially (the parenthetical names the size) |
| I4 | `GLOBAL.R2` | score-on-cycle vs PSK: byte-identical state counts at **2×2** and **3×2** only; 3×3/4×3 rows OOM'd (`ruleset-options.md:163-174`) | Foreclosed **globally and at every size**: "not a coincidence, a proof of structure" (`AGENTS.md:52-53`) | **structural** (an argument about the recursion tree, with two-goban evidence) | the note argues structurally; the foreclosure does not restate the scope |
| I5 | `4x4.S4` | `rules.area_score` cross-validated at smaller sizes (500 gobans vs `terminal.zig`, `0008:63-66`) | Area scoring asserted correct at **4×4** | **empirical** | yes — explicitly downgraded to `⬜ᴵᴺᴴ` with a TODO |
| I6 | `4x3.S4` | same | Area scoring asserted at **4×3** | **empirical** | yes — `⬜ᴵᴺᴴ` |
| I7 | `4x3.S1` | Colex bijection exhaustively round-tripped **through 4×4** | Asserted **✅ PROVEN** at 4×3: "4×3 raw space is smaller … and inherits the same structural proof" (`4x3/EPISTEMIC.md:24`) | **structural** (mixed-radix layout is size-generic) | the reasoning is stated; the status is nonetheless ✅ |
| I8 | `4x3.S2` | Benson's theorem (mathematics) | Asserted **✅ PROVEN** at 4×3: "holds for all finite gobans" | **structural** | yes — CONCEPTS.md:10-12 explicitly authorises theorem inheritance |
| I9 | `4x4.C3` | **C3 falsified at 3×3** (E2, 25/4000 games, promise +3 → final −9) | Asserted at **4×4** as "**analogy-expected falsified**, NOT an open hypothesis"; the deliverable decision is told not to wait for a 4×4 run (`4x4/EPISTEMIC.md:55-66`). The **4×3 file refuses the identical inheritance**: "per-goban independence forbids importing the 3×3 result" (`4x3/EPISTEMIC.md:34`) | **empirical** | partially — the 4×4 file argues from semantics ("PSK removes moves; lo only pessimises cycles") but records the status as inherited |
| I10 | `4x4.C2` | **C2 falsified at 3×2** (T13, 12/508) | Asserted at **4×4**: "4×4 falsification is analogy-expected, **not an open hypothesis**" (`4x4/EPISTEMIC.md:46,98`), while `PROGRESS.md:212-213` lists C2 at 4×4 as an untested TODO citing per-goban independence | **empirical** | contradictorily — flagged in one file, inherited in another (§6-D3) |
| I11 | `4x4.C2` corroboration | 4×4 arena: **176 single-score + 300 ko-sensitive real divergence events** (`arena-4x4-undef.md:87-91`) | Quoted as "corroborates history-dependence **at scale**" (`PROGRESS.md:127`) | **native to 4×4** — not an inheritance; recorded here because it sits beside I10 and is the only 4×4-native C2 evidence | n/a |
| I12 | `GLOBAL.C4` | The leak, measured at 2×2/3×2/3×3/4×4 | Asserted at 4×4 as "❌ **structural**" (`4x4/EPISTEMIC.md:26`) | **structural** (true by construction on ko-sensitive slots: a fresh-start value is defined under an empty history) | yes — tagged "(structural)" |
| I13 | `4x4.P3` | Arena leak **8–16%** measured on the 2×2/3×2 tables (`4x4/EPISTEMIC.md:53-54`) | Listed as a 4×4 Falsification, with 2×2/3×2 evidence, in the 4×4 tree | **empirical** | no — the entry names the other gobans but files the fact under 4×4 |
| I14 | `GLOBAL.P1` | — | "anchor ≠ real-game correctness (**structural**)" (`4x4/EPISTEMIC.md:24`) | **structural** (a logical claim about what an anchor can attest) | yes |
| I15 | `4x4.FP3` | Knaster–Tarski on a finite lattice | Asserted at 4×4 as `⬜ᴵᴺᴴ` — **not** re-derived as a 4×4 claim. The **4×3 file marks the identical claim ✅ PROVEN** with the identical justification | **structural** | yes at 4×4, no at 4×3 — inconsistent handling of the same theorem (§6-D4) |
| I16 | `GLOBAL.MAXGAP` | Worst misprice = 2n at **3×2, 3×3, 4×3, 4×4** (12/18/24/32); 2×2 is the exception | Stated as a CLAIMED regularity "for every goban with n ≥ 6", with an explicit refusal to carry it to 5×5 | **empirical** (a cross-size generalisation over four gobans) | yes — "no proof offered; per-goban independence forbids extrapolating it to 5×5" |
| I17 | `GLOBAL.SWEEPS` | Sweep counts 2/6/12/19 and falling ko-sensitive fractions at 2×2→4×4 | "Both trends are **favourable for 5×5**" (`retrograde-4x4.md:30-32`); `GLOBAL.ADR0012-5X5` builds a feasibility projection on them | **empirical** cross-size extrapolation — precisely the "this suggests X at larger gobans" pattern `AGENTS.md:11-13` names | no |
| I18 | `GLOBAL.ADR0006-EYE` | Argued from area-scoring theory; direct validation cited at **one** position (`dead_white` = Black +25, `0006:59-61`) | Applied at **every** goban size, in every forward search, as a soundness precondition | **structural** (argument) with a thin empirical base | the ADR states the argument; ADR-0009:118-123 supplies the standing indirect test |
| I19 | `GLOBAL.ADR0012-PAR` | Chaotic-iteration theory for monotone maps; **no measurement cited** | Asserted for all parallel builds at all sizes, and used to justify final-hash verification under threads | **structural** | no |
| I20 | `GLOBAL.F4` | `deps` mode validated at **3×2, 3×3, 4×3** (0 auditor violations, byte-identical to writes-off) | **NOT** inherited: `4x4.F4` is correctly marked ⬜ UNTESTED with a byte-compare experiment specified | — | **compliant example**, recorded to show the rule being honoured |
| I21 | `4x4.M6` ratio | ≈2.4× writes-on/writes-off excess at **4×4** | **NOT** carried anywhere: "per-goban independence forbids carrying the 2.4× ratio to any other size" | — | **compliant example** |
| I22 | `4x3.S2-impl` | "S2-4×4 implementation regression (`rules.zig` vs naive) passed for ≤8 stones" | **Refused** at 4×3: "4×3 not explicitly run" | — | **compliant example** — but the cited 4×4 pass contradicts `4x4.S2-impl`'s own UNTESTED status (§6-D6) |
| I23 | `3x2.T13` → `GLOBAL.C2` | 12/508 mismatches at **3×2** | Promoted to a **global** foreclosure: "the single-score region is NOT history-independent … settled false at the smallest testable goban" (`AGENTS.md:68-73`) | **empirical**, promoted to global | the foreclosure names the goban; the framing ("settled") does not scope the conclusion |
| I24 | `4x4.CYCLE-INSENS` | 4×4 empty-goban score +2 agrees with MIGOS II, which plays a **different ruleset** (basic ko + long-cycle-ties) | Inferred: "the 4×4 empty-goban score is evidently **cycle-rule-insensitive**" (`retrograde-4x4.md:77-80`) | **cross-ruleset**, not cross-goban — a fourth kind the rule does not name. One agreement; the same comparison **disagrees** at 2×2 and 3×2 | no |
| I25 | `GLOBAL.ADR0005-CACHE` → `GLOBAL.ADR0008-HOLE` → `GLOBAL.F1` | The `ko_ref ≥ d` rule stated as a **theorem** (`0005:90-93`), downgraded to "sound-in-practice compromise, not a theorem" (`0008:34-38`), then falsified (`0013`) | Not a goban inheritance but a **status inheritance**: every artifact persisted between 2026-07-15 and 2026-07-23 was written under the theorem-strength reading | — | the downgrade is explicit in ADR-0008; the artifacts written under the stronger reading were not re-labelled at the time |

---

## 6. Discrepancies

Every numeric or status conflict found. **None is resolved here.**

**D1 — E2's 3×3 leak count: 50/8000 vs 25/4000. — RESOLVED 2026-07-28 (D-1, Opus).**
`PROGRESS.md:128` — "C3 … FALSE-AS-SCOPED at 3×3 (E2: **50/8000** leaks, max 12 pts)".
`leak-crisis.md:36` — "E2 found 3×3 leaks (**25/4000** games…)", and its table
at `leak-crisis.md:74` records `3×3 | 4000 | 25`.
`4x4/EPISTEMIC.md:58` and `open-hypotheses:289` both say **25/4000**.
The rate is identical (0.625%); the run size is not. Two runs, or one run
double-counted. Not guessed.

> **Resolution (ruling D-1, Opus, 2026-07-28; retired from the open list).**
> **It is not a discrepancy. They are two real runs.** 25/4,000 is the original
> E2; 50/8,000 is B06's re-run. The rate is identical (0.625%) and the maximum
> is identical (12 pts) **because the second run replicated the first** — which
> is evidence, not a bookkeeping error. **Both are kept as separate rows**
> (`3x3.E2-RUN1`, `3x3.E2-RUN2`, §2.3): collapsing them into one number would
> destroy the independent replication, which is the strongest thing E2 has.
> `QA-009` — the row that asserted a discrepancy — is now **FALSE**.
> **What is still open, and it is not the same question:** the 8,000-game run has
> **no committed output**. Its numbers survive only in `PROGRESS.md:128`. That is
> C3-class evidence debt on `3x3.E2-RUN2`, recorded in the row.
> **Not done here:** `PROGRESS.md:128` and `leak-crisis.md:36,74` still each
> report one run without saying that a second exists. Adding that provenance is
> the job of those files' owners; this register does not edit them.

**D2 — C3 at 4×4: falsified-by-analogy vs untested.**
`4x4/EPISTEMIC.md:55-66` files C3 under **Falsifications** ("analogy-expected
falsified at 4×4 (NOT an open hypothesis)").
`4x3/EPISTEMIC.md:34` refuses the identical inference for 4×3 ("per-goban
independence forbids importing the 3×3 result").
`CONCEPTS.md:57-61` states both at once: "**falsified at 3×3 by analogy-expected
falsified at 4×4**" — a sentence that does not parse and appears to be a merge
artifact. Two goban files apply opposite rules to the same inheritance.

**D3 — C2 at 4×4: not-an-open-hypothesis vs open TODO.**
`4x4/EPISTEMIC.md:46,98` — "4×4 falsification is analogy-expected, **not an open
hypothesis**"; `4x4/EPISTEMIC.md:329-331` — "No further C2-probe needed at 4×4".
`PROGRESS.md:212-213` — "`TODO` (C2 at 3×3/4×4): **untested**. Falsified at 3×2
(T13), per-goban independence prevents inheritance."
`4x3/EPISTEMIC.md:33` — "Do not inherit the 3×2 falsification as a 4×3 result."
Three documents, three positions.

**D4 — FP3 status differs between goban files with identical justification.**
`4x4/EPISTEMIC.md:37-43` — FP3 is `⬜ᴵᴺᴴ`, "has **not** been re-derived as a
4×4-specific claim".
`4x3/EPISTEMIC.md:31` — FP3 is **✅ PROVEN**, "Knaster-Tarski on a finite
lattice; size-generic structural proof".
Same theorem, same argument, opposite statuses.

**D5 — the arena baseline band: 8–18% vs 8–16%, and 3.4% "within" it.**
`PROGRESS.md:114-115` and `arena-4x4-undef.md:79-81` — the T06 baseline band is
**8–18%**.
`4x4/EPISTEMIC.md:53-54` — "fresh-start player leaks **8-16%** of games".
Separately, `arena-4x4-undef.md:79-81` describes the 3.4% clean rate as "within
and slightly better than the T06 baseline band of 8–18%" — 3.4% is **below** 8%,
not within it. `PROGRESS.md:116-118` states the same figures without the "within"
claim.

**D6 — `S2` means two different claims, and its 4×4 status conflicts.**
`4x3/EPISTEMIC.md:25` — `S2` = Benson-alive **theorem**, ✅ PROVEN; `S2-impl` is
a separate row.
`4x4/EPISTEMIC.md:158-167` — `S2` = the **implementation** regression, ⬜
UNTESTED, filed under Unknowns.
`CONCEPTS.md:10-12` defines both and keeps them distinct — so the 4×4 file's
label is the non-conforming one.
Worse, `4x3/EPISTEMIC.md:26` reports that "**S2-4×4** implementation regression
(`rules.zig` vs naive) **passed** for ≤8 stones", which contradicts
`4x4.S2-impl`'s own UNTESTED status in the 4×4 file.

**D7 — ko-sensitive fractions: converge-census vs chainability sweep.**

| goban | census (`retrograde-3x3.md`, `ruleset-options.md`, `M1` rows) | chainability sweep (`ko-sensitive-chainability.md:50-54`) |
|---|---|---|
| 2×2 | 72% (41/57) | 77.36% |
| 3×2 | 39% (189/489) | 41.18% |
| 3×3 | 34.3% (8,698/25,350) | 35.04% |
| 4×3 | 26.47% (170,276/643,378) | 26.60% |
| 4×4 | 21.32% (exhaustive) | 21.27% (1:37 sample) |

Only the 4×4 row is reconciled in the documents (0.05 pp, attributed to
sampling). The other four differ by 0.13–5.36 pp and are nowhere reconciled.
The likely explanation — the sweep reports "% of *checked* slots" and skips
settled slots, while the census reports "% of *legal* slots" — is **not stated
anywhere**, and the 2×2 gap (5.36 pp) is large enough to matter.

**D8 — the empty 3×2 Black-to-move score: +1 vs −2 vs 0.**
`0011:50-51` and `retrograde-3x3.md:220` — `oracle-3x2.wzo` empty(B) = **+1**
(finisher-produced, in-bracket, "ground-truth-consistent").
`consistency-audit.md:32-34` and `0013:20-21` — the committed (`new`) generation
"reports Black-score **−2**, yet its own best child … is **0** — the published
3×2 score".
`retrograde-3x3.md:234-238` — published 2×3 = **0** vs weizigo's "exhaustively
ground-truthed PSK score" of **+1**, explained as a legitimate ruleset-variant
difference.
So: three values for the same slot in the same generation, and two documents
disagree on whether **0** is the target (auditor: yes, "the published score") or
a different ruleset's answer that PSK is expected to beat by a point
(`retrograde-3x3.md`: the latter).

**D9 — "exhaustive ground truth at 2×2/3×2" vs 8/114 and 68/600 roots.**
`CONCEPTS.md:50-52` — C1's proof method is "**exhaustive** comparison vs
independent exact solver".
`0009:90-93` — validation plan item 1 is "**Exhaustive** ground truth at 2x2 and
3x2 … of EVERY legal (position, side)".
`leak-crisis.md:24` — C1 is **PROVEN** "(vs history-aware exact solver)".
`retrograde-3x3.md:50-52` — "only the near-terminal roots complete (2x2: **8 of
114**; 3x2: **68 of 600**)".
`retrograde-3x3.md:141,188` — calls 8 and 68 roots "exhaustive ground truth …
0 mismatches (**8 and 68 reachable roots**)".
Partial mitigation, not noted in the C1 rows: `c2-falsification-3x2.md:56-57`
records a fresh-start sanity check with **0 mismatches on all 540 L==H slots**
at 3×2 — strong for the single-score half, silent on the 189+189 ko-sensitive
slots.

**D10 — `GLOBAL.B15` byte-identical regen vs 45 auditor violations at 3×2.**
`PROGRESS.md:238-240,244-245` — "Track A 2×2/3×2 regen complete (B15,
**byte-identical**)".
`consistency-audit.md:29-30` — at 3×2 the writes-on variant has **45**
violations and writes-off has **0**.
If turning the memo writes off changes 45 slots' worth of search behaviour yet
produces a byte-identical table, then either the auditor tests the search rather
than the table (plausible — `consistency-audit.md:15-19` solves each node as an
independent root), or the two statements are in tension. Not resolved here.

**D11 — a history-perfect genmove is "trivially affordable" vs H3 is open.**
`retrograde-4x4.md:147-151` (2026-07-22) — history-exact solves cost 65k nodes
at ply 1, sub-1k from ply 7: "A HISTORY-PERFECT genmove … is therefore trivially
affordable at 4×4."
`open-hypotheses:170-214` (2026-07-27) — H3 treats exactly this as an **open,
unmeasured** question, and `ko-sensitive-chainability.md:269-274` re-measures
memo-free history-exact search as intractable (empty 3×2 does not finish in
100 s).
The reconciliation is that the 2026-07-22 figures used the **bracket-cut**
search — i.e. claim C3, falsified the next day at 3×3 — so the cheap number was
bought with the unsoundness. Neither document says so; `retrograde-4x4.md`
carries no erratum.

**D12 — the 4×4 raw size: 43 MB vs 258 MB.**
`0008:75-77` — "4x4 = **43 MB** raw".
`0011:35-36,60` and `retrograde-4x4.md:7` — "**258 MB**" / 258,280,358 bytes.
Reconcilable (43 MB × 6 columns), but only if the reader already knows
ADR-0009's six-column schema; no document states the reconciliation.

**D13 — the persist gate forbids UNDEF on legal slots, yet UNDEF artifacts are in use.**
`0011:39-46` — `saveArtifact` "refuses to write unless … **no UNDEF value on any
legal slot**".
`arena-4x4-undef.md:20-26` and `PROGRESS.md:211` — `data/oracle-4x4-parallel.
checkpoint.wzo` is 99.8% filled with **83K UNDEF slots**, and is the artifact the
B43 arena audit and the shipped GTP player read.
These are *checkpoint* writes rather than `saveArtifact` writes, which likely
explains it — but the documents quote checkpoint files (`data/oracle-4x4.
checkpoint.wzo`, `data/oracle-4x4-parallel.checkpoint.wzo`,
`untracked/oracle-4x4-writesoff-checkpoint.wzo`) interchangeably with artifacts,
and every headline 4×4 number since 2026-07-27 comes from a checkpoint, not from
a gate-passed artifact.

**D14 — ADR-0007's eye-prune tension is resolved but never closed in writing.**
`0007:37-43` — the eye-prune-vs-total-coverage tension is left **unresolved** and
"must be flagged before persisting scores".
`0009:109-124` — ADR-0009 Decision 3 resolves it (retrograde uses the full move
set; coverage is total).
`0011:48-56` — artifacts were persisted.
No document records that ADR-0007's open item was discharged by ADR-0009.

**D15 — the empty 3×3 bracket contains the anchor but not the real-game score.**
`retrograde-3x3.md:102-110` — all five 3×3 anchors are in-bracket; empty(B)
bracket = [+2, +9], published +9. Reported under "Soundness confirmed".
`leak-crisis.md:66,74-79` — the same bracket [2,9] does **not** contain the real
3×3 game score of −9.
Both are true (the anchor is a fresh-start-comparable number, the −9 is a
real-game outcome), but `ruleset-options.md:215` still reports bracket
containment under the heading "**Soundness confirmed**", which reads as a
soundness claim that `GLOBAL.C3` falsifies.

**D16 — `4x4.M4` misprice rate quoted from two different artifacts.**
`4x4/EPISTEMIC.md:187-198` and `ko-sensitive-chainability.md:45,54` — the 4.08%
figure is from `data/oracle-4x4.**checkpoint**.wzo`.
`PROGRESS.md:74-77` — attributes the same sweep to
"`data/oracle-4x4.checkpoint.wzo`" correctly, but `AGENTS.md:54-57` and
`PROGRESS.md:267-270` discuss trust in terms of `data/oracle-4x4.wzo` (the
gate-passed artifact, sha256 `b42c3371…`). Whether the checkpoint and the
artifact are byte-identical is nowhere stated. `4x4.M6`'s slot counts
(1,313,248 vs 1,310,854) show the checkpoint family is not internally uniform.

**D17 — the corrections ledger has no remediation column, and two of its five
entries are already fixed.**
Verified on 2026-07-28: `regressions/README.md` now carries A-1's corrected
causal attribution (the old line-21 wording is gone), and `src/gtp.zig:42` now
reads "the player is neither history-perfect NOR fresh-start-perfect", closing
A-3's `src/gtp.zig:37` item. `corrections-2026-07-27.md` still lists both under
"What to change" as open, addressed to other agents. A reader of the ledger
alone cannot tell which errata are live. `GLOBAL.B-1` (the ADR-0013 Consequences
bullet) remains **open** by design — ADRs are append-only, so it needs a
superseding ADR, not an edit.

**D18 — EXP-3's calibration 2 contradicts its own dispatch, and the
cross-check that settles it is not committed.** Recorded 2026-07-28 when the
census rows were added; **not resolved here.**
`docs/infra/dispatch/EXP-3.md` asserts that with the ko dimension forced to
`none` the reachable count collapses to the `(position, side)` slot counts
**25,350 / 643,378 / 48,636,330**.
`kostate-census-2026-07-28.md:104-144` measured **20,888** (3×3) and
**45,734,854** (4×4) and states plainly that *the dispatch is wrong, not the
walk*: the dispatch's figures are the **total addressable** `(position, side)`
space, while the walk counts **reachable from the empty goban under alternating
play** — two different denominators. The census author flagged this himself
(`kostate-census-2026-07-28.md:260-264`), which is why the row is PROVEN rather
than held.
**But the evidence for the explanation is not in git.** The independent
depth-parity BFS that produced the reconciling number (3×3 has only **11,109**
`(position, side)` pairs reachable from `(empty, B-to-move)`) was written to
`/tmp/test_census_pure.zig` and deliberately not committed as "a sanity
throwaway". `weizigo-claimlint` C2 now reports that path as dangling, reachable
from all three `H1-CENSUS` rows. **This is the T13 mechanism exactly** — the
cross-check that makes a calibration disagreement explicable rather than
alarming, living outside git. The headline census numbers do not depend on it;
the *dismissal of the calibration mismatch* does.
Whoever owns `EXP-3.md` should correct the expected figure; whoever can still
reproduce the BFS should commit it under `docs/evidence/GLOBAL.H1-CENSUS/`.

---

## 7. Evidence-integrity note (found while sweeping)

Several of the project's most load-bearing claims cite evidence files under
`untracked/`, which is **git-ignored** (`.gitignore:8`). Checked on 2026-07-28,
the following cited files **do not exist on disk**:

| cited as | cited by | present? |
|---|---|---|
| `untracked/T13-minimax.md` | `leak-crisis.md:25,109`; `c2-falsification-3x2.md:4,134` | **RECOVERED** — T110 re-implementation at `docs/evidence/T13/` (T128 triage §1) |
| `untracked/c2pilot_3x2.zig` (the C2-probe source) | `c2-falsification-3x2.md:21,127,133` | **RECOVERED by re-implementation** — `docs/evidence/T13/` (T110); original is claimlint's known-bad C2 calibration fixture |
| `untracked/T12-minimax.md` (C2-pilot-2×2) | `4x4/EPISTEMIC.md:287-288` | **missing** |
| `untracked/T02-minimax.md` (B1 least-fixpoint results) | `leak-crisis.md:103,180` | **RECOVERABLE** — method at `b1-least-fixpoint/b1-spec.md`; numbers need regeneration (T128 triage §3) |
| `untracked/T02-audit-kimi.md` (the audit convicting (a′)) | `leak-crisis.md:104,180` | **LOST** — two-line paraphrase at `leak-crisis.md:99-101`; decision survives, reasoning does not (T128 triage §4) |
| `untracked/T07-audit-hypotheses.md` (the eight findings that rewrote the 4×4 tree) | `4x4/EPISTEMIC.md:12` | **LOST** — product is `4x4/EPISTEMIC.md`; the eight itemised findings are gone (T128 triage §5) |
| `untracked/B05-glm.md` (the reframe scope) | `PROGRESS.md:277`; `leak-crisis.md:145,151`; `4x4/EPISTEMIC.md:269` | **LOST** (durable summary exists) — decision fully documented at `GLOBAL.REFRAME`; the discussion that shaped it is gone (T128 triage §6) |
| `untracked/B39-arena4x4.md` | `arena-4x4-undef.md:11-14` (records its own deletion by B44) | **RETRACTED** — superseded by `4x4.B43`; retraction at `arena-4x4-undef.md:27-44` (T128 triage §7) |
| `untracked/discussion.md`, `untracked/idea-heap.md` | `AGENTS.md:169-171` | **missing** (2026-07-25 copies survive in `untracked/archive/`) |

Consequences for the register, stated without recommendation:

- **`3x2.T13` was not reproducible at the time of the sweep (2026-07-28).**
  It has since been independently re-implemented from the method description
  (2026-07-30, `docs/evidence/T13/probe-reimplementation-2026-07-30.md`,
  `docs/evidence/T13/t13_probe.py`, `docs/evidence/T13/zig_t13_replay.zig`).
  All twelve recorded contradiction lines re-execute exactly; all census
  numbers match. The original probe source (`untracked/c2pilot_3x2.zig`) and
  raw output (`untracked/T13-minimax.md`) remain lost — the re-implementation
  is independent evidence, not a recovery — so `QA-022` is unchanged. The
  order-independent measurement (§8 of the re-implementation report) shows the
  falsification is over 10× broader than the original 12-mismatch count
  suggested: 154 of 508 reachable L==H slots (30.3%) are history-sensitive.
- **`2x2.B1` / `3x2.B1` / `3x3.B1` have no durable evidence file.** Their only
  surviving record is the summary at `leak-crisis.md:86-101`. They are the
  parents of `GLOBAL.B1-AUDIT`, which is what removed the re-converge check from
  FP1 acceptance.
- **`GLOBAL.UD-1` / `UD-2` / `UD-3` cannot be verified at all** — `PROGRESS.md:
  238-240` points at `untracked/SUBAGENTS.md`, which exists, but the decision
  records themselves are cited only in bundles that were swept.
- `arena-4x4-undef.md:10-18` already documents this failure mode happening once
  (B44's cleanup deleted B43's write target) and its own lesson is
  "prefer writing durable findings to git `docs/research/` directly". The
  register records that the same mechanism removed the evidence for T13, T02,
  T07 and B05.

---

## 8. Maintenance

- **Never renumber.** Every row carries its legacy ID; new rows mint an ID per
  §1 and leave the legacy column `—`.
- **Adding a claim** means adding its edges. A row with no `depends-on` is
  asserting it rests on nothing; say so deliberately.
- **Changing a status to FALSE-AS-SCOPED** obliges a re-run of §4.1: every
  PROVEN/CLAIMED descendant reachable by `derives-from` becomes an orphan, and
  every descendant reachable by `evidenced-by` becomes UNTESTED. **Do not do
  that sweep by hand** — `weizigo-claimlint` does it mechanically, and doing it
  by hand is how O1 went unnoticed for weeks.
- **Run the linter after any edit to this file.**

      zig build && ./zig-out/bin/weizigo-claimlint

  It parses §2, walks the `derives-from` graph, and reports orphaned claims,
  dangling evidence paths, PROVEN claims whose evidence is not committed under
  `docs/evidence/`, dangling claim IDs, repeatedly-narrowed claims, and
  weak-evidence PROVEN rows. Each check maps to a failure this project actually
  suffered; the check-to-incident map, the calibration cases and the first full
  run are in `claimlint-2026-07-28.md`. **A row it cannot parse exits 3** — the
  parser never skips a row silently, so a malformed edit is loud, not
  invisible. As of the last run on 2026-07-28 the register does not pass its own
  linter: **10 C1a orphans, 0 C1b alarms, 10 C2 dangling evidence paths**
  (253 rows, 290 edges, exit 1). That is recorded debt, not a reason to soften a
  status. **Do not copy these numbers into another document** — the run prints
  them, and the counters move whenever a cited document is edited (they moved
  three times on 2026-07-28 while `AGENTS.md` was being rewritten in another
  console). `claimlint-2026-07-28.md` §11 records that volatility.
- **Two additive columns, `narrowed` and `wrong-answer-pass-rate`,** are defined
  in §1 and populated per `claimlint-2026-07-28.md` §5–§6. New rows must carry
  both (`0`/`?` is an acceptable honest default) or the linter will refuse the
  row.
- **Choosing an edge kind (§1) is a real decision, not bookkeeping.** Ask: *if
  the parent turned out true, would this claim be wrong?* If yes, `d:`. *If the
  parent turned out true, would this claim lose its reason to exist?* If yes,
  `n:`. If it would merely become untested, `e:`. **If you cannot tell, write
  `d:` and say so in the cell** — a false orphan is visible and cheap; a hidden
  one is what cost the project weeks. `GLOBAL.H5c` is left `d:` on exactly
  those grounds.
- **A `FALSE` status is not the end of a row's life.** Check its `n:`
  dependents before rehabilitating it: they were adopted because it fell, and
  C1b will alarm on every one.
- **When you cite a measurement as a dependency, ask what it measures.** "The
  run completed" is `e:`. "The method is correct" is a different claim, usually
  has its own row, and is the `d:` parent you actually meant. C5 reports the
  ones that got this wrong; `3x3.C1` was one for a day and it hid the sharpest
  orphan in the register.
- **A row whose claim text joins two independently-falsifiable assertions with
  "and" is a latent version of the conjoined-row defect.** The register cannot
  lint for this today (it is prose, not a structured column), but
  `CLAIMS-SPLIT-CONJUNCTS` (2026-07-29) split `GLOBAL.H1`, `GLOBAL.ONEMISMATCH`,
  and their QA aliases into separate rows. When a conjoined row is spotted:
  split it, re-point the inbound edges at whichever half each dependent actually
  needs, confirm no row is left depending on the retired conjoined ID, and add
  the split date and task name to every new row. If the `knowledge-ladder.md`
  **rung + rule** columns are ever ratified, this class becomes
  machine-checkable.
- **Do not resolve §5 or §6 in this file.** Resolutions belong in an ADR
  (append-only) or in the owning goban's `EPISTEMIC.md`; this file then updates
  the status and cites the resolution.
