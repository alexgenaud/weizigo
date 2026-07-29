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
**D-5** (→ ADR-0015), plus EXP-3's measured per-board census. Every status this
changed cites the ruling or the run that changed it, in the row:
`QA-009` UNTESTED → FALSE (D-1), `GLOBAL.H1-CENSUS` UNTESTED → PROVEN (EXP-3),
`3x3.H1-CENSUS` / `4x3.H1-CENSUS` new and PROVEN (EXP-3), `QA-015` decided
(D-2). **No status was changed on this file's own authority, and none was
changed to improve a linter counter.** Where a promotion needed a judgement
nobody had made, it was left undone and named: see §5's note on `mixed`, §6-D18,
and `GLOBAL.F2`, which stays CLAIMED-and-orphaned because ADR-0015 refutes an
*argument* and does not falsify the finisher.

Conventions inherited from `AGENTS.md`: epistemic tags on every claim; absolute
dates; every number cites its run; per-board epistemic independence; scores are
Black-positive; the board index is a **colex index**, never a "rank".

---

## 1. ID scheme

    <SCOPE>.<LEGACY-ID>

**SCOPE** is one of:

| scope | meaning |
|---|---|
| `GLOBAL` | size-generic: a definition, a mathematical theorem, a project foreclosure, or a claim the documents state without board scope |
| `CODE` | a claim about the *implementation* (a source file, a guard, a format), not about a board. Kept distinct from `GLOBAL` because the inheritance audit (§5) turns on exactly this distinction |
| `2x2` `3x2` `3x3` `4x3` `4x4` `5x4` `5x5` | the board size the claim is scoped to |

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
  project*, not of a board; where a QA claim is board-scoped its `board` column
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
is orphaned via `GLOBAL.C3`, falsified at 3×3, the very board. The measurement
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

**253 rows** (217 at the 2026-07-28 sweep + the 28 `QA-nnn` rows imported into
§2.11 the same day + **8 added later on 2026-07-28** promoting rulings D-1, D-2,
D-3, D-5 and EXP-3's per-board census: `3x3.E2-RUN1`, `3x3.E2-RUN2`,
`3x3.H1-CENSUS`, `4x3.H1-CENSUS`, `GLOBAL.H5a-CHILD`, `GLOBAL.H5a-FALLBACK`,
`GLOBAL.ADR0016-INHERIT`, `GLOBAL.ADR0015-BURDEN`). Grouped by family for
readability; the column set is identical throughout. (Row count and all edge
counts in §3 are printed by `bin/weizigo-claimlint` on every run — that print is
authoritative, this prose is a snapshot of it.)

### 2.1 Structural (S) — is the engine correct?

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.S1` | S1 | all | The colex mixed-radix index is a collision-free bijection over the 3^(w·h) board space | PROVEN | `4x4/EPISTEMIC.md:17`; `4x3/EPISTEMIC.md:24` | — | `4x4.S1`, `4x3.S1`, `CODE.ADR0011-FMT`, every artifact address | 0 | ~0% |
| `4x4.S1` | S1 | 4×4 | Colex bijection verified by exhaustive round-trip through 4×4 | PROVEN | `4x4/EPISTEMIC.md:17` | `e:GLOBAL.S1` | `4x4.C1`, `4x4` artifact | 0 | ~0% |
| `4x3.S1` | S1 | 4×3 | Colex bijection holds at 4×3 | PROVEN | `4x3/EPISTEMIC.md:24` | `d:GLOBAL.S1` (inherited from the 4×4 round-trip — see §5-I7) | `4x3.C1`, `4x3` artifact | 0 | ? |
| `GLOBAL.S2` | S2 | all | Benson's unconditional-life theorem holds on every finite board | PROVEN | `CONCEPTS.md:10-12`; `4x3/EPISTEMIC.md:25` | — | `GLOBAL.ADR0004-TERM`, all `S2-impl` rows, `GLOBAL.ADR0006-EYE` | 0 | ? |
| `3x3.S2-impl` | S2 | 3×3 | The `rules.zig` Benson implementation is exhaustively falsification-confirmed at 3×3 | PROVEN | `PROGRESS.md:203` | `e:GLOBAL.S2` | `3x3.C1` | 0 | ? |
| `4x4.S2-impl` | S2 | 4×4 | The `rules.zig` Benson implementation does not regress in a size-dependent way at 4×4 | UNTESTED | `4x4/EPISTEMIC.md:158-167` | `e:GLOBAL.S2` | `4x4.C1`, `4x4.M1`, `4x4` terminal detection | 0 | ? |
| `4x3.S2-impl` | S2-impl | 4×3 | The `rules.zig` Benson implementation is correct at 4×3 | UNTESTED | `4x3/EPISTEMIC.md:26` | `e:GLOBAL.S2` | `4x3.C1` | 0 | ? |
| `4x3.S2` | S2 | 4×3 | Benson-alive theorem holds at 4×3 | PROVEN | `4x3/EPISTEMIC.md:25` | `d:GLOBAL.S2` | `4x3.C1` | 0 | ? |
| `GLOBAL.S3a` | S3a | all | The move/capture/suicide kernel is correct; OEIS A094777 attests the legal-position count and nothing more | PROVEN (as scoped) | `CONCEPTS.md:14-16`; `4x4/EPISTEMIC.md:18-22` | — | `4x4.S3a`, `4x3.S3a` | 1 | ? |
| `4x4.S3a` | S3a | 4×4 | 24,318,165 legal positions/side at 4×4 = OEIS A094777, cross-validated | PROVEN | `4x4/EPISTEMIC.md:18-22`; `retrograde-4x4.md:20,28` | `e:GLOBAL.S3a`, `e:4x4.S1` | `4x4.C1`, `4x4.M1` | 0 | <0.01% |
| `4x3.S3a` | S3a | 4×3 | `legal_count = 321,689` at 4×3 = OEIS A094777 | PROVEN | `4x3/EPISTEMIC.md:27` | `e:GLOBAL.S3a` | `4x3.C1` | 0 | <0.1% |
| `GLOBAL.S3b` | S3b | all | Ko-legality under history is a separate sub-claim from S3a; it is the structural reason R1 holds | CLAIMED | `CONCEPTS.md:17-21` | — | `4x4.S3b`, `4x3.S3b`, `GLOBAL.R1` | 0 | ? |
| `4x4.S3b` | S3b | 4×4 | Ko-legality under PSK history is implemented correctly at 4×4 | UNTESTED | `4x4/EPISTEMIC.md:135-140` | `d:GLOBAL.S3b` | `4x4.R1`, `4x4.C1`, `4x4.C2`, `4x4.C3`, `4x4.M1` | 0 | ? |
| `4x3.S3b` | S3b | 4×3 | Ko-legality under PSK history is implemented correctly at 4×3 | UNTESTED | `4x3/EPISTEMIC.md:28` | `d:GLOBAL.S3b` | `4x3.C1`, `4x3.M1` | 0 | ? |
| `GLOBAL.S4` | S4 | all | Area (Chinese) scoring is implemented correctly; the score is a pure function of the terminal snapshot | PROVEN | `CONCEPTS.md:20-21`; `0003:13-16` | — | every terminal score; `GLOBAL.ADR0004-TERM`; `GLOBAL.ADR0006-EYE` | 0 | ? |
| `4x4.S4` | S4 | 4×4 | Area scoring correct at 4×4 | UNTESTED (`⬜ᴵᴺᴴ`) | `4x4/EPISTEMIC.md:31-36` | `d:GLOBAL.S4` (self-declared inheritance) | `4x4.C1`, `4x4.M1` | 0 | ? |
| `4x3.S4` | S4 | 4×3 | Area scoring correct at 4×3 | UNTESTED (`⬜ᴵᴺᴴ`) | `4x3/EPISTEMIC.md:29` | `d:GLOBAL.S4` (self-declared inheritance) | `4x3.C1` | 0 | ? |
| `CODE.S4-XVAL` | — | n/a | `rules.zig` cross-validated: 500 random boards vs `terminal.zig`, 1000 random moves vs `state.armies_from_move`, all equal | MEASUREMENT | `0008:63-66` | — | `GLOBAL.S4`, `GLOBAL.S3a` | 0 | ? |

### 2.2 Fixpoint (FP) — is the table a genuine fixpoint?

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.FP1` | FP1 | all | L is the least and H the greatest fixpoint of the Bellman map (Knaster–Tarski, monotone map, seeded from `−N`/`+N`) | PROVEN (as mathematics) | `CONCEPTS.md:25-30`; `0009:53-61` | `d:GLOBAL.FP3` | all `FP1` rows, `GLOBAL.C3`, `GLOBAL.BRACKET` | 0 | ? |
| `2x2.B1` | B1 | 2×2 | Canonical `lo` is the true least fixpoint at 2×2 (V0+V1 hold, zero violations; monotone from `−N`) | CLAIMED | `leak-crisis.md:86-101`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** | `e:GLOBAL.FP1` | `2x2.C3` | 0 | ? |
| `3x2.B1` | B1 | 3×2 | Canonical `lo` is the true least fixpoint at 3×2 | CLAIMED | `leak-crisis.md:86-101`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** | `e:GLOBAL.FP1` | `3x2.C3` | 0 | ? |
| `3x3.B1` | B1 | 3×3 | Canonical `lo` is the true least fixpoint at 3×3 → failure mode (b) ruled out for E2 | CLAIMED | `leak-crisis.md:56-61,86-101`; `4x4/EPISTEMIC.md:60-62`. **No durable evidence file — primary evidence (`untracked/T02-minimax.md`) lost; only a prose summary survives. Downgraded PROVEN→CLAIMED 2026-07-29 (evidence-integrity sweep).** | `e:GLOBAL.FP1` | `3x3.C3`, `GLOBAL.E2-VERDICT` | 0 | ? |
| `GLOBAL.B1-MULTIFIX` | B1 (a′) | 2×2/3×2/3×3 | The L map has multiple fixpoints (Gauss–Seidel reads oppV0 in-sweep); re-converge from `+N` lands above canonical | MEASUREMENT | `leak-crisis.md:93-99` | `e:2x2.B1`, `e:3x2.B1`, `e:3x3.B1` | `4x4.FP1` (the check *dropped* from acceptance) | 0 | ? |
| `GLOBAL.B1-AUDIT` | (a′) | all | The re-converge-from-`+N` check is a multi-fixpointedness observation, **not** a least-ness witness; the prior (a′) conclusion was unsound | PROVEN | `leak-crisis.md:99-101`; `4x4/EPISTEMIC.md:90-97`; `CONCEPTS.md:29-30` | `d:GLOBAL.FP1` | `4x4.FP1` acceptance set | 0 | ? |
| `4x4.FP1` | FP1 | 4×4 | L/H at 4×4 are the least/greatest fixpoints — three-check acceptance (seed, zero-change, V0/V1) | UNTESTED (checks 1–2); check 3 PASSES | `4x4/EPISTEMIC.md:69-97` | `d:GLOBAL.FP1`, `e:4x4.M4` (check 3), `e:4x4.M2` | `4x4.C3`, `4x4.F2`, `4x4.BRACKET`, `4x4.C1` | 0 | ? |
| `4x4.FP1-C1` | FP1 check 1 | 4×4 | `converge` was seeded from `−N` (L) and `+N` (H) at 4×4, per build logs | UNTESTED | `4x4/EPISTEMIC.md:71-73` | — | `4x4.FP1` | 0 | ? |
| `4x4.FP1-C2` | FP1 check 2 | 4×4 | The final L-sweep and H-sweep each hit zero change at 4×4 | UNTESTED | `4x4/EPISTEMIC.md:74-75` | `e:4x4.M2` | `4x4.FP1` | 0 | ? |
| `4x4.FP1-C3` | FP1 check 3 | 4×4 | V0/V1 Bellman identities hold at every non-settled slot — **PASSES** on `vb`/`vw`, 1:37 sample | PROVEN (as scoped) | `4x4/EPISTEMIC.md:76-88`; `ko-sensitive-chainability.md:60-69` | `e:4x4.M4` | `4x4.FP1`, `GLOBAL.H4` | 1 | ? |
| `4x3.FP1` | FP1 | 4×3 | L/H at 4×3 are the least/greatest fixpoints | CLAIMED | `4x3/EPISTEMIC.md:30` | `d:GLOBAL.FP1` | `4x3.C1`, `4x3.BRACKET` | 0 | ? |
| `GLOBAL.FP2` | FP2 | all | Where L==H the score is history-independent — **ADR-0009 honesty clause, explicitly NOT a theorem** | CLAIMED | `CONCEPTS.md:31-32`; `0009:65-67,78-89` | `d:GLOBAL.FP1` | `GLOBAL.C2`, `GLOBAL.C3`, `GLOBAL.CERTCORE`, `GLOBAL.F2` | 1 | ? |
| `GLOBAL.FP2-bounded` | FP2-bounded / C2-bounded | all | History-independence under a finite, well-specified set of ban sets | FALSE-AS-SCOPED (at 3×2) | `CONCEPTS.md:33-37` | `d:GLOBAL.FP2` | `GLOBAL.C2`, deliverable option 1/2 | 2 | ? |
| `GLOBAL.FP2-general` | FP2-general / C2-general | all | History-independence under *any* past or future repetition | INTRACTABLE (possibly unprovable by finite methods) | `CONCEPTS.md:38-42`; `4x4/EPISTEMIC.md:148-157` | `d:GLOBAL.FP2` | research only; explicitly not a deliverable input | 0 | ? |
| `GLOBAL.FP3` | FP3 | all | Bellman iteration terminates in finitely many sweeps (monotone map on a finite lattice) | PROVEN | `CONCEPTS.md:43-46`; `4x3/EPISTEMIC.md:31` | — | `GLOBAL.FP1`, all `FP3` rows | 0 | ? |
| `4x4.FP3` | FP3 | 4×4 | Finite-sweep convergence at 4×4 | UNTESTED (`⬜ᴵᴺᴴ`) | `4x4/EPISTEMIC.md:37-43` | `d:GLOBAL.FP3` (self-declared inheritance) | `4x4.FP1` | 0 | ? |
| `4x3.FP3` | FP3 | 4×3 | Finite-sweep convergence at 4×3 | PROVEN | `4x3/EPISTEMIC.md:31` | `d:GLOBAL.FP3` | `4x3.FP1` | 0 | ? |
| `GLOBAL.CERTCORE` | — | all | Where L==H the score "cannot depend on any cycle rule … equals the mid-game score under ANY ban set" — the ADR-0009 *certification* decision | FALSE-AS-SCOPED | `0009:65-67` | `d:GLOBAL.FP2` | `GLOBAL.F2`, `GLOBAL.ADR0010-CUT`, the retired "certified core" framing | 2 | ? |
| `GLOBAL.ADR0009-HONESTY` | — | all | The certification argument has one unproven step (the memoryless-strategy leak); `L ≤ fresh-start ≤ H` and `L==H ⇒ exact` are strong structural evidence, not a theorem | PROVEN (as a statement about the argument) | `0009:78-89` | — | `GLOBAL.CERTCORE`, `GLOBAL.C3`, `GLOBAL.ADR0010-SOUND` | 0 | ? |
| `GLOBAL.INVSYM` | — | all | Colour inversion: `value(−pos,−side) == −value(pos,side)`; for bound tables `L(−pos,−side) == −H(pos,side)`; dihedral transforms never change score or sign | PROVEN | `0009:102-107,148-157`; `0008:48-51,54-60`; `AGENTS.md:75-77` | — | `GLOBAL.P2`, all symmetry batteries, orbit propagation | 0 | ? |

### 2.3 Value-correctness (C) — the crisis claims

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.C1` | C1 | all | Fresh-start scores are correct *as fresh-start scores* | — (definition) | `CONCEPTS.md:50-53`; `leak-crisis.md:24` | — | all `C1` rows; the entire adopted deliverable | 0 | ? |
| `2x2.C1` | C1 | 2×2 | Fresh-start scores correct at 2×2 vs the history-aware exact solver | PROVEN | `leak-crisis.md:24`; `PROGRESS.md:126` | `e:2x2.EXACT`, `e:GLOBAL.ADR0006-EYE` | `2x2.C4`, arena baseline, `GLOBAL.C1-CALIB` | 0 | ? |
| `3x2.C1` | C1 | 3×2 | Fresh-start scores correct at 3×2 vs the history-aware exact solver | PROVEN | `leak-crisis.md:24`; `c2-falsification-3x2.md:56-57` (0/540 L==H fresh-start mismatches) | `e:3x2.EXACT`, `e:GLOBAL.ADR0006-EYE` | `3x2.C4`, `3x2.T13`, arena baseline | 0 | ? |
| `3x3.C1` | C1 | 3×3 | Fresh-start scores correct at 3×3 | CLAIMED | `PROGRESS.md:210` | `d:GLOBAL.F2` (the *soundness* behind `3x3.F2`; completion is not soundness — §4.1-O3), `e:3x3.F2`, `e:3x3.ANCHOR`, `e:GLOBAL.INVSYM` | `3x3.C3`, 3×3 artifact | 0 | ? |
| `4x3.C1` | C1 | 4×3 | Fresh-start scores correct at 4×3 | CLAIMED | `4x3/EPISTEMIC.md:32` | `d:4x3.F2`, `d:GLOBAL.F1` (same buggy finisher path), `e:4x3.ANCHOR`, `e:GLOBAL.INVSYM` | 4×3 artifact, `4x3.M1` | 0 | ? |
| `4x4.C1` | C1 | 4×4 | Fresh-start scores correct at 4×4 — "SUPPORTED, not PROVEN"; no exhaustive ground truth exists | UNTESTED | `4x4/EPISTEMIC.md:141-147`; `PROGRESS.md:210-211` | `d:4x4.F2`, `d:GLOBAL.F1`, `e:4x4.ANCHOR`, `e:GLOBAL.INVSYM`, `e:4x4.S3a` | the whole 4×4 deliverable, `4x4.M4`, `4x4.M6`, GTP player | ? | ? |
| `GLOBAL.C2` | C2 | all | Single-score (L==H) positions are history-independent | FALSE-AS-SCOPED (at 3×2) | `leak-crisis.md:25`; `PROGRESS.md:127`; `AGENTS.md:68-73` | `d:GLOBAL.FP2-bounded` | `GLOBAL.C4`, `GLOBAL.CERTCORE`, deliverable options 1/2, `4x4.M4` interpretation | 2 | ? |
| `2x2.T12` | T12 | 2×2 | C2-pilot at 2×2 is **tautological** — 2×2 admits no reachable non-root cycles | MEASUREMENT | `4x4/EPISTEMIC.md:255-257,287-288` | `e:2x2.EXACT` | `3x2.T13` design calibration | 0 | ? |
| `3x2.T13` | T13 | 3×2 | C2 falsified at 3×2: 12 verified mismatches on 508 non-trivial reachable PSK histories over L==H slots (0/540 fresh-start sanity mismatches) | PROVEN (falsification) | `c2-falsification-3x2.md:15-16,45-95`; `leak-crisis.md:106-121`. **⚠ CANNOT REPRODUCE — probe source (`untracked/c2pilot_3x2.zig`) and raw output (`untracked/T13-minimax.md`) are lost. The durable summary at `docs/research/c2-falsification-3x2.md` preserves the numbers and method, so the claim stands; the reproduction block cannot be executed. 2026-07-29 evidence-integrity sweep.** | `e:3x2.C1`, `e:3x2.EXACT` | `GLOBAL.C2`, `GLOBAL.C4`, `4x4.C2`, `GLOBAL.REFRAME`, `GLOBAL.H1` | 0 | ? |
| `3x3.C2` | C2 | 3×3 | C2 at 3×3 | UNTESTED | `PROGRESS.md:212-213` | `d:GLOBAL.FP2-bounded` | 3×3 real-game claims | 0 | ? |
| `4x3.C2` | C2 | 4×3 | C2 at 4×3 — explicitly *not* inherited from the 3×2 falsification | UNTESTED | `4x3/EPISTEMIC.md:33` | `d:GLOBAL.FP2-bounded` | 4×3 real-game claims | 0 | ? |
| `4x4.C2` | C2 / FP2 | 4×4 | C2 at 4×4 — "falsification is analogy-expected, not an open hypothesis" | UNTESTED (status conflict, §6-D3) | `4x4/EPISTEMIC.md:46,98-110`; `PROGRESS.md:212-213`; `arena-4x4-undef.md:87-91` | `d:GLOBAL.FP2-bounded`, `e:3x2.T13` (inherited — §5-I10), `e:4x4.ARENA-DIV` | 4×4 deliverable decision | 0 | ? |
| `GLOBAL.C3` | C3 | all | The bracket `[L,H]` bounds the real-game score for any history, any cycle rule in `[−n,n]` | FALSE-AS-SCOPED (at 3×3) | `leak-crisis.md:26`; `PROGRESS.md:128`; `CONCEPTS.md:57-61` | `d:GLOBAL.FP2`, `d:GLOBAL.ADR0009-HONESTY` | `GLOBAL.ADR0010-CUT`, `GLOBAL.F2`, all `F2` rows, `GLOBAL.H5c`, every artifact's ko-sensitive column | 2 | ? |
| `2x2.C3` | C3 | 2×2 | Range-aware player leak-free at 2×2 (0/4000 games) | MEASUREMENT | `leak-crisis.md:72` | `e:2x2.B1` | `GLOBAL.C3` support | 0 | ? |
| `3x2.C3` | C3 | 3×2 | Range-aware player leak-free at 3×2 (0/4000 games) | MEASUREMENT | `leak-crisis.md:73` | `e:3x2.B1` | `GLOBAL.C3` support | 0 | ? |
| `3x3.C3` | C3 / E2 | 3×3 | C3 falsified at 3×3: range-aware self-play leaked (promise +3 → final −9, 12-pt leak) | PROVEN (falsification) | `leak-crisis.md:36,74-79`; `4x4/EPISTEMIC.md:55-66` | `e:3x3.B1`, `e:3x3.E3`, `e:3x3.E2-RUN1`, `e:3x3.E2-RUN2` | `GLOBAL.C3`, `4x4.C3`, `GLOBAL.H5c` | 0 | ? |
| `4x3.C3` | C3 | 4×3 | C3 at 4×3 — explicitly *not* inherited from the 3×3 falsification | UNTESTED | `4x3/EPISTEMIC.md:34` | `d:GLOBAL.C3` | 4×3 bracket claims | 0 | ? |
| `4x4.C3` | C3 | 4×4 | C3 at 4×4 — "analogy-expected falsified, NOT an open hypothesis"; a 4×4 run would be characterisation only | UNTESTED (status conflict, §6-D2) | `4x4/EPISTEMIC.md:55-66` | `d:GLOBAL.C3`, `e:3x3.C3` (inherited — §5-I9) | 4×4 deliverable decision | 0 | ? |
| `GLOBAL.C4` | C4 | all | Fresh-start score == real-game score | FALSE-AS-SCOPED | `leak-crisis.md:27`; `PROGRESS.md:129`; `4x4/EPISTEMIC.md:26` | `d:GLOBAL.C2` (single-score half), `d:GLOBAL.P3` (ko-sensitive half) | `GLOBAL.REFRAME`, `4x4.A-2`, GTP player defect | 0 | ? |
| `GLOBAL.LEAK` | — | all | The fresh-start player leaks on real-game PSK histories; "leak" = final score short of the strongest promise made in that game | PROVEN | `leak-crisis.md:9-14`; `PROGRESS.md:110-121` | `n:GLOBAL.C4` | `GLOBAL.P3`, `4x4.B43` | 0 | ? |
| `GLOBAL.E1` | E1 | 2×2/3×2 | E1 as first written was **confounded** — it read the fresh-start child's fresh-start score, so it diagnoses where the plan breaks, it does not falsify C2 | PROVEN (methodological) | `leak-crisis.md:164-168` | — | `3x2.T13` (the replacement experiment) | 0 | ? |
| `3x3.E3` | E3 | 3×3 | The 3×3 leaking game is a VALID PSK game (0 illegal moves in 17 plies) — failure mode (c) ruled out | PROVEN | `leak-crisis.md:54-55` | — | `3x3.C3` | 0 | ? |
| `GLOBAL.E2-SANITY` | E2 sanity | 2×2/3×2/3×3 | With trivial bounds (`lo=−N, hi=+N`) the same range-aware policy is leak-free everywhere → the E2 harness is wired correctly | PROVEN | `leak-crisis.md:48-52` | — | `3x3.C3` | 0 | ? |
| `GLOBAL.E2-POLICY` | E2 | all | Correct range-aware policy: Black maximizes `lo[child]`, White minimizes `hi[child]`; the first run used `lo` for both and was wrong | PROVEN (bug + fix) | `leak-crisis.md:81-83` | `d:GLOBAL.INVSYM` | `3x3.C3` validity | 0 | ? |
| `GLOBAL.E2-VERDICT` | (a) | 3×3 | Survivor hypothesis: C3 is genuinely false because `lo` pessimises cycle *resolutions* while PSK *removes* the move — a structural reason, not an implementation accident | CLAIMED | `leak-crisis.md:38-42,66,172-175` | `d:3x3.B1`, `d:3x3.E3`, `d:GLOBAL.E2-SANITY` | `GLOBAL.C3`, `4x4.C3` analogy argument | 0 | ? |
| `3x3.E2-RUN1` | — | 3×3 | **E2 run 1 (original).** Range-aware self-play at 3×3 leaked **25 of 4,000 games** = 0.625%; worst leak **12 pts** (promise +3 → final −9). Denominator = games played. Added 2026-07-28 promoting ruling **D-1** | MEASUREMENT | `leak-crisis.md:36,74`; `4x4/EPISTEMIC.md:58`; `open-hypotheses:289` | `e:GLOBAL.E2-POLICY`, `e:GLOBAL.E2-SANITY` | `3x3.C3`, `QA-009`, §6-D1 | 0 | ? |
| `3x3.E2-RUN2` | — | 3×3 | **E2 run 2 (B06 re-run).** Range-aware self-play at 3×3 leaked **50 of 8,000 games** = 0.625%; worst leak **12 pts**. **An independent replication of run 1, not a double-count of it** — ruled 2026-07-28 (D-1, Opus). Kept as a separate row deliberately: collapsing the two into one destroys the replication, which is the evidence | MEASUREMENT | `PROGRESS.md:128`; the D-1 ruling, recorded in §6-D1 of this file. **No run log is committed** — the 8,000-game output exists nowhere in git, so this row is C3-class debt: the number survives, the run does not | `e:GLOBAL.E2-POLICY`, `e:GLOBAL.E2-SANITY` | `3x3.C3`, `QA-009`, §6-D1 | 0 | ? |

### 2.4 Finisher / engine (F)

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.ADR0005-CACHE` | — | all | Cacheability "theorem": a node at ply `d` is cacheable iff `ko_ref ≥ d` | FALSE-AS-SCOPED | `0005:90-93`; downgraded `0008:32-38`; falsified `0013:20-44` | — | `GLOBAL.F1`, every pre-2026-07-23 artifact | 1 | ? |
| `GLOBAL.ADR0008-HOLE` | — | all | The `ko_ref ≥ d` rule is "a sound-in-practice compromise, not a theorem" — explicit retraction of ADR-0005's proof claim | PROVEN (as a statement about the argument) | `0008:32-38` | `n:GLOBAL.ADR0005-CACHE` | `GLOBAL.F1`, `CODE.ADR0011-FMT` caveat | 0 | ? |
| `GLOBAL.F1` | F1 | all | The writes-on finisher (`ko_ref ≥ d` cross-branch memo guard) is sound | FALSE-AS-SCOPED | `0013:20-44`; `consistency-audit.md:25-34`; `CONCEPTS.md:109` | `d:GLOBAL.ADR0005-CACHE` | `3x2.C1` regen, `3x3.C1`, `4x3.C1`, `4x4.C1`, `4x4.M6`, every committed ko-sensitive column | 1 | ? |
| `3x2.F1` | F1 | 3×2 | Writes-on finisher unsound at 3×2: **45 of 378** ko-sensitive slots violate the minimax identity; writes-off gives **0** | PROVEN (falsification) | `consistency-audit.md:25-34`; `0013:15-19`; `4x4/EPISTEMIC.md:49-52` | `e:GLOBAL.AUDITOR` | `GLOBAL.F1`, `4x4.F1`, `4x3.F1`, `4x4.M6` reading 2 | 0 | ? |
| `4x4.F1` | F1 | 4×4 | Writes-on finisher unsound at 4×4 — "the guard is the same code; the bug is structural, not size-dependent"; the 4×4 auditor sample did not finish | CLAIMED | `4x4/EPISTEMIC.md:27-28,49-52` | `n:GLOBAL.F1` (this row asserts the finisher is UNsound — §4.1-O10), `e:3x2.F1` (inherited — §5-I1) | `4x4.C1`, `4x4.M6`, committed 4×4 ko-sensitive column | 0 | ? |
| `4x3.F1` | F1 | 4×3 | The committed 4×3 artifact was produced by the same unsound writes-on path | CLAIMED | `4x3/EPISTEMIC.md:35,48-50` | `n:GLOBAL.F1` (asserts UNsoundness — §4.1-O10), `e:3x2.F1` (inherited — §5-I2) | `4x3.C1` | 0 | ? |
| `GLOBAL.F2` | F2 | all | The bracket-guided finisher (ADR-0010) is sound. **Orphan confirmed 2026-07-28 (D-5 → ADR-0015): the fresh-start-root defence fails and the burden on ADR-0010 is undischarged. Status left CLAIMED — the ruling refutes the *justification*, it does not falsify the finisher** | CLAIMED | `CONCEPTS.md:110-112`; `0010:14-38,70-81`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` | `d:GLOBAL.C3`, `d:GLOBAL.ADR0009-HONESTY`, `d:GLOBAL.ADR0006-EYE` | all `C1` rows for finisher-produced slots; all shipped ko-sensitive values | 1 | ? |
| `GLOBAL.ADR0010-CUT` | — | all | Bracket cutoffs "are valid under any ban set (the bracket is)", so they fire deep inside the ko-tangled opening. **ADR-0015 (2026-07-28) supersedes the justification: only the cutoff (ADR-0010 item 1) needs the premise — bracket move ordering and the aspiration window survive as heuristics** | CLAIMED | `0010:29-30,16-18`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` | `d:GLOBAL.C3` | `GLOBAL.F2`, `GLOBAL.H5c`, finisher tractability | 0 | ? |
| `GLOBAL.ADR0010-SOUND` | — | all | ADR-0010's bracket claim inherits ADR-0009's honesty clause and is closed empirically, not proved | PROVEN (as a statement about the argument) | `0010:70-81` | `d:GLOBAL.ADR0009-HONESTY` | `GLOBAL.F2` | 0 | ? |
| `2x2.F2` | F2 | 2×2 | Plain and bracketed finishers agree slot-for-slot at 2×2 (0 diffs, both sides) | MEASUREMENT | `retrograde-3x3.md:197-203` | `e:GLOBAL.INVSYM` | `GLOBAL.F2` support | 0 | ? |
| `3x3.F2` | F2 | 3×3 | Bracket-guided finisher completes all 622 ko-sensitive orbit reps at 3×3; anchors PIN and MATCH | MEASUREMENT | `retrograde-3x3.md:181-196` | `e:3x3.B1`, `e:3x3.ANCHOR` | `3x3.C1` | 0 | ? |
| `4x3.F2` | F2/F3 | 4×3 | Writes-off finisher sound at 4×3 | UNTESTED | `4x3/EPISTEMIC.md:36` | `d:GLOBAL.F2` | `4x3.C1` | 0 | ? |
| `4x4.F2` | F2 | 4×4 | Bracket-guided finisher sound at 4×4 — needs auditor + bracket containment **on a writes-off regen** | UNTESTED | `4x4/EPISTEMIC.md:127-132` | `d:GLOBAL.F2`, `d:GLOBAL.C3`, `d:4x4.D3`, `e:4x4.M6` | `4x4.C1`, artifact promotion, 4×4 deliverable | 0 | ? |
| `GLOBAL.F3` | F3 | all | The writes-off (`memo_writes=false`, "soundish") finisher is sound; its correctness rests on exactly three invariants — bracket validity, eye-prune soundness, history-free certified seeds | CLAIMED | `0013:50-65`; `consistency-audit.md:42-51` | `d:GLOBAL.C3`, `d:GLOBAL.ADR0006-EYE`, `d:GLOBAL.CERTCORE` | all `F3` rows, Track A, artifact promotion | 1 | ? |
| `3x2.F3` | F3 | 3×2 | Writes-off finisher self-consistent at 3×2: 0 of 378 violations | PROVEN (necessary condition) | `consistency-audit.md:30`; `0013:15-19` | `e:GLOBAL.AUDITOR` | `GLOBAL.F3`, `3x2.C1` | 0 | ? |
| `4x4.F3` | F3 | 4×4 | Writes-off finisher self-consistent at 4×4 (stratified sample) | UNTESTED | `4x4/EPISTEMIC.md:111-126` | `d:GLOBAL.F3`, `d:4x4.D3`, `e:4x4.M6` | `4x4.C1`, `4x4.F4`, artifact promotion, `4x4.M6` reading 2 | 0 | ? |
| `GLOBAL.F4` | F4 | all | The Kishimoto–Müller dependency-guarded memo (Bloom fingerprint, `deps` mode) restores *sound* cross-branch reuse; bit-disjointness proves safety, false positives only forgo reuse | PROVEN (argument) + MEASUREMENT | `0013:67-116` | `d:GLOBAL.F3` | all `F4` rows, the 5×N scaling route | 0 | ? |
| `3x2.F4` | F4 | 3×2 | `deps` mode validated at 3×2 | PROVEN | `0013:88-91` (3×2/3×3/4×3 group) | `e:GLOBAL.AUDITOR` | `GLOBAL.F4` | 0 | ? |
| `3x3.F4` | F4 | 3×3 | `deps` mode: 0 auditor violations and byte-identical to writes-off at 3×3 | PROVEN | `0013:88-91` | `e:GLOBAL.AUDITOR` | `GLOBAL.F4` | 0 | ? |
| `4x3.F4` | F4 | 4×3 | `deps` mode: 0 auditor violations and byte-identical to writes-off at 4×3 | PROVEN | `0013:88-91` | `e:GLOBAL.AUDITOR` | `GLOBAL.F4` | 0 | ? |
| `4x4.F4` | F4 | 4×4 | KM dependency-guarded memo correct at 4×4 — needs KM regen + byte-compare to the writes-off regen | UNTESTED | `4x4/EPISTEMIC.md:168-174` | `d:GLOBAL.F4`, `d:4x4.F3`, `d:4x4.D3` | 5×N scaling, 4×4 artifact promotion | 0 | ? |
| `GLOBAL.F4-COST` | — | 3×3/4×3 | Fingerprint width buys reuse; 64-bit saturates (≈0 reuse), 4096-bit recovers ~75% (3×3) / ~45% (4×3) of the gap. **The memory-for-reuse tradeoff is the central 5×N obstacle** | MEASUREMENT | `0013:92-108` | `e:GLOBAL.F4` | 5×5 feasibility | 0 | ? |
| `GLOBAL.AUDITOR` | #2 auditor | all | The `RETRO_CONSIST` self-consistency auditor is the standing pre-commit gate; passing is **necessary, not sufficient** (a solver can be self-consistent at a wrong fixpoint) | PROVEN | `consistency-audit.md:6-23`; `AGENTS.md:63-67`; `0013:117-122` | — | `3x2.F1`, `3x2.F3`, all `F4` rows, `4x4.M6` reading 2, `GLOBAL.H5` gate | 1 | ? |
| `GLOBAL.MEMO-XROOT` | Finding 2 | 2×2 | Cross-root memo reuse is order-dependent and **unsound**: at 2×2 it produced 116 dihedral-symmetry failures. NEVER share `ko_ref`-clean memo entries between roots | PROVEN (falsification) | `retrograde-3x3.md:23-37`; `0010:63-66` | `e:GLOBAL.INVSYM` | `GLOBAL.F1`, `GLOBAL.F2` design, `GLOBAL.ADR0010-CUT` | 0 | ? |
| `GLOBAL.ADR0006-EYE` | — | all | Forbidding a player from filling its own Benson-alive true eye does not change the game score (weak dominance under area scoring) | CLAIMED | `0006:27-49`; `AGENTS.md:83-84` | `d:GLOBAL.S2`, `d:GLOBAL.S4` | `GLOBAL.F2`, `GLOBAL.F3`, all `EXACT` rows, `3x2.T13`, `3x3.C3`, `4x4.M4` (eye-pruned move set) | ? | ? |
| `GLOBAL.ADR0006-TEST` | — | all | Any score disagreement between the eye-pruned forward searches and the full-move-set retrograde table would falsify ADR-0006 — the validation is a standing empirical test of it | PROVEN (as method) | `0009:118-123` | — | `GLOBAL.ADR0006-EYE` | 0 | ? |
| `GLOBAL.ADR0009-NOEYE` | — | all | The retrograde graph uses the FULL legal move set (no eye-prune); coverage is total, resolving ADR-0007's eye-prune-vs-coverage tension | PROVEN | `0009:109-124`; `AGENTS.md:83-84` | — | `4x4.M1`, table coverage | 0 | ? |
| `GLOBAL.ADR0007-TENSION` | — | all | ADR-0007 left eye-prune vs "score of every position" **unresolved and required-to-flag before persisting scores** | CLAIMED (open in ADR-0007; resolved by `GLOBAL.ADR0009-NOEYE`, never recorded as such in ADR-0007) | `0007:37-43` | — | see §6-D14 | 0 | ? |
| `GLOBAL.ADR0004-TERM` | — | all | Benson-terminal leaf scores are the true game score → depth-independent → the transposition table becomes legitimately shareable (removes failure mode P2) | PROVEN | `0004:16-19,31-34` | `d:GLOBAL.S2`, `d:GLOBAL.S4` | every terminal score, `GLOBAL.F3` | 0 | ? |
| `GLOBAL.ADR0004-P1` | — | all | Superko removes repetition (failure mode P1) and makes the game tree finite | PROVEN | `0004:20`; `0003:17-20` | — | `GLOBAL.R1`, termination of all searches | 0 | ? |
| `GLOBAL.ADR0005-SUBBOARD` | — | all | Restricting moves to a sub-region of the board is **unsound** (edge stones keep phantom liberties); search is full-board only | PROVEN | `0005:5-9`; `AGENTS.md:80-81` | — | full-board-only foreclosure | 0 | ? |
| `GLOBAL.ADR0005-DBLPASS` | — | all | Under optimal area play, at a double pass no dead stones remain, so `area_score` is exact (Tromp–Taylor) | CLAIMED (argued, not machine-checked) | `0005:61-63` | `d:GLOBAL.S4` | every terminal score | 0 | ? |
| `GLOBAL.ADR0005-PASS` | — | all | Passes are exempt from superko; pass is always available, so the "no children" case is subsumed | PROVEN | `0005:47-50` | — | Bellman equations `0009:20-22` | 0 | ? |
| `GLOBAL.ADR0003-AREA` | — | all | Area score is a pure function of the terminal snapshot; Japanese/territory score is path-dependent and NOT recoverable from a snapshot | PROVEN | `0003:13-16,21-24` | — | `GLOBAL.S4`, `GLOBAL.ADR0004-TERM`, `0014` scoring UI | 0 | ? |

### 2.5 Play (P) and the GTP player

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.P1` | P1 | all | An anchor match implies real-game correctness | FALSE-AS-SCOPED | `CONCEPTS.md:123`; `4x4/EPISTEMIC.md:24` | `d:GLOBAL.C4` | every "anchor validates the table" argument | 0 | ? |
| `GLOBAL.P2` | P2 | all | A symmetry PASS implies correctness — **necessary, not sufficient** | PROVEN (as scoped) | `CONCEPTS.md:124` | `d:GLOBAL.INVSYM` | every "validation summary all green" claim | 1 | ? |
| `GLOBAL.P3` | P3 | all | The fresh-start player plays the real-game score | FALSE-AS-SCOPED | `CONCEPTS.md:125`; `4x4/EPISTEMIC.md:25` | `d:GLOBAL.C4`, `e:GLOBAL.LEAK` | `GLOBAL.C4`, arena programme | 0 | ? |
| `4x4.P3` | P3 | 4×4 | The fresh-start player leaks 8–16% of games "even on proven-correct 2×2/3×2 tables" | MEASUREMENT | `4x4/EPISTEMIC.md:53-54` | `e:2x2.C1`, `e:3x2.C1` (inherited — §5-I13) | 4×4 arena expectations | 0 | ? |
| `GLOBAL.T06` | T06 | 2×2/3×2 | Arena baseline leak band is 8–18% on proven-correct fresh-start tables | MEASUREMENT | `PROGRESS.md:114-115` | `e:2x2.C1`, `e:3x2.C1` | `4x4.B43` interpretation (§6-D5) | 0 | ? |
| `4x4.B39` | B39 | 4×4 | Original 4×4 parallel-artifact arena audit: 45.3% leak rate, max 144 pts | FALSE-AS-SCOPED (measurement artifact) | `arena-4x4-undef.md:4-8,27-44` | — | superseded by `4x4.B43` | 0 | ? |
| `4x4.B43` | B43 | 4×4 | With the arena UNDEF-sentinel guard: **3.4% clean leak** (123/3600), max 32 pts; 1,170/3,600 (32.5%) games touch a UNDEF slot and are out of scope | MEASUREMENT | `arena-4x4-undef.md:57-91` | `e:CODE.UNDEF`, `e:4x4.PARALLEL` | `GLOBAL.H2`, `4x4.X2` | 0 | ? |
| `4x4.B43-DIV` | B43 | 4×4 | 176 single-score + 300 ko-sensitive **real** divergence events survive the guard (down 16× from 7,825 pre-fix) | MEASUREMENT | `arena-4x4-undef.md:87-91` | `e:4x4.B43` | `4x4.C2` corroboration claim | 0 | ? |
| `4x4.M5` | M5 | 4×4 | The empty 4×4 board is itself KO_SENSITIVE (bracket [−6,+16]) and **16 of 19 plies** in both saved regression games are flagged — the player *starts* in the unchainable region | PROVEN | `4x4/EPISTEMIC.md:199-205`; `ko-sensitive-chainability.md:126-140` | `e:4x4.M4`, `e:4x4.BRACKET` | `4x4.GTP-DEFECT`, `GLOBAL.H5a` weakness | 0 | ? |
| `4x4.KO-RULE-NULL` | Measurement 2 | 4×4 | Positional-superko bans changed the best available value at **0 of 19 plies** in both regression games (1 ban fired per game, at ply 14, never the best move) | PROVEN (these two games) | `ko-sensitive-chainability.md:102-118`; `4x4/EPISTEMIC.md:202-205` | — | `4x4.A-1`, `4x4.GTP-DEFECT` | 0 | ? |
| `4x4.GTP-DEFECT` | — | 4×4 | The GTP player's move rule (`Session.choose` extremum over stored child values) is **undefined where it mostly operates** at 4×4 | PROVEN | `PROGRESS.md:148-167`; `ko-sensitive-chainability.md:141-150` | `d:4x4.CHAIN-KO`, `e:4x4.M5`, `e:4x4.KO-RULE-NULL` | `GLOBAL.H5`, deliverable fork | 0 | ? |
| `4x4.GREEDY-BIAS` | — | 4×4 | The greedy extremum systematically selects the child whose false fresh-start premise is most flattering, so 3.4% is a **lower bound** on the greedy player's loss rate, not an estimate | CLAIMED | `PROGRESS.md:160-164`; `ko-sensitive-chainability.md:151-158` | `d:4x4.GTP-DEFECT`, `e:4x4.B43` | `GLOBAL.H2` | 0 | ? |
| `4x4.REGR-SYM` | Measurement 3 | 4×4 | The two 4×4 regressions are the same game up to the vertical mirror through ply 17; value traces identical | PROVEN | `ko-sensitive-chainability.md:121-124` | `e:GLOBAL.INVSYM` | `4x4.M5` sample size caveat | 0 | ? |
| `4x4.REGR-CLIFF` | Measurement 3 | 4×4 | Ply 16 collapse: stored −16 vs +16 one ply down — 32 points = 2n = the full board swing | MEASUREMENT | `ko-sensitive-chainability.md:126-140` | `e:4x4.M4` | `GLOBAL.MAXGAP` | 0 | ? |
| `CODE.UNDEF` | — | n/a | `−128` (UNDEF) must be treated as "no fresh-start belief", never as a real score, by both `src/gtp.zig` and `src/arena.zig` | PROVEN | `arena-4x4-undef.md:20-56`; `0011:30-35` | — | `4x4.B43`, `4x4.B39` retraction | 0 | ? |
| `4x4.B16-GAME` | — | 4×4 | First in-the-wild GHI divergence (2026-07-22): a human beat the oracle by 16 on 4×4; history-exact replay shows White was never doomed — W C1 at ply 14 was the game-losing blunder, a 32-point swing | MEASUREMENT | `retrograde-4x4.md:103-152` | `e:GLOBAL.C4` | `GLOBAL.C4`, `4x4.GTP-DEFECT` | 0 | ? |
| `4x4.HISTPERF-CHEAP` | — | 4×4 | A history-perfect genmove is "trivially affordable at 4×4" — history-exact solves took 65k nodes at ply 1, sub-1k from ply 7 | MEASUREMENT | `retrograde-4x4.md:147-151` | `e:GLOBAL.ADR0010-CUT` | `GLOBAL.H3` (contradicted — §6-D11) | 0 | ? |

### 2.6 Ruleset (R) — foreclosures

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.R1` | R1 | all | Exact PSK solving is intractable | PROVEN (structural) | `CONCEPTS.md:129`; `AGENTS.md:47-49`; `ruleset-options.md:95-97` | `d:GLOBAL.S3b`, `e:2x2.R1`, `e:3x2.R1` | `GLOBAL.REFRAME`, the whole retrograde design, `GLOBAL.H1` | 0 | ? |
| `2x2.R1` | R1 | 2×2 | PSK exact-solve on the EMPTY 2×2 exceeds a 200M-node budget at **118,475,182** ban-set states | MEASUREMENT | `ruleset-options.md:91,163`; `retrograde-3x3.md:44-49` | — | `GLOBAL.R1`, `4x4.R1` | 0 | ? |
| `3x2.R1` | R1 | 3×2 | PSK exact-solve on the empty 3×2: **116,114,272** states, budget-exceeded | MEASUREMENT | `ruleset-options.md:92,164` | — | `GLOBAL.R1` | 0 | ? |
| `4x4.R1` | R1 | 4×4 | PSK intractable at 4×4 — "structural; measured at 2×2" | CLAIMED | `4x4/EPISTEMIC.md:22` | `d:GLOBAL.R1`, `e:2x2.R1` (inherited — §5-I3) | 4×4 generation-rule decision | 0 | ? |
| `GLOBAL.R2` | R2 | all | score-on-cycle is exactly as exact-intractable as PSK — byte-identical state counts (118,475,182 at 2×2; 116,114,272 at 3×2). "Not a coincidence, a proof of structure" | PROVEN (argument) + MEASUREMENT | `ruleset-options.md:156-181`; `AGENTS.md:52-53` | `e:2x2.R1`, `e:3x2.R1` (inherited to all sizes — §5-I4) | `GLOBAL.H1` long-cycle constraint, Option B foreclosure | 0 | ? |
| `GLOBAL.R3` | R3 | all | kill-X% collapses the ko-sensitive region | FALSE-AS-SCOPED | `CONCEPTS.md:130`; `AGENTS.md:50-51` | — | ruleset pivot | 0 | ? |
| `4x4.R3` | R3 | 4×4 | kill-X% census at 4×4, 4 thresholds: 21.32% (0) / 21.24% (50) / 21.63% (40) / **25.01%** (30) — it makes the ko-sensitive region WORSE | PROVEN (falsification) | `ruleset-options.md:107-127`; `4x4/EPISTEMIC.md:23,47-48` | `e:4x4.M1` | `GLOBAL.R3` | 0 | ? |
| `2x2.R3` | kill-X% | 2×2 | kill-50 makes 2×2 trivial with the score UNCHANGED (+1, 4795 nodes) | MEASUREMENT | `ruleset-options.md:91,98` | — | `GLOBAL.R3` nuance | 0 | ? |
| `3x2.R3` | kill-X% | 3×2 | kill-50 is too lenient at 3×2 (still intractable, 125M states); the threshold must scale with board size | MEASUREMENT | `ruleset-options.md:92,99-101` | — | `GLOBAL.R3` nuance | 0 | ? |
| `GLOBAL.RPLY` | RETRO_PLY | 2×2/3×2 | The exact N-ply superko sweep is intractable for **every** N including N=1 (basic ko) and PSK — all rows hit the 200M-node budget | PROVEN (falsification) | `ruleset-options.md:53-71` | — | `GLOBAL.H1`, bounded-history route | 0 | ? |
| `GLOBAL.RPLY-TRAP` | — | all | Bounded-history N-ply is only bounded for *legality*; the score-on-cycle terminal drags the whole history back into the memo key | PROVEN (argument) | `ruleset-options.md:62-71` | `d:GLOBAL.R2` | `GLOBAL.H1` | 0 | ? |
| `GLOBAL.RPLY-RETRO` | — | all | The only tractable home for N-ply is the retrograde engine with the window **in the state**; that state space is sparse and defeats dense colex addressing | CLAIMED | `ruleset-options.md:73-81` | — | representation fork | 0 | ? |
| `GLOBAL.RNPLY-FORBID` | — | all | Bounded "N-ply superko (forbid-only)" does **not** terminate — a cycle longer than N is legal | PROVEN | `ruleset-options.md:42-51` | — | `GLOBAL.RPLY` | 0 | ? |
| `GLOBAL.MIGOS-RULE` | — | all | MIGOS II (van der Werf & Winands, ICGA 2009) plays basic ko + long-cycle-ties, **not** superko; the two rulesets legitimately disagree on cycle-dominated boards | PROVEN | `retrograde-3x3.md:222-241` | — | all anchor comparisons, `GLOBAL.H1` | 0 | ? |
| `GLOBAL.ANCHOR-DELTA` | — | 2×2/3×2 | Published 2×2 = 0 and 2×3 = 0 vs weizigo's PSK +1 / +1 — a ruleset-variant difference, not a bug | CLAIMED | `retrograde-3x3.md:234-238` | `d:GLOBAL.MIGOS-RULE`, `e:2x2.C1`, `e:3x2.C1` | `GLOBAL.H1` falsification target (§6-D8) | 0 | ? |
| `GLOBAL.REFRAME` | B05/B11 | all | The near-term deliverable is a **fresh-start score table + CLAIMED `[L,H]` bracket**, with the explicit non-promise that neither equals nor bounds the real-game PSK score | CLAIMED (adopted decision) | `PROGRESS.md:135-146,235-241`; `leak-crisis.md:150-154`; `AGENTS.md:59-62` | `n:GLOBAL.C2`, `n:GLOBAL.C3`, `n:GLOBAL.C4` (the reframe was adopted *because* these are false — §1 `n:`) | all downstream packaging | 3 | ? |
| `GLOBAL.UD-1` | UD-1 | all | User decision 1 resolved as YES and acted on | CLAIMED | `PROGRESS.md:238-240` → `untracked/SUBAGENTS.md` (**not in git; see §7**) | `d:GLOBAL.REFRAME` | Track A regen | 0 | ? |
| `GLOBAL.UD-2` | UD-2 | all | User decision 2 resolved as YES and acted on; blocks the `4x4.S4` TODO | CLAIMED | `PROGRESS.md:238-240`; `4x4/EPISTEMIC.md:35,326-327` | `d:GLOBAL.REFRAME` | `4x4.S4` | 0 | ? |
| `GLOBAL.UD-3` | UD-3 | all | User decision 3 resolved as YES and acted on | CLAIMED | `PROGRESS.md:238-240` | `d:GLOBAL.REFRAME` | 4×4 bracket-only artifact (T14.1) | 0 | ? |
| `GLOBAL.PSK-GAP` | — | all | PSK is abandoned as the generation rule (2026-07-24) **but the 4×4 artifact and the GTP player are both still PSK** | PROVEN | `PROGRESS.md:178-181,224-228`; `open-hypotheses:56-61` | `d:GLOBAL.R1` | `GLOBAL.H1` | 0 | ? |

### 2.7 Chainability (2026-07-27) and the M-facts

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.CHAIN-DEF` | — | all | *Chainable* [project term]: a region where `V0(P,s) == best_s({V0(child,−s)} ∪ {V1(P,−s)})`. Taking an extremum over stored child values is only defined on a chainable region | — (definition) | `ko-sensitive-chainability.md:24-33` | — | every chainability row | 0 | ? |
| `GLOBAL.CHAIN-LH` | M4 | 2×2/3×2/3×3/4×3/4×4 | The single-score (L==H) region **is chainable** — zero identity violations outside the KO_SENSITIVE flag at every size tested, under both the full and the ADR-0006 eye-pruned move sets | PROVEN (on the audited artifacts) | `ko-sensitive-chainability.md:60-69`; `PROGRESS.md:72-82,192-197` | `e:2x2.M4`…`e:4x4.M4` | `4x4.FP1-C3`, `GLOBAL.H4`, `GLOBAL.H5a` | 0 | ? |
| `GLOBAL.CHAIN-KO` | M4 | same | The ko-sensitive region is **not** chainable; violations are *exactly co-extensive* with the KO_SENSITIVE flag (16/16, 72/72, 688/688, 6,092/6,092, 11,402/11,402) — no unflagged slot ever violates | PROVEN | `ko-sensitive-chainability.md:70-71`; `PROGRESS.md:86-92` | `e:2x2.M4`…`e:4x4.M4` | `4x4.GTP-DEFECT`, `GLOBAL.H5` | 0 | ? |
| `GLOBAL.CHAIN-KIND` | — | all | Ko-sensitive violations are **definitional in kind** — each such slot is an independent fresh-start PSK solve owing its parent no agreement across a history-free edge; a nonzero rate is expected, 0% would indicate a broken tool | PROVEN | `ko-sensitive-chainability.md:71-79,198-211`; `corrections:175-201` | `n:GLOBAL.C2` | `4x4.M6` reading 1, `GLOBAL.C-1` | 0 | ? |
| `GLOBAL.MAXGAP` | — | 3×2/3×3/4×3/4×4 | For every board with n ≥ 6 the worst misprice is exactly **2n** (12, 18, 24, 32) — the full board swing; 2×2 is the exception (2, not 8) | CLAIMED | `ko-sensitive-chainability.md:94-100`; `PROGRESS.md:98-102` | `e:2x2.M4`…`e:4x4.M4` | none (explicitly not carried to 5×5) | 0 | ? |
| `2x2.M4` | M4 | 2×2 | 77.36% of checked slots ko-sensitive; 19.51% misprice within flag; max gap 2; **0** outside | MEASUREMENT | `ko-sensitive-chainability.md:50` (`bin/weizigo-chainability artifacts/oracle-2x2.wzo`) | — | `GLOBAL.CHAIN-LH`, `GLOBAL.C-1` | 0 | ? |
| `3x2.M4` | M4 | 3×2 | 41.18% ko-sensitive; 19.05% misprice; max gap 12; **0** outside | MEASUREMENT | `ko-sensitive-chainability.md:51` | — | `GLOBAL.CHAIN-LH`, `GLOBAL.C-1` | 0 | ? |
| `3x3.M4` | M4 | 3×3 | 35.04% ko-sensitive; 7.91% misprice; max gap 18; **0** outside | MEASUREMENT | `ko-sensitive-chainability.md:52` | — | `GLOBAL.CHAIN-LH` | 0 | ? |
| `4x3.M4` | M4 | 4×3 | 26.60% ko-sensitive; 3.58% misprice; max gap 24; **0** outside (exhaustive) | MEASUREMENT | `ko-sensitive-chainability.md:53` | — | `GLOBAL.CHAIN-LH` | 0 | ? |
| `4x4.M4` | M4 | 4×4 | 21.27% ko-sensitive; 4.08% misprice; max gap 32; **0** outside — 1:37 colex stride, 657,566 positions / 1,313,248 slots on `data/oracle-4x4.checkpoint.wzo` | MEASUREMENT | `4x4/EPISTEMIC.md:187-198`; `ko-sensitive-chainability.md:54,45` | `e:4x4.PARALLEL` | `4x4.FP1-C3`, `4x4.M6`, `GLOBAL.H4` | 0 | ? |
| `4x4.M6` | M6 | 4×4 | Writes-off regeneration **halves** the ko-sensitive misprice rate: 4.08% → 1.67% at stride 37; 3.81% → 1.47% at stride 997; 0 outside the flag on both artifacts at both strides | MEASUREMENT | `4x4/EPISTEMIC.md:206-245`; `ko-sensitive-chainability.md:163-197` | `e:4x4.M4`, `e:4x4.WRITESOFF` | `4x4.M6-FLOOR`, `4x4.M6-EXCESS`, `4x4.F2`, `4x4.F3` | 0 | ? |
| `4x4.M6-FLOOR` | M6 (i) | 4×4 | The definitional floor is **nonzero**: writes-off still shows 1.67%. **0% is not the target value for a correct artifact** | PROVEN (on the swept artifact) | `4x4/EPISTEMIC.md:222-226`; `ko-sensitive-chainability.md:198-211` | `d:GLOBAL.CHAIN-KIND`, `e:4x4.M6` | interpretation of every future sweep | 0 | ? |
| `4x4.M6-EXCESS` | M6 (ii) | 4×4 | The committed artifact's ≈2.4× excess over that floor **is** the ADR-0013 `ko_ref ≥ d` GHI bug | CLAIMED | `4x4/EPISTEMIC.md:227-231`; `ko-sensitive-chainability.md:213-234` | `d:4x4.F1`, `e:4x4.M6` | `4x4.F3` acceptance framing | 0 | ? |
| `4x4.M6-SCREEN` | — | 4×4 | The ko-sensitive misprice rate is a **cheap artifact-only discriminator** between sound and unsound generation — a screen, not a gate | CLAIMED | `4x4/EPISTEMIC.md:232-235`; `ko-sensitive-chainability.md:236-244` | `d:4x4.M6` | Track A validation workflow | 1 | ? |
| `4x4.WRITESOFF` | — | 4×4 | `untracked/oracle-4x4-writesoff-checkpoint.wzo` exists but its **build completion is NOT confirmed**; it is uncommitted and differs from the committed artifact by 2,394 filled slots (0.18%) at stride 37 | MEASUREMENT | `4x4/EPISTEMIC.md:236-242`; `ko-sensitive-chainability.md:246-254` | — | `4x4.M6`, `4x4.F3` | 0 | ? |
| `4x4.M1` | M1 | 4×4 | Ko-sensitive region = 10,367,922 / 48,636,330 = **21.32%** (exhaustive) | MEASUREMENT | `4x4/EPISTEMIC.md:186`; `ruleset-options.md:116` | `e:4x4.S3a`, `e:GLOBAL.ADR0009-NOEYE` | `4x4.R3`, `4x4.M4` cross-check | 0 | ? |
| `4x4.M2` | M2 | 4×4 | 19 sweeps to fixpoint at 4×4 (the measurement; `4x4.FP3` is the theorem) | MEASUREMENT | `4x4/EPISTEMIC.md:246-247`; `retrograde-4x4.md:21` | — | `4x4.FP1-C2`, 5×5 projection | 0 | ? |
| `4x4.M3` | M3 | 4×4 | 649,517 ko-sensitive orbit reps; finisher 6.1 min; ~1,663 nodes/rep avg; max/root 349,349; total 1,080,118,252 nodes | MEASUREMENT | `4x4/EPISTEMIC.md:248`; `retrograde-4x4.md:23-25,33-34` | `e:GLOBAL.F1` (measured on the **writes-on** config) | `GLOBAL.H5c` cost, 5×5 projection | 0 | ? |
| `4x4.BRACKET` | — | 4×4 | Empty 4×4 bracket = **[−6, +16]** (22 wide out of 32); the published anchor +2 is in-bracket | MEASUREMENT | `4x4/EPISTEMIC.md:249`; `ruleset-options.md:213` | `e:4x4.FP1` | `4x4.M5`, `4x4.ANCHOR` | 0 | ~70% |
| `4x4.SINGLE` | — | 4×4 | Fresh-start single-score region = 38,268,408 / 48,636,330 = **78.68%** of slots | MEASUREMENT | `4x4/EPISTEMIC.md:250`; `ruleset-options.md:213` | `e:4x4.M1` | `GLOBAL.REFRAME` scope | 0 | ? |
| `4x4.TANGLE` | — | 4×4 | 3,702,442 ko-sensitive slots have a width-32 bracket = the full [−16,+16] range — over a third of the region carries zero information | MEASUREMENT | `ruleset-options.md:216-218` | `e:4x4.BRACKET` | deliverable honesty | 0 | ? |
| `4x4.ANCHOR` | — | 4×4 | `empty(B) 4×4 = +2` (dtt 13) agrees with the published MIGOS II anchor (van der Werf & Winands, ICGA 2009; van der Werf 2005 PhD thesis §6.4). **MIGOS II plays basic ko + long-cycle-ties, NOT PSK** (`GLOBAL.MIGOS-RULE`, `QA-025`). The agreement is cross-ruleset — see `4x4.CYCLE-INSENS` for the inference it licenses. A 15-ply self-play game on the artifact scores B+2. **Corrected 2026-07-29 (AUDIT-REF-DSPro-2026-07-29 §1): the original text claimed "under PSK," which is contradicted by `GLOBAL.MIGOS-RULE`.** | MEASUREMENT | `retrograde-4x4.md:74-84` | `e:GLOBAL.P1` (which is FALSE-AS-SCOPED as *validation*) | `4x4.C1` support, §4-O4 | 0 | ~70% |
| `4x4.CYCLE-INSENS` | — | 4×4 | "The 4×4 empty-board score is evidently cycle-rule-insensitive, unlike 2×2/3×2" | CLAIMED | `retrograde-4x4.md:77-80` | `d:GLOBAL.MIGOS-RULE`, `e:4x4.ANCHOR` | `GLOBAL.H1` anchor argument (§5-I24) | 0 | ~70% |
| `4x4.VALBATTERY` | — | 4×4 | 4×4 validation summary (2026-07-21): 0 bracket-fails, 0 orbit-clashes, exhaustive symmetry PASS over all 43M slots, 0 unfilled legal slots, reload byte-identical | MEASUREMENT | `retrograde-4x4.md:86-88` | `e:GLOBAL.P2`, `e:CODE.ADR0011-GATE` | §4-O5 | 0 | ? |
| `4x4.COMPLETE-2026-07-21` | — | 4×4 | "The complete, validated 4×4 oracle — every legal (position, side) exact" (`data/oracle-4x4.wzo`, 258,280,358 B, sha256 `b42c3371…655f`) | FALSE-AS-SCOPED | `retrograde-4x4.md:1-13`; retracted by `PROGRESS.md:267-270`, `0013:126-128`, `AGENTS.md:54-57` | `d:GLOBAL.F1`, `d:GLOBAL.C1` | §4-O5, `GLOBAL.ADR0012-GATE` | 0 | ? |
| `4x4.PARALLEL` | — | 4×4 | `data/oracle-4x4-parallel.checkpoint.wzo` — writes-off finisher, **99.8% filled**, 83K UNDEF slots (mostly 2-ko+) | MEASUREMENT | `arena-4x4-undef.md:20-26`; `PROGRESS.md:211,244-245` | — | `4x4.B43`, `4x4.M4`, §6-D13 | 0 | ? |
| `4x3.M1` | M1 | 4×3 | Ko-sensitive fraction = 170,276 / 643,378 = **26.47%** | MEASUREMENT | `4x3/EPISTEMIC.md:40`; `ruleset-options.md:212` | `e:4x3.S3a` | `4x3.M4` cross-check (§6-D7) | 0 | ? |
| `4x3.M2` | M2 | 4×3 | 17 sweeps to convergence | MEASUREMENT | `4x3/EPISTEMIC.md:41` | — | `4x3.FP1` | 0 | ? |
| `4x3.M3` | M3 | 4×3 | Full 4×3 writes-on solve ~4.7 s (census), ~31 s with the sound dependency guard; ~16.6× node-count increase vs 3×3 | MEASUREMENT | `4x3/EPISTEMIC.md:42` | — | `4x4.D3` pilot extrapolation | 0 | ? |
| `4x3.BRACKET` | — | 4×3 | Empty 4×3 bracket = **[−1, +12]** (width 13 of 28); published anchor **+4** is in-bracket | MEASUREMENT | `4x3/EPISTEMIC.md:43-44`; `ruleset-options.md:212` | `e:4x3.FP1` | `4x3.C1` support | 0 | ~56% |
| `4x3.TANGLE` | — | 4×3 | 54,388 4×3 slots have a width-24 bracket = the entire [−12,+12] range | MEASUREMENT | `ruleset-options.md:228-230` | `e:4x3.BRACKET` | deliverable honesty | 0 | ? |
| `3x3.M1` | — | 3×3 | Ko-sensitive = 8,698 / 25,350 = 34.3%; single-score 16,652 (65.7%) | MEASUREMENT | `ruleset-options.md:211`; `retrograde-3x3.md:66` | — | §6-D7 | 0 | ? |
| `3x3.BRACKET` | — | 3×3 | Empty 3×3 bracket = **[+2, +9]** (width 7); all five published anchors are in-bracket | MEASUREMENT | `retrograde-3x3.md:102-110`; `ruleset-options.md:211` | `e:3x3.B1` | `3x3.C3` (the leak went to −9, **outside** the bracket) | 0 | ~42% |
| `3x3.ANCHOR` | — | 3×3 | Anchors PIN and MATCH after bracket-guided finishing: empty +9/−9, centre +9, side +3, corner −9 | MEASUREMENT | `retrograde-3x3.md:183-185`; `0008:45-47` | `e:3x3.F2` | `3x3.C1` support | 0 | ~42% |
| `GLOBAL.SWEEPS` | — | 2×2→4×4 | Sweep growth 2 → 6 → 12 → 19 is strongly sub-linear in slot count; the ko-sensitive fraction keeps FALLING (72 → 39 → 34 → 21.3%) | MEASUREMENT | `retrograde-4x4.md:21-22,30-32` | — | 5×5 projection (§5-I16 class) | 0 | ? |
| `2x2.EXACT` | Finding 3/5 | 2×2 | The 2×2 pipeline is complete: 9 orbit reps solved, 82 slots by symmetry, 0 bracket-fails, 0 orbit-clashes, exhaustively symmetric | MEASUREMENT | `retrograde-3x3.md:74-82` | `e:GLOBAL.INVSYM` | `2x2.C1` | 0 | ? |
| `3x2.EXACT` | Finding 3 | 3×2 | History-exact ground truth completed on **68 of 600** roots at 3×2 (2×2: **8 of 114**), all with zero mismatches and every score in-bracket | MEASUREMENT | `retrograde-3x3.md:50-52,141` | — | `2x2.C1`, `3x2.C1` (§6-D9) | 0 | ? |
| `3x3.FWD-SPOT` | Finding 7 | 3×3 | 400 sampled certified deep 3×3 roots re-solved no-memo forward: **295 exceeded budget**, 105 completed, 105/105 matched | MEASUREMENT | `retrograde-3x3.md:128-135` | — | `3x3.C1` support | 0 | ? |
| `GLOBAL.FWD-INTRACT` | Finding 1/3 | 3×3 | Forward fresh-start filling of the 3×3 table was measured INTRACTABLE (years); the exact state space explodes before the position space does | PROVEN | `retrograde-3x3.md:17-21,39-58` | `d:GLOBAL.R1` | the retrograde design | 0 | ? |
| `GLOBAL.FIN-NEARTERM` | Finding 6 | 3×3 | The plain (ADR-0009) finisher rescues near-terminal ko-sensitive slots, **not** the opening: empty(B) 3×3 exceeded 2.0e9 nodes seeded with all 8,326 certified scores | MEASUREMENT | `retrograde-3x3.md:84-100` | — | `GLOBAL.ADR0010-CUT` motivation | 0 | ? |
| `GLOBAL.FIN-BRACKET` | Finding 8 | 2×2/3×2/3×3 | Bracket cutoffs collapse the finisher by ~6 orders of magnitude; empty(B) 3×3 pins in 1,854 nodes | MEASUREMENT | `retrograde-3x3.md:165-179` | `e:GLOBAL.ADR0010-CUT` | `GLOBAL.H5c` | 0 | ? |
| `4x4.DRIVER` | — | 4×4 | Driver saga: aspiration dies on wide brackets (>5e8 nodes, abandoned on the empty root); bare MTD is worse; MTD + per-root bounds memo solves all 649,517 reps with zero skips | MEASUREMENT | `retrograde-4x4.md:36-62` | — | `4x4.M3`, `GLOBAL.H3` context | 0 | ? |

### 2.8 Open hypotheses (H) — the 2026-07-27 register

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.H1` | H1 | all | The simple-ko pivot: every symptom follows from **one** mismatch — PSK is non-Markovian while the table is Markovian; under simple ko + long-cycle-ties the state `(position, side, ko_point)` is Markovian and a table over it would be chainable by construction | CLAIMED | `open-hypotheses:30-118`; `PROGRESS.md:169-183` | `n:GLOBAL.C2`, `n:GLOBAL.C3`, `n:GLOBAL.C4` (the pivot is motivated by their falsity), `d:GLOBAL.CHAIN-KO`, `d:GLOBAL.LONGCYCLE` | project direction; a new ADR | 0 | ? |
| `GLOBAL.H1-CENSUS` | H1 census | 4×4 | Reachable `(position, ko_point, side)` triple count at 4×4 is a small multiple of the 48,636,330 slots (naive dense bound: 3^16 × 17 × 6 B = **4.39 GB**, 17× the current artifact). **Measured exactly 2026-07-28 (EXP-3): 51,419,046 reachable triples = 1.057× the 48,636,330 slots; 29,497,329 distinct `(b, ko)` addresses = 4.031% of the naive dense 731,794,257; 176,983,974 B = 177 MB at 6 B/address = 0.69× the current PSK artifact; 29 sweeps to fixpoint. GO on dense addressing.** No sampling, no striding | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:23,228-241`; calibration at 4×4: `4x4-ko-disabled.txt` (known-good), `4x4-broken-every_capture.txt` (known-bad, +91%) | `e:GLOBAL.S3a` (the OEIS A094777 legal-count known-good the census reproduces: 24,318,165) | `GLOBAL.H1` GO/NO-GO, `4x4.D3` budget (≤ 32 GB placeholder → measured 177 MB / 354 MB with passes) | 0 | ? |
| `3x3.H1-CENSUS` | — | 3×3 | Reachable `(position, side, ko_point)` census at **3×3** under the standard basic-ko detector, exact: **22,736** reachable triples, **13,997** distinct `(b, ko)` addresses = **7.111%** of the naive dense 196,830, 83,982 B at 6 B/address, 16 sweeps. `ko_point = none` on 12,101 of 13,997 addresses (86.4%). New row minted 2026-07-28 — the ID was already cited by `docs/infra/dispatch/EXP-3.md` and `docs/status/CURRENT.md` with no register row | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/3x3-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:21,201-218`; calibration at 3×3: `3x3-ko-disabled.txt`, `3x3-broken-every_capture.txt` (+60%), `3x3-broken-every_move.txt` (+84%) | `e:GLOBAL.S3a` (OEIS A094777 known-good reproduced at 3×3: 12,675) | `GLOBAL.H1` GO/NO-GO | 0 | ? |
| `4x3.H1-CENSUS` | — | 4×3 | Reachable `(position, side, ko_point)` census at **4×3** under the standard basic-ko detector, exact: **638,266** reachable triples, **375,281** distinct `(b, ko)` addresses = **5.432%** of the naive dense, 2,251,686 B at 6 B/address, 25 sweeps. New row minted 2026-07-28; ID previously dangling. **Calibration caveat, stated not hidden:** the broken-detector known-bads were run at 3×3 and 4×4 only, **not at 4×3**, and 4×3's legal-count known-good (321,689) is the project's own ground truth rather than a published figure. The known-bad is inherited as a property of the *detector code* (one binary, board size a compile-time parameter) per **ADR-0016** clause 2 | PROVEN | `docs/evidence/GLOBAL.H1-CENSUS/4x3-standard.txt`; `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`; `kostate-census-2026-07-28.md:22,220-226` | `e:4x3.S3a` (the 4×3 legal count 321,689, independently reproduced by the census enumerator), `d:GLOBAL.ADR0016-INHERIT` (the calibration inheritance this row relies on) | `GLOBAL.H1` GO/NO-GO | 0 | ? |
| `GLOBAL.LONGCYCLE` | — | all | "Long cycle = tie" is a loopy-game fixpoint computable by the existing converge machinery — **UNVERIFIED and must not be asserted**; any candidate must resolve cycles without knowing which earlier boards were seen, or it has smuggled score-on-cycle back in. **FALSIFIED at 3x2 2026-07-29 (2B-PROBE-FIX + 2B-6): the existing converge machinery with a pointwise tie-pin does NOT compute the history-conditioned value. Whether ANY pointwise function of (L,TIE,H) can is open — task `PINRULE-SUFFICIENCY`.** | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2b-6-full-review-2026-07-29.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `open-hypotheses:92-103` | `d:GLOBAL.R2` (the foreclosure constraint) | `GLOBAL.H1`, any simple-ko build | 0 | ? |
| `GLOBAL.H2` | H2 | 4×4 | The greedy player's loss rate strictly exceeds the arena's random-persona leak rate | UNTESTED | `open-hypotheses:122-166` | `d:4x4.GREEDY-BIAS`, `e:4x4.B43` | relabelling or retiring the 3.4% figure | 0 | ? |
| `GLOBAL.H3` | H3 | 4×4 | There is an empty-point count below which memo-free, bracket-free, history-exact 4×4 search under the real history is affordable at play time | UNTESTED | `open-hypotheses:170-214` | `n:GLOBAL.F1` (memo-free *because* the sound memo does not exist) | `GLOBAL.H5b` | 0 | ? |
| `GLOBAL.H3-LOWERBOUND` | H3 context | 2×2/3×2 | The 2026-07-27 re-measurement (empty 2×2 = 2.3M nodes / 132 ms; empty 3×2 did not finish in 100 s) is a **lower bound on achievable performance**, not a measurement of the method — the probe used a linear history scan and neither `zobrist.zig` nor the `scount`/`armed` prune | MEASUREMENT | `open-hypotheses:172-182`; `ko-sensitive-chainability.md:269-274` | — | `GLOBAL.H3` | 0 | ? |
| `GLOBAL.H4` | H4 | 4×4 | FP1 acceptance check 3 has two residual gaps: (a) the `lo`/`hi` bracket tables were never checked (WZO1 carries no bracket columns); (b) 4×4 was a 1:37 sample | CLAIMED (partial) | `open-hypotheses:217-261`; `PROGRESS.md:77-81,221-223` | `d:4x4.FP1-C3` | `4x4.FP1` | 0 | ? |
| `GLOBAL.H4a` | H4(a) | 4×4 | V0/V1 identity on the in-memory `Retro(4,4).Tables.lo`/`.hi` quads | UNTESTED | `open-hypotheses:224-228,233-235` | `d:4x4.D3` (needs a build) | `GLOBAL.H4`, `4x4.FP1` | 0 | ? |
| `GLOBAL.H4b` | H4(b) | 4×4 | Exhaustive (stride 1) chainability sweep at 4×4 | UNTESTED | `open-hypotheses:229-231,236-239` | — | `GLOBAL.H4`, removes `4x4.M4`'s sampling caveat | 0 | ? |
| `GLOBAL.H5` | H5 | 4×4 | The GTP player can be made to stop asserting mispriced numbers **without resolving any open epistemic question** | CLAIMED | `open-hypotheses:265-313` | `d:4x4.GTP-DEFECT` | deliverable decision | 0 | ? |
| `GLOBAL.H5a` | H5(a) | 4×4 | Restricting table steering to the chainable L==H region is **sound but weak** — on 4×4 it gives no table guidance from move one | CLAIMED | `open-hypotheses:274-279` | `d:GLOBAL.CHAIN-LH`, `e:4x4.M5` | player fork | 0 | ? |
| `GLOBAL.H5a-CHILD` | H5(a) correction 1 | 4×4 | **A 1-ply Bellman-identity check at the current node is NOT sufficient** to license table steering — the **chosen child** must be checked too. Ruled 2026-07-28 (D-3, Opus) as a condition of H5(a) shipping. The demonstrating instance is `4x4.A-3`: at ply 14 the node's own V0 was −3 while the child the player chose was −16, so a node-only check passes exactly where the player is about to be wrong. **Implementation shipped (EXP-9, Opus 5, 2026-07-29):** child-side refuse-on-divergence check + settled-area fallback in `src/gtp.zig`; a sign defect in the draft was found and fixed (pinned by a new antisymmetry test); +6.8%/genmove. **Acceptance 4 PARTIAL** — the A2 mechanism fires at ply 13 not ply 7 (structural reason in `docs/research/h5a-player-mitigation-2026-07-28.md` §5). **CLAIMED, not verified-optimal.** | CLAIMED | ruling D-3, 2026-07-28; EXP-9 2026-07-29 (`docs/research/h5a-player-mitigation-2026-07-28.md`); `corrections:99-132`; `regressions/4x4-black-win-after-ko.txt:74`; `open-hypotheses:274-279` | `n:4x4.A-3` (the requirement exists *because* "the player is fresh-start-perfect" is false at the chosen child; if `4x4.A-3` were rehabilitated the node-only check would suffice and this row would lose its reason to exist), `e:GLOBAL.CHAIN-LH`, `e:QA-014` | H5(a) implementation, `GLOBAL.H5` player fork | 0 | ? |
| `GLOBAL.H5a-FALLBACK` | H5(a) correction 2 | all | **"Refuse" must NOT mean pass.** When the identity check fails, the player falls back to a **history-free quantity** — settled area / Benson-alive territory — which is sound by theorem rather than by table lookup. Ruled 2026-07-28 (D-3, Opus) as the second condition of H5(a) shipping. Passing is a *move* with a value; refusing to price a position is not. **Implementation shipped (EXP-9, Opus 5, 2026-07-29):** the fallback is the settled-area / Benson-alive quantity in `src/gtp.zig`. **CLAIMED, not verified-optimal** (same EXP-9 run as `GLOBAL.H5a-CHILD`; same PARTIAL caveat). | CLAIMED | ruling D-3, 2026-07-28; EXP-9 2026-07-29 (`docs/research/h5a-player-mitigation-2026-07-28.md`); `open-hypotheses:281-284` (the H5(b) history-free-by-theorem argument this reuses); `0004:16-19,31-34` | `d:GLOBAL.S2`, `d:GLOBAL.ADR0004-TERM`, `e:GLOBAL.H5b` | H5(a) implementation, `GLOBAL.H5` player fork, `src/gtp.zig` genmove | 0 | ? |
| `GLOBAL.H5b` | H5(b) | 4×4 | History-exact search to a Benson-settled horizon is sound (the settled area score is history-free by theorem) | CLAIMED | `open-hypotheses:281-284` | `d:GLOBAL.S2`, `d:GLOBAL.ADR0004-TERM`, `d:GLOBAL.H3` | player fork | 0 | ? |
| `GLOBAL.H5c` | H5(c) | 4×4 | Bracket-cut search is tractable (≤3.5e5 nodes for the empty 4×4 root vs >5e8) but **NOT shippable as sound** — cutting on `[L,H]` under a real history *is* claim C3 | PROVEN (as an implication) | `open-hypotheses:286-291`; `ko-sensitive-chainability.md:276-281` | `d:GLOBAL.C3`, `e:GLOBAL.FIN-BRACKET` | §4-O1 (this is the edge that orphans the finisher) | 0 | ? |
| `GLOBAL.H5d` | — | all | Bounded-history state is the representational route to a real-game claim — a new ADR, not a bug fix | CLAIMED | `open-hypotheses:288-289`; `ko-sensitive-chainability.md:288-289`; `AGENTS.md:71-73` | `n:GLOBAL.C2` | future work | 0 | ? |
| `GLOBAL.ONEMISMATCH` | — | all | The leak crisis, C2, C3, C4 and the chainability collapse are plausibly all symptoms of a single mismatch (non-Markovian rule, Markovian table) — an interpretation offered to organise the findings, **not a proved theorem** | CLAIMED | `PROGRESS.md:169-183` | `d:GLOBAL.H1` | framing only | 0 | ? |

### 2.9 Corrections ledger (2026-07-27)

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `4x4.A-1` | A-1 | 4×4 | "With PSK history from the capture/ko fight, W A4 gave Black +16" — the game's history removed White's winning move | FALSE-AS-SCOPED | `corrections:19-62`; commit `753584f`. **Remediated:** `regressions/README.md` now carries the corrected wording (verified 2026-07-28; `corrections:60-62`'s line-21 citation is stale) | `e:4x4.KO-RULE-NULL` | `4x4.GTP-DEFECT` (the corrected cause) | 0 | ? |
| `4x4.A-2` | A-2 | 4×4 | "The blunder is the C2 falsification in action" | FALSE-AS-SCOPED (category error — every blundering node is KO_SENSITIVE, i.e. outside C2's scope) | `corrections:66-96` | `e:GLOBAL.CHAIN-KO` | corrected attribution = `GLOBAL.C4` + unchainability | 0 | ? |
| `4x4.A-3` | A-3 | 4×4 | "The engine is *fresh-start perfect*, not *history perfect*" | FALSE-AS-SCOPED (the player is not fresh-start-perfect in the ko-sensitive region: node's own V0 = −3, chosen child = −16) | `corrections:99-132`; `regressions/4x4-black-win-after-ko.txt:74`. **Remediated:** `src/gtp.zig:42` now states "neither history-perfect NOR fresh-start-perfect" and `regressions/README.md:72,81` carries the correction (verified 2026-07-28; `corrections:107,130-132`'s `gtp.zig:37` citation is stale) | `e:4x4.M4` | `4x4.GTP-DEFECT` | 0 | ? |
| `GLOBAL.B-1` | B-1 | all | ADR-0013's Consequences: "The history-perfect genmove (GTP player) shares this machinery; it inherits the fix automatically" | FALSE-AS-SCOPED (as of the code at 2026-07-27) | `corrections:136-171`; `0013:129-130`; `src/gtp.zig:154-196,90-93,121-132`; `src/artifact.zig:23-53,140,181` | — | any plan assuming a finisher fix improves play | 0 | ? |
| `GLOBAL.C-1` | C-1 | all | (Transient) the chainability violations in the committed 4×4 artifact were the ADR-0013 bug resurfacing | FALSE-AS-SCOPED | `corrections:175-201` | `e:2x2.M4`, `e:3x2.M4` (calibration on known-good artifacts) | `GLOBAL.CHAIN-KIND` | 0 | ? |
| `GLOBAL.CALIB-LESSON` | C-1 lesson | all | A self-consistency check with no *passing* calibration case cannot distinguish "bug" from "definition" — every input looks guilty | PROVEN (methodological) | `corrections:197-201` | — | auditor practice | 0 | ? |

### 2.10 Format, artifacts, and process claims

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `CODE.ADR0011-FMT` | — | all | WZO1 = 32-byte header + **six** frozen columns `vb\|vw\|fb\|fw\|db\|dw`; the reader REFUSES on any header mismatch; **no `lo`/`hi` bracket columns exist** | PROVEN | `0011:21-37`; `corrections:153-158`; `src/artifact.zig:23-53` | `d:GLOBAL.S1` | `GLOBAL.H4a`, `GLOBAL.B-1`, `4x4.FP1-C3` scope caveat | 0 | ? |
| `CODE.ADR0011-GATE` | — | all | `retro.saveArtifact` refuses to write unless the same process passed: finisher completed every orbit, 0 bracket-fails, 0 orbit-clashes, exhaustive symmetry PASS, **no UNDEF on any legal slot** — then reloads and byte-verifies | PROVEN | `0011:39-46` | `d:GLOBAL.P2` | `4x4.VALBATTERY`, §6-D13 | 0 | ? |
| `CODE.ADR0011-DTT` | — | all | DTT is **best-effort** where optimal lines cross unfinished V1 slots; a later V1-finishing pass would tighten a side-file column without moving addresses | CLAIMED | `0011:63-65`; `0009:138-146` | — | DTT-based tie-breaks in `src/gtp.zig` | 1 | ? |
| `GLOBAL.ADR0009-DTT` | — | all | DTT = *fastest optimal resolution* (both sides play score-optimal and cooperate on speed), computed by a monotone-decreasing min-sweep; well-defined on the cyclic graph | PROVEN | `0009:138-146` | — | `CODE.ADR0011-DTT` | 0 | ? |
| `GLOBAL.ADR0012-GATE` | — | 3×3/4×4/6×3 | Any engine change must first reproduce the recorded **sha256** artifacts end-to-end on 3×3 / 4×4 / 6×3; no green gate, no big board | CLAIMED | `0012:157-159`; `0012:46-49` | `d:4x4.COMPLETE-2026-07-21` | §4-O6 | 0 | ? |
| `GLOBAL.ADR0012-PAR` | — | all | Converged tables are **byte-identical regardless of thread schedule** (unique least/greatest fixpoints; chaotic-iteration convergence of monotone maps), so final-hash verification survives parallelism | CLAIMED | `0012:160-166` | `d:GLOBAL.FP1`, `d:GLOBAL.FP3` | `4x4.PARALLEL`, all parallel builds | 0 | ? |
| `GLOBAL.ADR0012-5X5` | — | 5×5 | 5×5 is feasible: ~53e9 canonical-legal slots, ~106 GB working files, ≤40 GB RAM, ~4–6 days on 10 cores. "A real plan, not a wish" | CLAIMED (projection; ADR status is *proposed*, measurements pending) | `0012:3,124-131` | `d:GLOBAL.SWEEPS`, `d:GLOBAL.F4-COST` | 5×5 roadmap (on hold) | 0 | ? |
| `GLOBAL.ADR0012-LAYER` | — | 5×5 | Single 5×5 layers exceed RAM raw (peak layer k=17 ≈ 1.42e11 slots = 142 GB at 1 B/slot) → layered streaming alone does not save 5×5 | PROVEN (arithmetic) | `0012:91-95` | — | `GLOBAL.ADR0012-5X5` | 0 | ? |
| `GLOBAL.ADR0012-V1` | — | all | V1 is never stored — recomputed inline during a slot's own update; the quad shrinks 4 → 2 scores per fixpoint per slot | PROVEN | `0012:99-102` | `d:GLOBAL.ADR0005-PASS` | RAM-lean engine | 0 | ? |
| `GLOBAL.ADR0002-SEQ` | — | 5×5 | `collision_size`/`seq_table_size` for 9–16 stones are **2^(n−1) worst-case bounds, not measured** | UNTESTED | `0002:36-38`; `0005:127-130` | — | 5×5 forward-search feasibility | 0 | ? |
| `GLOBAL.ADR0007-AB` | — | all | Alpha-beta / proof-number search cannot populate an oracle — it returns the root score plus bounds and prunes whole subtrees unvisited | PROVEN | `0007:25-28` | — | the retrograde design | 0 | ? |
| `GLOBAL.ADR0007-BACKEDGE` | — | all | Captures create back-edges (k stones → k−3), so retrograde must be a **fixpoint iteration, not a single topological sweep** | PROVEN | `0007:30-33`; `0009:41-46` | — | `GLOBAL.FP3`, the whole out-of-core design | 0 | ? |
| `GLOBAL.ADR0009-SUCC` | — | all | Values propagate by successor sweeps, never predecessor generation — un-capture inversion is a large unvalidatable kernel and would not buy a one-sweep guarantee anyway | PROVEN (design argument) | `0009:28-46` | `d:GLOBAL.ADR0007-BACKEDGE` | `src/retro.zig` | 0 | ? |
| `GLOBAL.ADR0014-PURE` | — | all | `score.zig` consults **no oracle values**; every public function carries an epistemic tag; the report does not claim the fresh-start value and does not bound the real-game PSK score | PROVEN | `0014:16-25,65-71` | `d:GLOBAL.ADR0003-AREA`, `d:GLOBAL.S2` | scoring UI | 0 | ? |
| `GLOBAL.ADR0016-INHERIT` | — | all | **ADR-0016 (D-2, 2026-07-28):** per-board epistemic independence applies to **empirical** claims (never inherit) and not to **structural** ones — code or mathematics — which may inherit **with the inheritance argument written down**; status does not upgrade on inheritance; `mixed` and cross-ruleset are **unruled** and do not inherit. Supersedes the rule as stated in `AGENTS.md` and `CONCEPTS.md:65-71`; the `AGENTS.md` amendment is **outstanding** (another agent owned that file) | CLAIMED (adopted rule — a decision, not a fact) | `docs/decisions/0016-per-board-independence-empirical-vs-structural.md`; `critique-2026-07-28.md:373` | `e:QA-015` | §5 inheritance audit, §6-D2/D3/D4, `4x3.H1-CENSUS` (first application) | 0 | ? |
| `GLOBAL.ADR0015-BURDEN` | — | all | **ADR-0015 (D-5, 2026-07-28):** ADR-0010's premise that the `[L,H]` bracket "holds under ANY arrival history" is **refuted as stated** — for an empty-board root the finisher's own search path *is* a real game line, so E2's falsifying histories lie inside the family ADR-0010 claims to cover. `GLOBAL.F2` stays orphaned; the burden is on ADR-0010 and is **undischarged**. A ruling about an *argument*, not a new measurement: it does not establish that the bracket fails at any board other than 3×3. **Challenge attempted and FAILED (EXP-10, Fable 5, 2026-07-29 — ADR-0017):** the search-path family is **not** exempt — T13's 12 pointwise mismatches at 3×2 ride exactly the finisher's search-shaped histories (8/12 empty-rooted); ADR-0015 **stands, strengthened.** A three-seat blind review (`QA-018-REVIEW-A/B/C`: GLM-5.2, DeepSeek Pro, Kimi-k2.7) returned **unanimously** that ADR-0017's 'refutation failed' verdict is SOUND; all three convicted the two planted calibration defences (6 MTD self-verification, 7 `bracket_fail` gate) as WRONG. **Confirmed by ADR-0018 (the human's `QA-018-RULING`, 2026-07-29): ADR-0015 stands; F2 remains orphaned.** The finisher remedy is a new task (`F2-REMEDY`) — not a brackets-off regen, which inherits the same premise through CERTCORE-dependent seeds. | CLAIMED | `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`; `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md`; `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md`; `0010:16-18,70-93`; `src/retro.zig:464`; `critique-2026-07-28.md:376` | `n:GLOBAL.C3` (the ruling is justified by C3 being FALSE; if C3 were rehabilitated ADR-0010's premise would stand and this ADR would lose its reason to exist), `e:3x3.C3`, `e:QA-019` | `GLOBAL.F2` orphan status, `QA-018`, `GLOBAL.ADR0010-CUT`, artifact promotion, the brackets-off regen decision | 0 | ? |
| `GLOBAL.F2-REMEDY` | — | all | The finisher-replacement is the **median build**: `converge` on `(board, side, ko_point, passes)` under basic ko + constant tie `T`, then `V = median(L, T, H)` (proof-v2 Thm 5.1); no forward search, no brackets, no seed inheritance — F2 is **dissolved, not rehabilitated** (the F2 relationship is *supersession*, recorded here, not a graph edge). **Design only** (`docs/research/f2-remedy-design-2026-07-29.md`, Fable 5, 2026-07-29); gated on EXP-2B (the QA-023 computational half) and EXP-4 (2×2/2×3 = 0 falsifier). | CLAIMED | `docs/research/f2-remedy-design-2026-07-29.md`; `docs/evidence/QA-023/proof-v2-2026-07-28.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md` | `d:QA-023`, `d:QA-023.M1` | the new-rule build (EXP-4/5/6), the certified-fraction measurement (EXP-7), the PSK divergence (EXP-8 under the new rule) | 0 | ? |
| `GLOBAL.ADR0014-DEAD` | — | all | `dead_stone_estimate` and `territory_japanese` are conservative heuristics, deliberately under-claiming; not a life/death oracle | CLAIMED | `0014:37-38,42-48,68-71` | `d:GLOBAL.S2` | scoring UI honesty | 0 | ? |
| `4x4.D3` | D3 | 4×4 | Writes-off 4×4 tractability — **a measurement, not a truth claim**. Target wall ≤ 8 h, memory ≤ 32 GB (placeholder, unconfirmed with the user) | UNTESTED | `4x4/EPISTEMIC.md:175-183,328` | `e:4x3.M3` (pilot extrapolation) | `4x4.F2`, `4x4.F3`, `4x4.F4`, `GLOBAL.H4a`, `GLOBAL.H1-CENSUS` budget | 0 | ? |
| `GLOBAL.B15` | B15 | 2×2/3×2 | Track A 2×2/3×2 regen complete and **byte-identical** | CLAIMED | `PROGRESS.md:238-240,244-245` | `d:GLOBAL.F3` | `2x2.C1`, `3x2.C1` (§6-D10) | 0 | ? |
| `GLOBAL.T14.1` | T14.1 | 4×4 | 4×4 bracket-only artifact produced 2026-07-27 | CLAIMED | `PROGRESS.md:238-240` | — | `GLOBAL.REFRAME` packaging | 0 | ? |
| `GLOBAL.ONEWRITER` | — | n/a | Concurrent edits to `retro.zig`/`oracle.zig`/`rules.zig`/`solve.zig` silently corrupt; one writer per engine file | CLAIMED | `AGENTS.md:96-97,150-171` | — | all parallel dispatch | 0 | ? |
| `GLOBAL.RELEASEFAST` | — | n/a | Asserts are no-ops in ReleaseFast — correctness runs must use `-Doptimize=ReleaseSafe` | PROVEN | `AGENTS.md:110-111` | — | every measurement's validity | 0 | ? |

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

| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `QA-001` | QA-001 | 2×2–4×4 | "V0 satisfies the one-ply Bellman identity by construction, everywhere" (raised by GLM) — **refuted**: 11,402/11,402 violations at 4×4, all KO_SENSITIVE, max gap 32 = 2n | FALSE | `critique-2026-07-28.md:359`; `ko-sensitive-chainability.md:70-71` | `e:GLOBAL.CHAIN-KO` | `GLOBAL.CHAIN-KO` (the correct statement) | 0 | ? |
| `QA-002` | QA-002 | 4×4 | **Alias of `4x4.A-3`.** "The player is fresh-start-perfect (unsound only for the real game)" — refuted at ply 14: stored −3, played child −16 | FALSE | `critique-2026-07-28.md:360`; `regressions/4x4-black-win-after-ko.txt:74` | `d:4x4.A-3` | `4x4.GTP-DEFECT` | 0 | ? |
| `QA-003` | QA-003 | 4×4 | **Alias of `4x4.A-2`.** "The 4×4 collapse is 'the C2 falsification in action'" — category error: C2 is scoped to L==H, every blundering node is L<H | FALSE | `critique-2026-07-28.md:361`; `corrections:66-96` | `d:4x4.A-2` | corrected attribution = `GLOBAL.C4` + unchainability | 0 | ? |
| `QA-004` | QA-004 | 4×4 | "The empty 4×4 board is really L==H / the KO_SENSITIVE flag is over-broad there" — refuted: bracket [−6,+16] | FALSE | `critique-2026-07-28.md:362`; `4x4/EPISTEMIC.md:249` | `e:4x4.M5`, `e:4x4.BRACKET` | `QA-005` | 0 | ? |
| `QA-005` | QA-005 | 4×4 | "A KO_SENSITIVE flag implies the identity fails at that node" — refuted: only 4.08% of flagged 4×4 slots violate, the empty board does not, plies 1–7 are clean. **Flagged = unguaranteed, not wrong** | FALSE | `critique-2026-07-28.md:363`; `ko-sensitive-chainability.md:54` | `e:4x4.M4` | the reading of every KO_SENSITIVE count in this file | 0 | ? |
| `QA-006` | QA-006 | 4×4 | "The chainability violations are purely definitional" (Opus, earlier) — refuted: writes-off 1.67% vs writes-on 4.08% at two strides. There is a floor **and** an excess | FALSE | `critique-2026-07-28.md:364`; `ko-sensitive-chainability.md:163-197` | `e:4x4.M6` | `4x4.M6-FLOOR`, `4x4.M6-EXCESS` | 0 | ? |
| `QA-007` | QA-007 | 4×4 | **Alias of `4x4.M6-EXCESS`.** "The excess above the definitional floor is the ADR-0013 `ko_ref ≥ d` bug" — upgrade path is `RETRO_CONSIST` on both artifacts, not a substitute for the auditor | CLAIMED | `critique-2026-07-28.md:365`; `4x4/EPISTEMIC.md:227-231` | `d:4x4.M6-EXCESS` | `4x4.F3` acceptance framing | 0 | ? |
| `QA-008` | QA-008 | 4×4 | "`untracked/oracle-4x4-writesoff-checkpoint.wzo` is a completed Track A regen" — asked of GLM 2026-07-28, unanswered. Blocks promoting `QA-007` and cheapening F2/F3 | UNTESTED | `critique-2026-07-28.md:366`; `4x4/EPISTEMIC.md:236-242` | `e:4x4.WRITESOFF` | `QA-007`, `4x4.F3` | 0 | ? |
| `QA-009` | QA-009 | 3×3 | "E2's 3×3 leak count is a **discrepancy**: 50/8000 (`PROGRESS.md`) vs 25/4000 (`leak-crisis.md`)" — **refuted 2026-07-28 (D-1, Opus): it is not a discrepancy.** They are two real runs: 25/4,000 is the original E2, 50/8,000 is B06's re-run; identical rate (0.625%) and identical maximum (12 pts) because the second **replicated** the first. Both are now separate register rows and neither was collapsed | FALSE | `critique-2026-07-28.md:367`; ruling D-1, 2026-07-28, recorded in §6-D1 of this file | `e:3x3.E2-RUN1`, `e:3x3.E2-RUN2` | §6-D1 (resolved), `3x3.C3`'s run size | 0 | ? |
| `QA-010` | QA-010 | all | **Alias of `GLOBAL.ONEMISMATCH`.** "PSK's non-Markovian / Markovian mismatch explains C2, C3, C4 and the collapse" — an interpretation, not a theorem | CLAIMED | `critique-2026-07-28.md:368`; `PROGRESS.md:169-183` | `d:GLOBAL.ONEMISMATCH` | framing only | 0 | ? |
| `QA-011` | QA-011 | all | **Alias of `GLOBAL.H1`.** "Under simple ko the state `(position, side, ko_point)` is Markovian, so the table is chainable by construction" | CLAIMED | `critique-2026-07-28.md:369`; `open-hypotheses:30-118` | `d:GLOBAL.H1` | `QA-023` (the rule-complete restatement) | 0 | ? |
| `QA-012` | QA-012 | all | Values converge as the ko-history dial `j`/`k` increases, and the `j`→`j+1` delta **measures** residual suboptimality. Requires ≥2 affordable rungs. **EXP-8 (2026-07-29, Kimi-k2.7) built the divergence harness + perturbation calibration (`docs/research/psk-divergence-2026-07-29.md`), but the new-rule-vs-PSK value divergence is BLOCKED on the new-rule tables (EXP-4/5/6, behind EXP-2B); the numbers it produced (2×2 random: 28/56 value divergences, 50% CI [0.37,0.63]) compare the existing PSK table against history-exact PSK — the C2 history-dependence gap in reachable play, NOT the rule-divergence gap.** | UNTESTED | `critique-2026-07-28.md:370`; `roadmap-2026-07-28.md:302-307`; `docs/research/psk-divergence-2026-07-29.md`; `docs/evidence/QA-012/` | `d:QA-023`, `d:QA-026` | the measured-gap deliverable | 0 | ? |
| `QA-013` | QA-013 | all | **Alias of `GLOBAL.LONGCYCLE`.** "Long cycles under simple ko can be resolved as a loopy-game fixpoint with loops pinned to the tie value" — highest design risk in the roadmap; must not reintroduce score-on-cycle. **FALSIFIED at 3x2 2026-07-29: the tie-pinned loopy-game fixpoint over-pins TIE where the true value is the static pass-out score. The register's own 'highest design risk' annotation was correct.** | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2b-6-full-review-2026-07-29.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `critique-2026-07-28.md:371`; `open-hypotheses:92-103` | `d:GLOBAL.LONGCYCLE` | `QA-023`, `QA-026` | 0 | ? |
| `QA-014` | QA-014 | 4×4 | A per-node Bellman-identity check (~16 lookups) lets the player refuse **exactly** when its rule is undefined | UNTESTED | `critique-2026-07-28.md:372`; `ko-sensitive-chainability.md:24-33` | `d:GLOBAL.CHAIN-LH`, `e:4x4.GTP-DEFECT` | `GLOBAL.H5` player fork, the certification deliverable | 0 | ? |
| `QA-015` | QA-015 | n/a | Per-board independence should distinguish *empirical* claims (never inherit) from *structural / code* claims (inherit, with the argument written down) | CLAIMED (**DECIDED 2026-07-28** — D-2, Opus + GLM; the rule now lives in ADR-0016, and `mixed` was **not** ruled on) | `critique-2026-07-28.md:373`; `docs/decisions/0016-per-board-independence-empirical-vs-structural.md` | — | `GLOBAL.ADR0016-INHERIT`, §5 inheritance audit, the pending `AGENTS.md` amendment | 0 | ? |
| `QA-016` | QA-016 | 4×4 | "`data/oracle-4x4-parallel.checkpoint.wzo` can state the 4×4 answer" — refuted: `vb[empty] = −128` (UNDEF) by byte inspection, the **root** is unfilled. "99.8% complete" measures the wrong thing when the missing slot is the root | FALSE | `critique-2026-07-28.md:374`; `arena-4x4-undef.md:20-26` | `e:4x4.PARALLEL`, `e:CODE.UNDEF` | roadmap §4 P4 (fitness, not percentage) | 0 | ? |
| `QA-017` | QA-017 | 3×3/4×3/4×4 | The engine steers **into** the unchainable region: `mixed` policy — engine-to-move nodes 21.24% flagged, nodes it *creates* 47.33%; 4×3 31.49/49.13; 3×3 38.76/59.00 | CLAIMED | `critique-2026-07-28.md:375`; `reachable-kosensitivity-2026-07-28.md` | `e:GLOBAL.CHAIN-KO`, `e:4x4.M4` | `4x4.GREEDY-BIAS`, `GLOBAL.H2` | 0 | ? |
| `QA-018` | QA-018 | all | **Alias of `GLOBAL.F2`.** "The bracket-guided finisher (F2) is sound" — recorded ORPHANED (O1) at source: it derives from "brackets hold under ANY arrival history" (`0010:16-18`, `src/retro.zig:464`), which is C3. **Adjudicated 2026-07-28 (D-5, Opus → ADR-0015): the orphan is real — the fresh-start-root defence fails, because the finisher's own search path from an empty-board root is a real game line. The burden is on ADR-0010 and is undischarged; the row stays orphaned. EXP-10 (2026-07-29, Fable 5) attempted to refute ADR-0015 and FAILED (ADR-0017): the orphan **stands**. A three-seat blind review (`QA-018-REVIEW-A/B/C`) returned **unanimously** that ADR-0017's verdict is SOUND; **ADR-0018 (the human's `QA-018-RULING`, 2026-07-29) confirms the orphan.** F2 stays CLAIMED-and-orphaned; the finisher remedy is a new task (`F2-REMEDY`), not a brackets-off regen** | CLAIMED | `critique-2026-07-28.md:376`; `0010:16-18`; `src/retro.zig:464`; `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`; `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md`; `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md`; `untracked/msg/milestone-01-ko-reframe/025-fable-to-all.md` | `d:GLOBAL.F2`, `e:GLOBAL.ADR0015-BURDEN` | every shipped ko-sensitive value | 0 | ? |
| `QA-019` | QA-019 | all | "ADR-0013 Track A (`memo_writes=false`) escapes `QA-018`" — refuted: `bracketed` and `memo_writes` are independent and `saveArtifact` hardcodes `bracketed=true`; the 1.67% writes-off floor is **also** bracket-derived | FALSE | `critique-2026-07-28.md:377`; `src/retro.zig:2407` | `e:GLOBAL.F3`, `e:4x4.M6-FLOOR` | Track A scope, `4x4.F3`, artifact promotion | 0 | ? |
| `QA-020` | QA-020 | 3×3/4×3/4×4 | "The 4×4 engine can certify some of its own moves in self-play" — refuted: **0%**. 14 plies, 7,000/7,000 nodes flagged, one distinct game line, 144 tie-break variants find no certifiable node. Same at 4×3 | FALSE | `critique-2026-07-28.md:378`; `reachable-kosensitivity-2026-07-28.md` | `e:4x4.M5`, `e:GLOBAL.CHAIN-LH` | `GLOBAL.H5a` ("sound but weak"), the certification deliverable | 0 | ? |
| `QA-021` | QA-021 | 4×4 | FP1 acceptance check 3 passes **exhaustively** at 4×4 on the shipped `vb`/`vw` columns: 48,599,962 slots, 422,990 violations, **all** KO_SENSITIVE, **zero** outside, 87 s. Upgrades `4x4.FP1-C3`'s 1:37 sample. Does **not** cover `lo`/`hi` — WZO1 has no bracket columns | PROVEN | `critique-2026-07-28.md:379`; `ko-sensitive-chainability.md:109,116` | `e:4x4.M4` | `4x4.FP1-C3`, `GLOBAL.H4b` (discharged), `GLOBAL.H4` (gap (b) closed, gap (a) open) | 0 | ? |
| `QA-022` | QA-022 | n/a | "Load-bearing evidence for T13, T02/B1, T07 and B05 is retrievable" — refuted: all four were cited under git-ignored `untracked/`, all deleted, none ever in git. T13's numbers survive; its probe source does not | FALSE | `docs/evidence/README.md`; `critique-2026-07-28.md:380`; §7 of this file | `e:3x2.T13` | roadmap §4 P1, §7, `weizigo-claimlint` C2/C3 | 0 | ? |
| `QA-023` | QA-023 | all | Under basic ko + a **fixed-value** long-cycle verdict, `(board, side_to_move, ko_point, passes)` is a sufficient **Markovian** state for exact solving — the score-on-cycle path-dependence does not apply, because a constant verdict is not a function of *which* board repeated. **Load-bearing for the whole roadmap.** Its central obligation is to distinguish itself from `GLOBAL.R2` (score-on-cycle ≡ PSK) and `GLOBAL.RPLY-TRAP` (the cycle terminal drags history back into the key); **no `depends-on` edge is written deliberately** — writing one would prejudge which of those two it stands or falls with, and EXP-2 Part A is what decides | CLAIMED | `roadmap-2026-07-28.md:302`; `docs/evidence/QA-023/proof.md` (Part A; the computational half is 2×2-only, which `EXP-2-AUDIT-PREREG.md` rejects outright as INCOMPLETE). EXP-2A done 2026-07-28 (Fable 5; REPAIRABLE-GAPS→repaired); EXP-2B (the 3×2 computational half) COMPLETE 2026-07-29 via 2B-0…2B-6. **DO NOT MARK THIS ROW FALSE. The computational half SPLITS: C1 (this row's actual assertion — state-sufficiency) is UNTESTED-FOR-WANT-OF-CONTRAST, because the history generator misses the shortest arrival in 93% of states and its histories share ~62% of prefixes (`2B-3-AUDIT`); C2 (that the common value equals `median(L,TIE,H)`) is FALSIFIED — but C2 is `QA-026`'s content, NOT this row's. C2's failure is not evidence against state-sufficiency: on every eligible state all within-budget histories agree, including on the six C2 counterexamples. The reference-semantics §1 restatement conjoins C1 and C2, so §1-as-a-whole is false; that is a fact about the restatement. Adjudicated by 2B-6 (independent) confirming the Orchestrator: `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`.** Note also that the 2B-4 probe numbers (390/1080) were artefacts of a σ-in-arrival defect, 1,133/1,133 collisions (`docs/evidence/QA-023/probe-defect-2026-07-29/`) | — (deliberate — see the claim) | `QA-012`, `QA-026`, `QA-027`, EXP-4…EXP-8, the whole roadmap | 0 | ? |
| `QA-024` | QA-024 | 3×3/4×3/4×4 | PSK binds beyond basic ko at a negligible rate in real play, for repeats that are **not** ko cycles. **Legality half measured by EXP-1 (0 binding). Value half: EXP-8 (2026-07-29) built the harness but the new-rule-vs-PSK value divergence is BLOCKED on new-rule tables (EXP-4/5/6); the PSK-vs-history-exact-PSK numbers EXP-8 produced quantify the C2 history-dependence gap, not this claim.** | CLAIMED | `roadmap-2026-07-28.md:303`; `psk-binding-rate-2026-07-28.md:366-380` (EXP-1: consistent at exactly zero, with a recommended re-scoping); `docs/research/psk-divergence-2026-07-29.md` (EXP-8: harness built, value half blocked) | — | the measured-gap deliverable | 0 | ? |
| `QA-025` | QA-025 | all | **Alias of `GLOBAL.MIGOS-RULE`.** MIGOS II is a *program*, not a ruleset; its ruleset is Chinese area scoring + basic ko + long-cycle ties | PROVEN | `roadmap-2026-07-28.md:304`; `retrograde-3x3.md:222-241` | `d:GLOBAL.MIGOS-RULE` | every anchor comparison, `QA-023` | 0 | ? |
| `QA-026` | QA-026 | all | The existing L/H `converge` machinery is directly reusable under a fixed-value cycle rule, with loops pinned by **`V = median(L, T, H)`** — not v1's false `L<H ⇒ V=T` (the proof-v2 §5.3 gadget falsifies it; corrected in the F2-REMEDY design, 2026-07-29). **FALSIFIED at 3x2 2026-07-29 (2B-PROBE-FIX, independently confirmed by 2B-6): six states — all White-to-move, passes=1, no ko — where `median(L,TIE,H)` pins TIE=0 while the history-conditioned value is the pass-out `area_score` (+1, +3 or -6). proof-v2 Thm 5.1 is therefore FALSE as stated. Per-board scope: 3x2.** | FALSE-AS-SCOPED | `docs/evidence/QA-023/probe-fix-2026-07-29.md`; `docs/audits/2b-6-full-review-2026-07-29.md`; `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `roadmap-2026-07-28.md:305`; `docs/research/f2-remedy-design-2026-07-29.md`; `docs/evidence/QA-023/proof-v2-2026-07-28.md` | `d:QA-023`, `d:GLOBAL.LONGCYCLE`, `e:docs/evidence/QA-023/proof-v2-2026-07-28.md` | EXP-4, any simple-ko build, the F2-REMEDY median build | 0 | ? |
| `QA-027` | QA-027 | all | Under a Markovian rule the certified fraction is **100% by construction** — and it is a falsifier, not a formality | CLAIMED | `roadmap-2026-07-28.md:306` | `d:QA-023` | EXP-7, the certification deliverable | 0 | ? |
| `QA-028` | QA-028 | all | Opus's "Reading A" history-window ladder (`critique-2026-07-28.md` §5) is tractable — **withdrawn**: `RETRO_PLY` already falsified it, and the cycle terminal drags the full history back into the memo key | FALSE | `roadmap-2026-07-28.md:307`; `ruleset-options.md:42-71` | `e:GLOBAL.RPLY`, `e:GLOBAL.RPLY-TRAP` | representation fork | 0 | ? |

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
      ⟵d 3x3.F2 ⟵d GLOBAL.F2 ⟵d GLOBAL.C3   [FALSE at 3×3 — same board]
      ⟵d GLOBAL.F1                            [FALSE-AS-SCOPED]

Sharpest instance: the 3×3 table is finisher-produced with bracket cuts, and
3×3 is the very board where the bracket was shown not to bound. `PROGRESS.md:210`
still lists 3×3 C1 as a `TODO` to promote, not as debt.

**O4 — `4x4.ANCHOR` used as validation · MEASUREMENT quoted as support**

    "empty(B) 4×4 = +2 matches the published anchor" (retrograde-4x4.md:74-84)
      quoted in support of 4x4.C1
      ⟵d GLOBAL.P1 ("anchor match ⇒ real-game correctness")  [FALSE-AS-SCOPED]
      and produced by an artifact ⟵d GLOBAL.F1                [FALSE-AS-SCOPED]

The measurement stands; its use as validation is orphaned. `4x4.CYCLE-INSENS`
("the 4×4 empty-board score is evidently cycle-rule-insensitive",
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

**O6 — `GLOBAL.ADR0012-GATE` (the sha256 regression gate) · CLAIMED**

    0012:46-49,157-159 — "must reproduce the 4×4 artifact BYTE-IDENTICAL
      (sha256 recorded in retrograde-4x4.md)"
      ⟵d 4x4.COMPLETE-2026-07-21               [orphaned, O5]
      ⟵d GLOBAL.F1                             [FALSE-AS-SCOPED]

The standing pre-big-board gate targets a hash of an artifact generated with the
unsound guard. Reproducing it byte-identically would now be evidence of
reproducing the bug.

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
| 5 | `GLOBAL.LONGCYCLE` — "long cycle = tie" is a computable loopy-game fixpoint | UNTESTED | 4: `GLOBAL.H1`, `GLOBAL.H1-CENSUS` interpretation, any simple-ko build, the post-PSK roadmap | H1's census can return GO and still leave the project unable to build anything: `open-hypotheses:92-103` states plainly that this "is UNVERIFIED and must not be asserted", and `GLOBAL.R2` forecloses every resolution rule that needs to know which earlier boards were seen |

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

`AGENTS.md:8-13` and `CONCEPTS.md:65-71` forbid using a claim at one board size
as evidence at another. The project also inherits when convenient. Both are
recorded below. **Kind** is this register's reading of *what the inherited thing
is about*, offered as a starting point only:

- **structural** — the inherited statement is about code or mathematics, so
  "board size" may not be the right unit of scope at all. Plausibly legitimate.
- **empirical** — the inherited statement is about a board. Forbidden by the
  rule as written.
- **mixed** — a structural claim whose only evidence is empirical, at other
  sizes.

**No ruling is made** on any individual row below. The user and Opus decide.

**2026-07-28 — the *rule* is now ruled on, the rows are not.** D-2 (Opus + GLM)
found the per-board-independence rule as stated to be **mis-stated**, and
**ADR-0016** replaces it: *empirical* claims never inherit; *structural*
claims — code or mathematics — may, **with the inheritance argument written
down**, and a status does not upgrade on inheritance. The `kind` column below is
therefore the operative classification rather than a suggestion. Two limits,
stated because they are easy to over-read:

- **`mixed` was NOT ruled on** (I3, I4, I18, I19) and **cross-ruleset** (I24) was
  not either. Both fall under the empirical default: no inheritance is licensed.
- **Each row still needs its argument written down, or its inheritance
  withdrawn**, by the owner of the board file it lives in. ADR-0016 does not
  discharge a single row below, and this register still does not adjudicate them.

| # | claim | what was measured, where | what was inherited, to where | kind | self-flagged? |
|---|---|---|---|---|---|
| I1 | `4x4.F1` | `ko_ref ≥ d` guard: **45/378** auditor violations at **3×2**, 0 with writes off (`consistency-audit.md:25-34`) | Asserted at **4×4**: "the guard is the same code at 4×4; the bug is structural, not size-dependent" — and the 4×4 auditor sample **did not finish** (`4x4/EPISTEMIC.md:49-52`) | **structural** (a claim about a source-level guard) | yes — listed under Falsifications with the caveat |
| I2 | `4x3.F1` | same 3×2 measurement | Asserted at **4×3**: "the same unsound guard used to generate the committed 4×3 artifact" (`4x3/EPISTEMIC.md:35,48-50`) | **structural** | yes |
| I3 | `4x4.R1` | PSK exact-solve: **118,475,182** ban-set states on the empty **2×2**, budget-exceeded (`ruleset-options.md:91`) | Asserted at **4×4** as "R1 ✅ PSK intractable (structural; measured at 2×2)" (`4x4/EPISTEMIC.md:22`) and globally as a foreclosure (`AGENTS.md:47-49`) | **mixed** — the growth argument is structural, the evidence is one board | partially (the parenthetical names the size) |
| I4 | `GLOBAL.R2` | score-on-cycle vs PSK: byte-identical state counts at **2×2** and **3×2** only; 3×3/4×3 rows OOM'd (`ruleset-options.md:163-174`) | Foreclosed **globally and at every size**: "not a coincidence, a proof of structure" (`AGENTS.md:52-53`) | **structural** (an argument about the recursion tree, with two-board evidence) | the note argues structurally; the foreclosure does not restate the scope |
| I5 | `4x4.S4` | `rules.area_score` cross-validated at smaller sizes (500 boards vs `terminal.zig`, `0008:63-66`) | Area scoring asserted correct at **4×4** | **empirical** | yes — explicitly downgraded to `⬜ᴵᴺᴴ` with a TODO |
| I6 | `4x3.S4` | same | Area scoring asserted at **4×3** | **empirical** | yes — `⬜ᴵᴺᴴ` |
| I7 | `4x3.S1` | Colex bijection exhaustively round-tripped **through 4×4** | Asserted **✅ PROVEN** at 4×3: "4×3 raw space is smaller … and inherits the same structural proof" (`4x3/EPISTEMIC.md:24`) | **structural** (mixed-radix layout is size-generic) | the reasoning is stated; the status is nonetheless ✅ |
| I8 | `4x3.S2` | Benson's theorem (mathematics) | Asserted **✅ PROVEN** at 4×3: "holds for all finite boards" | **structural** | yes — CONCEPTS.md:10-12 explicitly authorises theorem inheritance |
| I9 | `4x4.C3` | **C3 falsified at 3×3** (E2, 25/4000 games, promise +3 → final −9) | Asserted at **4×4** as "**analogy-expected falsified**, NOT an open hypothesis"; the deliverable decision is told not to wait for a 4×4 run (`4x4/EPISTEMIC.md:55-66`). The **4×3 file refuses the identical inheritance**: "per-board independence forbids importing the 3×3 result" (`4x3/EPISTEMIC.md:34`) | **empirical** | partially — the 4×4 file argues from semantics ("PSK removes moves; lo only pessimises cycles") but records the status as inherited |
| I10 | `4x4.C2` | **C2 falsified at 3×2** (T13, 12/508) | Asserted at **4×4**: "4×4 falsification is analogy-expected, **not an open hypothesis**" (`4x4/EPISTEMIC.md:46,98`), while `PROGRESS.md:212-213` lists C2 at 4×4 as an untested TODO citing per-board independence | **empirical** | contradictorily — flagged in one file, inherited in another (§6-D3) |
| I11 | `4x4.C2` corroboration | 4×4 arena: **176 single-score + 300 ko-sensitive real divergence events** (`arena-4x4-undef.md:87-91`) | Quoted as "corroborates history-dependence **at scale**" (`PROGRESS.md:127`) | **native to 4×4** — not an inheritance; recorded here because it sits beside I10 and is the only 4×4-native C2 evidence | n/a |
| I12 | `GLOBAL.C4` | The leak, measured at 2×2/3×2/3×3/4×4 | Asserted at 4×4 as "❌ **structural**" (`4x4/EPISTEMIC.md:26`) | **structural** (true by construction on ko-sensitive slots: a fresh-start value is defined under an empty history) | yes — tagged "(structural)" |
| I13 | `4x4.P3` | Arena leak **8–16%** measured on the 2×2/3×2 tables (`4x4/EPISTEMIC.md:53-54`) | Listed as a 4×4 Falsification, with 2×2/3×2 evidence, in the 4×4 tree | **empirical** | no — the entry names the other boards but files the fact under 4×4 |
| I14 | `GLOBAL.P1` | — | "anchor ≠ real-game correctness (**structural**)" (`4x4/EPISTEMIC.md:24`) | **structural** (a logical claim about what an anchor can attest) | yes |
| I15 | `4x4.FP3` | Knaster–Tarski on a finite lattice | Asserted at 4×4 as `⬜ᴵᴺᴴ` — **not** re-derived as a 4×4 claim. The **4×3 file marks the identical claim ✅ PROVEN** with the identical justification | **structural** | yes at 4×4, no at 4×3 — inconsistent handling of the same theorem (§6-D4) |
| I16 | `GLOBAL.MAXGAP` | Worst misprice = 2n at **3×2, 3×3, 4×3, 4×4** (12/18/24/32); 2×2 is the exception | Stated as a CLAIMED regularity "for every board with n ≥ 6", with an explicit refusal to carry it to 5×5 | **empirical** (a cross-size generalisation over four boards) | yes — "no proof offered; per-board independence forbids extrapolating it to 5×5" |
| I17 | `GLOBAL.SWEEPS` | Sweep counts 2/6/12/19 and falling ko-sensitive fractions at 2×2→4×4 | "Both trends are **favourable for 5×5**" (`retrograde-4x4.md:30-32`); `GLOBAL.ADR0012-5X5` builds a feasibility projection on them | **empirical** cross-size extrapolation — precisely the "this suggests X at larger boards" pattern `AGENTS.md:11-13` names | no |
| I18 | `GLOBAL.ADR0006-EYE` | Argued from area-scoring theory; direct validation cited at **one** position (`dead_white` = Black +25, `0006:59-61`) | Applied at **every** board size, in every forward search, as a soundness precondition | **structural** (argument) with a thin empirical base | the ADR states the argument; ADR-0009:118-123 supplies the standing indirect test |
| I19 | `GLOBAL.ADR0012-PAR` | Chaotic-iteration theory for monotone maps; **no measurement cited** | Asserted for all parallel builds at all sizes, and used to justify final-hash verification under threads | **structural** | no |
| I20 | `GLOBAL.F4` | `deps` mode validated at **3×2, 3×3, 4×3** (0 auditor violations, byte-identical to writes-off) | **NOT** inherited: `4x4.F4` is correctly marked ⬜ UNTESTED with a byte-compare experiment specified | — | **compliant example**, recorded to show the rule being honoured |
| I21 | `4x4.M6` ratio | ≈2.4× writes-on/writes-off excess at **4×4** | **NOT** carried anywhere: "per-board independence forbids carrying the 2.4× ratio to any other size" | — | **compliant example** |
| I22 | `4x3.S2-impl` | "S2-4×4 implementation regression (`rules.zig` vs naive) passed for ≤8 stones" | **Refused** at 4×3: "4×3 not explicitly run" | — | **compliant example** — but the cited 4×4 pass contradicts `4x4.S2-impl`'s own UNTESTED status (§6-D6) |
| I23 | `3x2.T13` → `GLOBAL.C2` | 12/508 mismatches at **3×2** | Promoted to a **global** foreclosure: "the single-score region is NOT history-independent … settled false at the smallest testable board" (`AGENTS.md:68-73`) | **empirical**, promoted to global | the foreclosure names the board; the framing ("settled") does not scope the conclusion |
| I24 | `4x4.CYCLE-INSENS` | 4×4 empty-board score +2 agrees with MIGOS II, which plays a **different ruleset** (basic ko + long-cycle-ties) | Inferred: "the 4×4 empty-board score is evidently **cycle-rule-insensitive**" (`retrograde-4x4.md:77-80`) | **cross-ruleset**, not cross-board — a fourth kind the rule does not name. One agreement; the same comparison **disagrees** at 2×2 and 3×2 | no |
| I25 | `GLOBAL.ADR0005-CACHE` → `GLOBAL.ADR0008-HOLE` → `GLOBAL.F1` | The `ko_ref ≥ d` rule stated as a **theorem** (`0005:90-93`), downgraded to "sound-in-practice compromise, not a theorem" (`0008:34-38`), then falsified (`0013`) | Not a board inheritance but a **status inheritance**: every artifact persisted between 2026-07-15 and 2026-07-23 was written under the theorem-strength reading | — | the downgrade is explicit in ADR-0008; the artifacts written under the stronger reading were not re-labelled at the time |

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
`4x3/EPISTEMIC.md:34` refuses the identical inference for 4×3 ("per-board
independence forbids importing the 3×3 result").
`CONCEPTS.md:57-61` states both at once: "**falsified at 3×3 by analogy-expected
falsified at 4×4**" — a sentence that does not parse and appears to be a merge
artifact. Two board files apply opposite rules to the same inheritance.

**D3 — C2 at 4×4: not-an-open-hypothesis vs open TODO.**
`4x4/EPISTEMIC.md:46,98` — "4×4 falsification is analogy-expected, **not an open
hypothesis**"; `4x4/EPISTEMIC.md:329-331` — "No further C2-probe needed at 4×4".
`PROGRESS.md:212-213` — "`TODO` (C2 at 3×3/4×4): **untested**. Falsified at 3×2
(T13), per-board independence prevents inheritance."
`4x3/EPISTEMIC.md:33` — "Do not inherit the 3×2 falsification as a 4×3 result."
Three documents, three positions.

**D4 — FP3 status differs between board files with identical justification.**
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

| board | census (`retrograde-3x3.md`, `ruleset-options.md`, `M1` rows) | chainability sweep (`ko-sensitive-chainability.md:50-54`) |
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
space, while the walk counts **reachable from the empty board under alternating
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
| `untracked/T13-minimax.md` | `leak-crisis.md:25,109`; `c2-falsification-3x2.md:4,134` | **missing** |
| `untracked/c2pilot_3x2.zig` (the C2-probe source) | `c2-falsification-3x2.md:21,127,133` | **missing** |
| `untracked/T12-minimax.md` (C2-pilot-2×2) | `4x4/EPISTEMIC.md:287-288` | **missing** |
| `untracked/T02-minimax.md` (B1 least-fixpoint results) | `leak-crisis.md:103,180` | **missing** |
| `untracked/T02-audit-kimi.md` (the audit convicting (a′)) | `leak-crisis.md:104,180` | **missing** |
| `untracked/T07-audit-hypotheses.md` (the eight findings that rewrote the 4×4 tree) | `4x4/EPISTEMIC.md:12` | **missing** |
| `untracked/B05-glm.md` (the reframe scope) | `PROGRESS.md:277`; `leak-crisis.md:145,151`; `4x4/EPISTEMIC.md:269` | **missing** |
| `untracked/B39-arena4x4.md` | `arena-4x4-undef.md:11-14` (records its own deletion by B44) | **missing** |
| `untracked/discussion.md`, `untracked/idea-heap.md` | `AGENTS.md:169-171` | **missing** (2026-07-25 copies survive in `untracked/archive/`) |

Consequences for the register, stated without recommendation:

- **`3x2.T13` is not reproducible.** Its numbers, method, ban-set distribution
  and all 12 contradiction lines survive in git at
  `docs/research/c2-falsification-3x2.md` — that durable copy is why the row is
  marked PROVEN — but the probe source is gone, so the reproduction block at
  `c2-falsification-3x2.md:124-129` cannot be executed.
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
- **Do not resolve §5 or §6 in this file.** Resolutions belong in an ADR
  (append-only) or in the owning board's `EPISTEMIC.md`; this file then updates
  the status and cites the resolution.
