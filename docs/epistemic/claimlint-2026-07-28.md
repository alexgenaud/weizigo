# claimlint — making `CLAIMS.md` check itself

**Created:** 2026-07-28. **Tool:** `src/claimlint.zig`, built as
`weizigo-claimlint` (`zig build`, then `./zig-out/bin/weizigo-claimlint` from
the repo root). **Owner of this file:** the claimlint agent.

`CLAIMS.md` is a static snapshot. It was built by reading documents at one
moment and nothing kept it true afterwards. This project has already been
destroyed that way once: claims marked PROVEN cite evidence files that were
deleted (`docs/evidence/README.md`), and the C3 falsification failed to
propagate to its dependent F2 for weeks because propagation was manual
(`critique-2026-07-28.md` §4 M-F0).

**"More discipline" is the answer that already failed.** This is the check
instead. It runs in about a second, it exits non-zero, and every one of its
checks maps to a failure this project actually suffered — not to formatting.

**Revised twice on 2026-07-28**, after review. First the register was missing an
edge kind (§9); then the corrected sweep exposed a second class, `d:` edges that
dead-end on a measurement (§10). Both changed the headline. What follows is the
corrected state.

**Revised a third time on 2026-07-28**, after the D-1…D-5 promotion pass added
eight register rows. **The counters below moved, and one of them moved for a
reason worth knowing: this document's own earlier numbers disagreed with each
other** (11 vs 12 dangling paths; 61 vs 65 vs 77 vs 51 unreferenced rows). §11 is
the reconciliation and **the live tool output is the authority — not this
prose.** Where a number below is a snapshot, it says so.

**Headline: the register does not pass its own standard.** **10** live claims
derive from a falsified one — 23 before the `n:` audit removed 14 false
positives, then +1 when the shadow sweep found a real one that had been hidden
all along. Eight of the ten are one family. **10** cited evidence paths are
dangling (9 missing + 1 that exists but is git-ignored) — see §11 for why this
was written as 11 and as 12 in different places, and why it is not stable.
**79 of the register's 82 PROVEN rows fail the roadmap's P1 rule that a PROVEN
claim's evidence must be committed under `docs/evidence/`.** It was **79 of 79 —
every single one** — until 2026-07-28, when EXP-3's three `H1-CENSUS` rows became
the first Tier A entries in the project's history. 78 PROVEN rows have never had
the discriminating power of their test computed.

---

## 1. What the tool checks, and which past failure each check is

| check | what it flags | the failure it would have caught | fails the run? |
|---|---|---|---|
| **C0** | a register row the parser cannot read | a linter that silently skips rows is worse than none | yes (exit 3) |
| **C1a** | PROVEN/CLAIMED claim with a transitive `d:` ancestor that is FALSE-AS-SCOPED or FALSE | **O1.** `GLOBAL.F2` (the finisher behind every shipped ko-sensitive value) derives from `GLOBAL.C3`, falsified at 3×3 on 2026-07-23. The project wrote both halves of that sentence in two different documents and did not join them for weeks | yes (exit 1) |
| **C1b** | an `n:` (derives-from-negation) edge whose parent is **not** FALSE | **The inverse, and it has no precedent because nothing could express it.** `GLOBAL.REFRAME` — the current deliverable — exists *because* C2/C3/C4 are false. If any were rehabilitated, the reframe and everything under it would need re-examining and nothing would say so. See §9 | yes (exit 1) |
| **C2** | a cited file path that does not exist — in the evidence column (**C2a**), inside the documents the evidence cites (**C2b**), or an evidence document that exists but is git-ignored (**C2c**) | **The T13 class.** `c2-falsification-3x2.md:124-129` gives a reproduction command whose `-Mmain=untracked/c2pilot_3x2.zig` input was deleted. The falsification the entire reframe rests on can be read but not re-run | yes (exit 1) |
| **C3** | PROVEN claim whose evidence does not resolve under `docs/evidence/` | `roadmap-2026-07-28.md` §4 **P1**. On 2026-07-27 a cleanup bundle swept 57 scratch files, taking the primary evidence for T13, T02/B1, T07 and B05. A claim whose evidence cannot be retrieved is not proven; it is remembered | no — debt list |
| **C5** | a `d:` edge whose parent is a MEASUREMENT row or a definition | **O3, and it was invisible.** `3x3.C1` carried `d:3x3.F2`, and `3x3.F2` measures only that the finisher *completed* 622 reps. Completion is not soundness. The measurement dead-ended the chain, so the falsification of `GLOBAL.C3` never reached the 3×3 table — the case §4.1 calls the sharpest | no — report |
| **C4** | a claim ID cited in `docs/` with no register row; `QA-nnn` namespace coverage; register rows nothing references | a falsification cannot propagate to an ID the graph cannot see — O1 with a different prefix. This check found the whole `QA-nnn` namespace, now imported (§9.3) | no — report |
| **A** | `narrowed >= 2` → `SMELL: repeated narrowing — the representation may be wrong, not the claim.` | **The retreat ladder.** Single score → bracket → fresh-start-only (`critique-2026-07-28.md` §2). Three locally-honest reclassifications, and the project was solving nothing | no — report |
| **B** | PROVEN claim whose `wrong-answer-pass-rate` is above 25% or `?` | **Weak evidence recorded as confirmation.** Anchor agreement, cycle-rule insensitivity and bracket containment would each have been passed by a *wrong* answer 40–70% of the time (`critique-2026-07-28.md` §3) | no — report |

**Deliberately not implemented:** anything that merely enforces formatting.
There is no check for column alignment, heading style, citation punctuation or
`—` vs `-`. If a check cannot name a dated incident, it is not in the tool.

### Parsing

The register is a markdown table split on `|` that is not backslash-escaped —
`CODE.ADR0011-FMT` contains a literal `vb\|vw\|fb\|fw\|db\|dw`, and a naive
split mangles that row. **A row the parser cannot read is reported by ID and
line number and exits 3.** It is never skipped. The unparsed count is printed
first, before any finding, so it cannot be missed.

Evidence citations are not repo paths — the column writes `4x4/EPISTEMIC.md:17`,
`0009:65-67`, `open-hypotheses:63-88`, `../status/leak-crisis.md`. Resolution is
therefore a tolerant search over a full repo file index: exact path, trailing
path-component match, `docs/decisions/<nnnn>-*` for a bare four-digit ADR
number, basename match, then basename-prefix match. A token is only *reported*
as missing if it is path-shaped (carries a known file extension); prose,
ratios (`45/378`), shorthand (`V0/V1`) and git hashes are skipped rather than
reported. A dangling-evidence check that cries wolf on prose gets switched off,
and then it is worth nothing.

---

## 2. Calibration — did C1 rediscover O1 unaided?

**Yes.** `GLOBAL.F2` is reported by C1a from the register alone, with
`GLOBAL.C3` in its chain. The tool has no knowledge of §4.1; it walks
`derives-from` edges and reads statuses.

Seven calibration cases run at the end of **every** invocation, and a
calibration failure exits non-zero on its own (exit 2) regardless of what else
the run found. `GLOBAL.CALIB-LESSON` / roadmap §4 P3: an auditor with no
*passing* case cannot distinguish "bug" from "definition", and this project
has already shipped an uncalibrated auditor once and paid a session for it.

```
== CALIBRATION (GLOBAL.CALIB-LESSON; roadmap §4 P3) ==
A checker with no failing case proves nothing.

  known-bad 1 (C1): `GLOBAL.F2` must be reported with `GLOBAL.C3` in its chain … CAUGHT
  known-bad 2 (C2): `untracked/c2pilot_3x2.zig` must be reported … CAUGHT
  known-good (C1+C2): PROVEN `GLOBAL.ADR0003-AREA` with a real evidence path must be silent … SILENT (correct)
  known-good (C1, `n:`): `GLOBAL.REFRAME` — `n:` to a FALSE parent must be silent … SILENT (correct)
  known-bad 3 (C1b, synthetic): `n:` to a PROVEN parent must ALARM, `n:` to a
                FALSE parent must not … CAUGHT (1 alarm, 1 silent)
  known-bad 4 (C5, synthetic): `d:` onto a MEASUREMENT must be reported, `d:`
                onto a real claim must not … CAUGHT (1 shadow, 1 silent)
  known-good (C5): `GLOBAL.F2` — every `d:` parent is a real claim, must be silent … SILENT (correct)

  calibration: PASS
```

`GLOBAL.ADR0003-AREA` is the known-good: PROVEN, evidence
`0003:13-16,21-24` → `docs/decisions/0003-ruleset-chinese-area-and-positional-superko.md`,
which exists, is committed, names no missing reproduction input, and has no
`derives-from` ancestor at all. It produces no C1 and no C2 finding. (It still
appears in the C3 debt list — Tier B — and that is correct, not a checker bug:
an ADR is a record of a decision, not a re-runnable probe.)

**The ALARM half of C1b cannot be exercised by real data** — today every `n:`
edge points at a parent that really is false, which is the healthy state. So
the binary carries a four-row **synthetic register** (two parents, one FALSE and
one PROVEN; two children, one `n:` to each) and runs the whole pipeline — parse,
graph, alarm — on it at every invocation, asserting exactly one alarm and
exactly one silence. Without that, "0 alarms" would be indistinguishable from
"the alarm is unreachable code".

### Five mutation tests — proof the checks are data-driven, not hardcoded

Run on scratch copies of `CLAIMS.md`; the repo file was not modified.

| # | mutation | expected | observed |
|---|---|---|---|
| M1 | flip `GLOBAL.C3`'s status to PROVEN | `GLOBAL.F2` must **disappear** from C1a, the `n:` children of C3 must **ALARM**, and calibration must fail | orphans 9 → 5, `GLOBAL.F2` gone, **2 new C1b alarms** (`GLOBAL.REFRAME`, `GLOBAL.H1`), `known-bad 1 … MISSED`, **exit 2** |
| M2 | delete one cell from the `GLOBAL.RELEASEFAST` row | parse must fail **loudly**, not silently skip | `rows UNPARSED: 1` · `! 447: expected 10 columns, found 9 — GLOBAL.RELEASEFAST` · **exit 3** |
| M3 | replace `3x2.T13`'s evidence with `docs/evidence/3x2.t13/probe-that-does-not-exist.zig` | C2**a** (the evidence-column limb, which real data never trips) must catch it, and C3 must demote the row to Tier C | `MISSING … named in: the evidence column itself`; `3x2.T13` moved from Tier B to Tier C |
| **M4** | **rehabilitate `GLOBAL.C2` — flip it to PROVEN** | **every `n:` edge pointing at it must ALARM** | **4 alarms: `GLOBAL.REFRAME`, `GLOBAL.CHAIN-KIND`, `GLOBAL.H1`, `GLOBAL.H5d`**; orphans 10 → 11; the known-good case correctly detects its own breakage; **exit 2** |
| **M5** | **revert the §10 shadow fix — put `3x3.C1` back on `d:3x3.F2`** | `3x3.C1` must **vanish** from C1a and **reappear** in C5 | orphans 10 → **9**, C5 4 → **5**. The measurement really is what was hiding it, and C5 catches the regression |

M1 and M4 are the important ones for C1. Without M1, "C1a found O1" is
compatible with C1a being a hardcoded string. Without M4, C1b's zero could mean
the check does not work. M1 fires both directions from a single mutation — five
orphans vanish and two alarms appear — the clearest demonstration that the two
checks read the same graph with opposite propagation rules. **M5 is the one that
proves §10**: undo the single edge change and the orphan disappears again, which
is what "the measurement was shadowing the real dependency" means operationally.

---

## 3. Findings by category

**Two runs are quoted in this section.** The **live** one is authoritative; the
**first** one is kept because the narrative below was written against it and
because the delta is itself informative. Every number in the prose that follows
is a snapshot of the first run unless it says otherwise; §11 lists the deltas.

Live run — `bin/weizigo-claimlint`, 2026-07-28 13:2x CEST, after the D-1…D-5
promotion pass:

```
weizigo-claimlint — docs/epistemic/CLAIMS.md
repo index: 449 files · register §2 lines 199–543
edges: 290 total — 122 `d:` derives-from, 152 `e:` evidenced-by, 16 `n:` derives-from-negation

== SUMMARY ==
  rows parsed / unparsed        253 / 0
  C1a orphans / C1b alarms      10 / 0   (FAILS)
  C2 dangling evidence paths    10   (FAILS)
  C3 PROVEN w/o committed evid. 79   (debt only, does not fail yet)   [79 of 82; Tier A = 3]
  C4 dangling IDs / unreferenced 12 / 57   (report only, does not fail yet)
  C5 shadowed dependencies      4   (report only, does not fail yet)
  A  repeated-narrowing smells  5   (report only)
  B  weak-evidence PROVEN rows  78   (report only)
  calibration                   PASS
```

First full run, for the delta (2026-07-28, before the promotion pass):

```
weizigo-claimlint — docs/epistemic/CLAIMS.md
repo index: 434 files · register §2 lines 175–478
edges: 267 total — 119 `d:` derives-from, 134 `e:` evidenced-by, 14 `n:` derives-from-negation

== SUMMARY ==
  rows parsed / unparsed         245 / 0
  C1a orphans / C1b alarms      10 / 0   (FAILS)
  C2 dangling evidence paths     12   (FAILS)
  C3 PROVEN w/o committed evid.  79   (debt only, does not fail yet)   [79 of 79; Tier A = 0]
  C4 dangling IDs / unreferenced 14 / 61   (report only, does not fail yet)
  C5 shadowed dependencies        4   (report only, does not fail yet)
  A  repeated-narrowing smells    5   (report only)
  B  weak-evidence PROVEN rows   75   (report only)
  calibration                    PASS
```

**Exit code 1 on both.** The register does not pass. That is the honest state,
and no status in it was changed to make the run green — not at the first run, and
not in the promotion pass, where every status change cites the ruling or the run
that made it (`CLAIMS.md` preamble amendment).

### C1a — 10 orphans (23 → 9 → 10)

The first run reported 23. Fourteen were the missing-edge-kind artefact
corrected in §9: claims justified by a refutation, recorded as if they derived
from the refuted premise. Then the shadow sweep (§10) added one back — a real
orphan that a measurement had been hiding since the register was written.
**The ten are almost one family.**

| falsified root | orphans reached |
|---|---|
| `GLOBAL.C3` (bracket bounds the real-game score — FALSE at 3×3) | **`3x3.C1`** (new — §10), `GLOBAL.F2`, `GLOBAL.ADR0010-CUT`, `GLOBAL.F3`, `GLOBAL.F4`, `GLOBAL.H5c`, `GLOBAL.B15`, **`QA-018`** (the alias of F2, imported in §2.11 — propagation working on the new rows) |
| `GLOBAL.F1` (writes-on finisher sound — FALSE) | `4x3.C1` |
| `4x4.COMPLETE-2026-07-21` (FALSE-AS-SCOPED) | `GLOBAL.ADR0012-GATE` |

**`3x3.C1` is the headline, not a footnote.** "Fresh-start scores correct at
3×3" is CLAIMED, the 3×3 table is bracket-cut-produced, and **3×3 is the exact
board where the bracket was shown not to bound** (E2, `3x3.C3`). The register's
own §4.1-O3 calls this the sharpest instance and notes that `PROGRESS.md:210`
still lists 3×3 C1 as a `TODO` to *promote*, not as debt. It took a structural
check to make it visible, because the chain ran through a measurement.

**Eight of ten are the O1 family.** After the correction the orphan report is
no longer a list of loosely-related debris; it says one thing: *the bracket
claim is falsified and the entire finisher, at every board size, still stands on
it.* That is `critique-2026-07-28.md` §4 M-F0 and it is unresolved. The
remaining two are `4x3.C1` (whose own row already admits "same buggy finisher
path") and the sha256 regression gate that targets an artifact built with the
unsound guard.

Two notes:

1. **`GLOBAL.H5c` is a deliberate false positive.** "Bracket-cut search is
   tractable but NOT shippable as sound" is half a `d:` claim (the
   *identification* cut ≡ C3 holds either way) and half an `n:` claim (the
   *verdict* "not shippable" requires C3 to be false). The documents do not
   settle which, so it is left `d:` and listed as ambiguous (§9.2). A visible
   false orphan is cheaper than a hidden real one.
2. **§4.1's O3 chain was not in the edge data — now fixed, see §10.**
   `3x3.C1` carried `d:3x3.F2` and `3x3.F2` is a MEASUREMENT, so the chain
   dead-ended and `3x3.C1` never appeared. It appears now.

### C1b — 0 alarms

Every `n:` edge currently points at a parent that really is false, which is the
healthy state. The check is not vacuous — see M4 in §2, where rehabilitating
`GLOBAL.C2` fires four alarms, and the synthetic case that runs on every
invocation.

### C2 — 9 missing paths live (11 at the first run), 1 git-ignored evidence document, 1 bulk artifact

**The live count is 10** — 9 unique missing paths plus 1 evidence document that
exists but is git-ignored. The table below is the **first run's 11**; four rows
have changed status since, and the reasons are worth recording because they show
what the counter is sensitive to:

- **Gone (3):** `docs/engine/RISKS.md`, `untracked/discussion.md`,
  `untracked/idea-heap.md`. All three were reported because **`AGENTS.md` cited
  them**; `AGENTS.md` was rewritten as an 89-line router in another console on
  2026-07-28 and no longer does. The files are still absent — the *citation* went
  away, not the file. Fourteen register rows stopped reaching them.
- **Appeared and vanished within minutes (1):** `dispatch/EXP-N.md`, cited by the
  rewritten `AGENTS.md` read-order table at 13:0x and absent from it by 13:11.
  Two runs eleven minutes apart differed by one on this alone.
- **New (1):** `/tmp/test_census_pure.zig`, named by
  `kostate-census-2026-07-28.md` and reachable from the three new `H1-CENSUS`
  rows. It is EXP-3's independent depth-parity BFS — the cross-check that
  explains away a calibration mismatch — written to `/tmp` and deliberately not
  committed. **This is the T13 mechanism, live.** Recorded as `CLAIMS.md` §6-D18.

| missing path (first run) | named in | register rows that reach it |
|---|---|---|
| `untracked/B05-glm.md` | `4x4/EPISTEMIC.md`, `CONCEPTS.md`, `PROGRESS.md`, `leak-crisis.md` | **95** |
| `untracked/T07-audit-hypotheses.md` | `4x4/EPISTEMIC.md` | 46 |
| `untracked/T02-audit-kimi.md` | `leak-crisis.md` | 22 |
| `untracked/T02-minimax.md` | `leak-crisis.md` | 22 |
| `untracked/T13-minimax.md` | `leak-crisis.md`, `c2-falsification-3x2.md` | 22 |
| `docs/engine/RISKS.md` | `AGENTS.md` | 14 |
| `untracked/discussion.md` | `AGENTS.md` | 14 |
| `untracked/idea-heap.md` | `AGENTS.md` | 14 |
| `untracked/B39-arena4x4.md` | `arena-4x4-undef.md` | 6 |
| **`untracked/c2pilot_3x2.zig`** | `c2-falsification-3x2.md` | 2 (`3x2.C1`, `3x2.T13`) |
| `docs/research/qa023-basicko-markovian-2026-07-28.md` | `docs/infra/dispatch/EXP-2.md` | 1 (`QA-023`) — *not yet written* rather than deleted; EXP-2 is in flight |

Not counted as failures, reported separately:

- **ALREADY INVENTORIED:** 11 further paths are named *only* in
  `docs/evidence/README.md` §"CONFIRMED LOST" — a document whose purpose is to
  record, by name, files that are gone. A path named only there is a recorded
  loss, not a dangling citation. A path named there **and** in a live document
  is still a failure, which is why `untracked/c2pilot_3x2.zig` and
  `untracked/T13-minimax.md` stay in the table above.

- **NOT IN GIT:** `untracked/SUBAGENTS.md`, cited by `GLOBAL.UD-1`. It exists
  today. It is git-ignored, so it is one cleanup sweep from gone — and that
  sweep has already happened once (QA-022). The register row already carries
  "(not in git; see §7)"; the tool now enforces it.
- **BULK:** `data/oracle-4x4.wzo` is named in `4x4/EPISTEMIC.md` and is not on
  disk. `.wzo` files are git-ignored by design and their hashes are recorded in
  `docs/evidence/README.md`, so this is informational — but the artifact behind
  `4x4.COMPLETE-2026-07-21`'s published sha256 is not there.

`docs/engine/RISKS.md` is cited by `AGENTS.md` four times as a live reference
and is marked "⚠ not yet written" in the read-order list. It has fourteen
register rows citing `AGENTS.md` behind it.

### C3 — 79 of 82 PROVEN rows have no committed evidence. Tier A is no longer empty.

| tier | meaning | first run | live |
|---|---|---|---|
| **A** | evidence resolves under `docs/evidence/` — compliant with P1 | **0** | **3** |
| **B** | a committed prose document records the result; no re-runnable probe | **79** | **79** |
| **C** | nothing resolves at all | 0 | 0 |

**Zero of the register's 79 PROVEN claims met the project's own P1 standard at
the first run.** (77 before §2.11's import added `QA-021` and `QA-025`, both
Tier B.) Tier C being empty is the one piece of good news: every PROVEN claim can
at least point at a committed document. But at the first run *not one* pointed at
a probe.

**Tier A became 3 on 2026-07-28** — `GLOBAL.H1-CENSUS`, `3x3.H1-CENSUS` and
`4x3.H1-CENSUS`, whose evidence resolves to `docs/evidence/GLOBAL.H1-CENSUS/`
(raw stdout per board, provenance, and the broken-detector calibration runs;
committed in `286d679`). **These are the first P1-compliant PROVEN rows in the
project's history.** The debt did not shrink — 79 rows are still non-compliant,
and the ratio only improved because the denominator grew — but the standard is
now demonstrably reachable, by an experiment that cost four minutes of CPU.

Ranked by formal in-degree (how much of the graph rests on it), the top of the
debt list is:

| in-deg | claim | what is missing |
|---|---|---|
| 9 | `GLOBAL.S2` | Benson's theorem — mathematics; a probe may not be the right artifact (see §7) |
| 9 | `GLOBAL.INVSYM` | colour inversion / dihedral invariance — the symmetry battery source and output |
| 8 | `GLOBAL.FP1` | Knaster–Tarski least/greatest fixpoint — mathematics |
| 5 | `GLOBAL.S4` · `GLOBAL.AUDITOR` | area scoring; **the standing pre-commit gate itself has no committed run** |
| 5 | `3x3.B1` | least-fixpoint probe — results file **confirmed lost**; only `b1-spec.md` (method) survives |
| 4 | `GLOBAL.FP3` · `3x2.C1` | finite-sweep convergence; the 3×2 ground-truth comparison |
| 3 | `GLOBAL.S1` · `2x2.C1` · `GLOBAL.R1` · `GLOBAL.ADR0009-HONESTY` | — |
| 2 | `3x2.T13` | the C2 falsification. Numbers in git, **probe gone** (C2 above) |
| 2 | `3x2.F1` · `GLOBAL.F4` · `GLOBAL.CHAIN-KO` · `4x4.GTP-DEFECT` · … | — |

**The cheapest remediation is real and worth naming:** `docs/evidence/`
already contains rescued material for `4x4.B43`, `4x4.B43-DIV`, `CODE.UNDEF`,
`2x2.B1`/`3x2.B1`/`3x3.B1` (method only) and the UD decisions — but at the first
run **no register row cited `docs/evidence/` in its evidence column**, which is
why Tier A read 0. Some of that is a citation update, not new work. The rest —
`GLOBAL.AUDITOR`, `GLOBAL.INVSYM`, `GLOBAL.S1`, `3x2.C1` — needs somebody to
commit the probe and its output. This document does not do it: changing an
evidence citation changes what the register asserts, and that was not the
first run's call. **The three `H1-CENSUS` rows are the counter-example, and they
show the pattern:** the citation update was legitimate there only because the run
that backs it was committed first.

### C4 — 12 dangling IDs live (14 at the first run), 0 unmodelled `QA-nnn` IDs (was 14), 57 unreferenced rows live

**Read the unreferenced number with §11 open.** It has been written in this
document as 61, 65, 77 and 51 in four different places, all of them honest
snapshots of a counter that moves whenever a claim ID is mentioned anywhere in
`docs/` — including in this file. The live figure is **57**; the tool print is the
authority and this prose is not.

**Two dangling IDs closed:** `3x3.H1-CENSUS` and `4x3.H1-CENSUS` were dangling
because EXP-3 minted them in flight; both now have register rows (§2.8) carrying
EXP-3's measured per-board numbers. That is the check working end to end — it
flagged an ID the graph could not see, and the ID now has a row and edges.

**Dangling — an ID is cited but has no row.** These are broken edges *inside
the register itself*, and every one is a place a future falsification would
fail to propagate:

| dangling ID | cited at | probable intent |
|---|---|---|
| `4x3.ANCHOR` | `CLAIMS.md:196` (`4x3.C1`'s `e:` edge), `CLAIMS.md:479` (§4.1 O2 prose) | no such row exists; the 4×3 anchor lives inside `4x3.BRACKET` |
| `4x4.CHAIN-KO` | `CLAIMS.md:271` (`4x4.GTP-DEFECT`'s `d:` edge) | almost certainly `GLOBAL.CHAIN-KO` |
| `4x4.ARENA-DIV` | `CLAIMS.md:203` (`4x4.C2`'s `e:` edge) | almost certainly `4x4.B43-DIV` |
| `2x2.C4`, `3x2.C4` | `CLAIMS.md:193-194` (dependents of `2x2.C1`/`3x2.C1`) | no per-board C4 rows exist; only `GLOBAL.C4` |
| `GLOBAL.BRACKET` | `CLAIMS.md:167` (`GLOBAL.FP1`'s dependents) | no row |
| `GLOBAL.C1-CALIB` | `CLAIMS.md:193` | no row |
| `4x4.X1`, `4x4.X2` | `CLAIMS.md:48` (§1's own minting example), `CLAIMS.md:267` | `4x4.X2` is named as a dependent of `4x4.B43` and does not exist |
| `4x4.S2` | `CLAIMS.md:41` (§1's scope-disambiguation example) | the row is `4x4.S2-impl`; §1's own worked example cites an ID the register does not carry |
| `3x3.H1-CENSUS`, `4x3.H1-CENSUS` | `docs/infra/dispatch/EXP-3.md:155`, `docs/status/CURRENT.md:25` | in-flight work minting new IDs — **CLOSED 2026-07-28: both now have rows in §2.8** |
| `2x2.BASICKO-TIE`, `3x2.BASICKO-TIE` | `docs/infra/dispatch/EXP-4.md:136` | in-flight work minting new IDs — still dangling (EXP-4 has not landed) |

The last four are the tool working as intended on *live* work: two other
consoles are creating claims right now, and the register does not know about
them yet. **Two of the four have since been closed**, which is the check's whole
purpose: an ID minted in a dispatch brief was caught before it became a second
graph with no edges.

**A second ID namespace the register does not model.** `roadmap-2026-07-28.md`
and the dispatch briefs use **14 distinct `QA-nnn` IDs** — `QA-010`, `QA-011`,
`QA-012`, `QA-016`, `QA-018`, `QA-019`, `QA-020`, `QA-021`, `QA-022`, `QA-023`,
`QA-024`, `QA-025`, `QA-026`, `QA-027` — and **none has a register row**.
`QA-023` even has committed evidence at `docs/evidence/QA-023/proof.md`, the
only claim-ID-named directory in the evidence store, and the register cannot
see it. Two ID namespaces means two dependency graphs, and the second one has
no edges at all. This is O1's failure mode with a different prefix, and it is
being created right now, faster than the register is being maintained.
**Recommendation (not a ruling): §1 should either admit `QA-nnn` as a scope or
the roadmap should stop minting it.**

**Unreferenced — 77 rows** when the sweep was run *before* this document
existed: no citation outside §2 and no incoming edge inside it. Most are terminal
MEASUREMENT rows and that is fine. A claim nothing rests on is either a fact the
project has stopped using, or an edge somebody forgot to write.

*The metric is live, and publishing this document moved it.* Re-running after
this file was committed gave **51**: discussing 26 of them here counts as a
reference. The first-run SUMMARY block above prints **61**, and the live run
prints **57**. **All four numbers are real and none is wrong** — they are the same
counter at four different moments, and the moments differ by which documents
existed and what they mentioned. The lesson is not that the counter is broken; it
is that **this figure must be read from the tool, never quoted from prose**, and
§11 says so once for the whole document. That sensitivity to prose is a limitation
of the smell — the count says "nobody is talking about this claim", which is
weaker than "nothing depends on this claim". The residue after this
document is the interesting set; the PROVEN members are
`GLOBAL.ADR0004-P1`, `GLOBAL.ADR0005-SUBBOARD`, `GLOBAL.ADR0007-AB`,
`GLOBAL.ADR0009-DTT`, `GLOBAL.ADR0009-SUCC`, `GLOBAL.ADR0012-V1`,
`GLOBAL.ADR0014-PURE`, `GLOBAL.RPLY-TRAP`, `GLOBAL.RNPLY-FORBID` and
`4x4.REGR-SYM` — nine ADR design decisions and one measurement, none of which
any current claim rests on.

---

## 4. The repeated-narrowing smells (Field A)

Five rows are at `narrowed >= 2`:

```
  SMELL: repeated narrowing — the representation may be wrong, not the claim.
         `GLOBAL.FP2-bounded` narrowed 2× · now FALSE-AS-SCOPED (at 3×2)
         `GLOBAL.CERTCORE`    narrowed 2× · now FALSE-AS-SCOPED
         `GLOBAL.C2`          narrowed 2× · now FALSE-AS-SCOPED (at 3×2)
         `GLOBAL.C3`          narrowed 2× · now FALSE-AS-SCOPED (at 3×3)
         `GLOBAL.REFRAME`     narrowed 3× · now CLAIMED (adopted decision)

  4 of 5 repeatedly-narrowed claims are now FALSE. Repeated narrowing has
  so far predicted death in this register; the survivors are the ones to read.
```

**Read that last line carefully.** Every claim in this register that was
narrowed twice is now false — except one, and that one is the project's current
deliverable, narrowed *three* times. `GLOBAL.REFRAME` is the "fresh-start score
table + CLAIMED `[L,H]` bracket" position, and its three narrowings are exactly
the ladder `critique-2026-07-28.md` §2 names: single score → bracket →
fresh-start-only.

The field was added to test a hypothesis about the project's method. On the
register's own history the hypothesis holds: **repeated narrowing has been a
leading indicator of falsification, not of increasing rigour.** It is one
register and five data points, so this is a smell, not a law — but the one
survivor is the thing the project is currently building.

**Correction to the first version of this document, and it weakens the claim.**
The first run also reported `GLOBAL.REFRAME` as a C1 orphan, and this section
said "two independent checks, added for unrelated reasons, both point at the
deliverable." **That was wrong.** The orphan flag was a false positive caused by
the missing edge kind (§9): the reframe is not a consequence of C2/C3/C4 being
true, it was adopted *because they are false*, and after re-labelling those
three edges `n:` the reframe is healthy. Only the narrowing smell remains.

So the signal is **one check, not two** — weaker, and it should be read as
weaker. It is still real: `GLOBAL.REFRAME` is the only claim in a 245-row
register narrowed three times, it is the only repeatedly-narrowed claim still
standing, and the four that preceded it down that path are all now FALSE. But
one smell on one row is a prompt to re-read the deliverable, not evidence
against it, and this document previously implied more than that.

---

## 5. How Field A was populated, and where it is honest about not knowing

A **narrowing event** is a re-statement of the same claim with a smaller scope.
A falsification is not a narrowing (the claim was withdrawn, not shrunk), and a
scope stated narrowly at birth is not a narrowing either.

**Individually assessed and given a non-zero count (16 rows):**

| claim | n | the narrowing events |
|---|---|---|
| `GLOBAL.REFRAME` | 3 | single score → bracket → fresh-start-only (`critique-2026-07-28.md` §2; `PROGRESS.md:135-146`) |
| `GLOBAL.C2` | 2 | FP2 theorem → "explicitly NOT a theorem" (`0009:78-89`); then split into bounded / general (`CONCEPTS.md:33-42`) |
| `GLOBAL.C3` | 2 | equality (`CERTCORE`, `0009:65-67`) → a *bracket*; then the ADR-0009 honesty downgrade |
| `GLOBAL.CERTCORE` | 2 | ADR-0009 Decision 2 → honesty clause → "the retired 'certified core' framing" (the register's own words) |
| `GLOBAL.FP2-bounded` | 2 | inherits FP2's theorem→claim downgrade, plus the general→bounded restriction |
| `GLOBAL.FP2` | 1 | `0009:65-67` → `0009:78-89`, "explicitly NOT a theorem" |
| `GLOBAL.F1` | 1 | `0005:90-93` "theorem" → `0008:32-38` "sound-in-practice compromise, not a theorem" (§5-I25) |
| `GLOBAL.ADR0005-CACHE` | 1 | the same ADR-0008 downgrade, from the parent's side |
| `GLOBAL.F2` | 1 | ADR-0010 "sound" → `0010:70-81` "closed empirically, not proved" |
| `GLOBAL.F3` | 1 | "sound" → "soundish", resting on three named invariants (`0013:50-65`) |
| `GLOBAL.AUDITOR` | 1 | a gate → "passing is **necessary, not sufficient**" |
| `GLOBAL.P2` | 1 | symmetry PASS ⇒ correctness → "necessary, not sufficient" |
| `GLOBAL.S3a` | 1 | kernel correctness → "OEIS attests the legal-position count **and nothing more**" |
| `4x4.M6-SCREEN` | 1 | a discriminator → "a screen, not a gate" |
| `CODE.ADR0011-DTT` | 1 | DTT → "**best-effort** where optimal lines cross unfinished V1 slots" |
| `4x4.FP1-C3` | 1 | "PROVEN" → "PROVEN (as scoped)": a 1:37 sample with `GLOBAL.H4`'s two residual gaps |

**Left `?` — the documents show a hedge-ladder I could not count (2 rows):**
`4x4.C1` ("SUPPORTED, not PROVEN" is plainly a retreat, but from what and how
many times is not recorded) and `GLOBAL.ADR0006-EYE` (whether ADR-0006's
weak-dominance claim was ever stronger is not recoverable from the ADR alone).

**Everything else is `0`, and `0` here is a default, not a measurement.** It
means "no narrowing event was found for this row in the 2026-07-28 sweep",
across the 199 rows not individually assessed. `GLOBAL.C4` is deliberately `0`
despite being one of the dispatch's named candidates: it was falsified outright,
never narrowed, and recording a narrowing there would have been invention.

---

## 6. The weak-evidence list (Field B)

```
  WEAK EVIDENCE — stated rate above 25%:            0
  WEAK EVIDENCE — rate not computed (`?`):         78 PROVEN rows   (75 at the first run)
  discriminating (rate stated and <= 25%):          4
    `GLOBAL.S1`  ~0%      `4x4.S1`   ~0%
    `4x4.S3a`    <0.01%   `4x3.S3a`  <0.1%
```

**78 of 82 PROVEN claims have never had the question asked** (75 of 79 at the
first run). That is the finding — not the zero in the first line. **The three new
rows made it worse, deliberately:** the `H1-CENSUS` rows carry `?` because EXP-3's
broken-detector calibration shows the count *is* discriminating (a wrong detector
moved it by +60%, +84%, +91% and −8%) without anybody computing the probability a
wrong answer would land on the right number. Writing a figure there would have
been invention, so the honest cost is three more `?` rows. The critique's proposal was that
*every* validation state the probability a wrong result would also have passed
it; the register now has a column for it and it is 95% empty.

**Populated where the critique already computed the number** (§3, the
bracket-containment table):

| claim | rate | why |
|---|---|---|
| `3x3.BRACKET`, `3x3.ANCHOR` | ~42% | bracket [2,9], ~19 plausible values; the anchor +9 is *the bracket's own upper endpoint* |
| `4x3.BRACKET` | ~56% | bracket [−1,12] of ~25 values, anchor +4 |
| `4x4.BRACKET`, `4x4.ANCHOR` | ~70% | bracket [−6,16] of ~33 values, anchor +2. A test a wrong answer passes 70% of the time is close to unfalsifiable |
| `4x4.CYCLE-INSENS` | ~70% | rests on that same single 4×4 agreement, cross-*ruleset* rather than cross-board |

**Populated where the figure is arithmetically obvious** (the four rows that
clear the bar): `GLOBAL.S1` / `4x4.S1` at `~0%` — an exhaustive round-trip over
the whole 3^16 board space; a non-bijection collides with certainty.
`4x4.S3a` at `<0.01%` and `4x3.S3a` at `<0.1%` — a wrong move/capture kernel
reproducing an externally published count (24,318,165 and 321,689, OEIS
A094777) by chance.

**Everything else is `?`**, including both rows imported from the Q&A register
(`QA-021`, the exhaustive FP1 check-3 sweep, and `QA-025`). Note what this means for the highest-in-degree rows
in the whole register: `GLOBAL.INVSYM` (in-degree 9), `GLOBAL.S2` (9),
`GLOBAL.FP1` (8), `GLOBAL.AUDITOR` (5) all carry `?`. `GLOBAL.AUDITOR` is the
standing mandatory pre-commit gate and the register itself already says
"passing is necessary, not sufficient" — the rate is the number that would
quantify how insufficient.

**A caveat the tool does not encode.** Several `?` rows are mathematical
arguments (`GLOBAL.FP1`, `GLOBAL.FP3`, `GLOBAL.ADR0012-LAYER`) where "the
probability a wrong answer passes the test" may not be a meaningful quantity.
An `n/a` value was deliberately *not* added: it is an escape hatch that would
have absorbed most of the 75, and the whole point of the column is that the
project has not asked the question. If the user wants `n/a`, it should be added
with a rule for who may use it.

---

## 7. What this run does NOT claim

- **No status was changed to make the lint pass.** Not one. The register is in
  the state the sweep found it, and the tool exits 1 on it. Promotions,
  demotions, `d:`→`e:` re-labellings and the O1 adjudication are the user's and
  Opus's calls (register §8, §4.1's "Nuance to preserve, not resolve").
- **C1a flags a structure, not a verdict.** "Live claim with a falsified `d:`
  ancestor" is a mechanical property of the edges as written. The first run
  proved the point in the worst way: 14 of its 23 orphans were mis-typed edges,
  not real debt (§9). The tool cannot tell an edge kind from a status; that is
  the whole reason §1 distinguishes `d:` / `e:` / `n:` and it needs a human.
- **The `n:` audit is a reading of the documents, not a proof.** §9.1 gives the
  reasoning for each of the 14 re-labellings and §9.2 names the one edge left
  deliberately mis-flagged. If any of the 14 is wrong, the correct response is
  to move it back to `d:` and let C1a shout again.
- **The §2.11 import maps statuses, it does not re-adjudicate them.** §9.3 gives
  the mapping table. Where a Q&A claim restates an existing row it is recorded
  as an alias with a `d:` edge, so it cannot drift from its canonical — but the
  aliasing itself is a judgement about which claims are the same claim.
- **C2's resolver is tolerant on purpose.** It strips `../` and matches on path
  suffixes and basename prefixes, so it will not catch a citation with the
  *wrong relative depth* or a basename collision. It hunts deleted files.
- **C3 Tier B is not an accusation of dishonesty.** An ADR, a research note and
  an epistemic tree are all committed and readable. P1's bar is higher —
  a re-runnable probe — and by that bar the register scores 0.
- **The `narrowed` field is 227 rows of default** (199 of the original 217, plus
  all 28 Q&A rows, which were not assessed for narrowing). Section 5 says which
  18 were actually read.
- **This tool has no evidence directory of its own.** By its own C3 rule that
  makes any claim about it unproven; it is a checker, not a claim. Its
  calibration is in the binary and re-runs on every invocation, which is the
  strongest form of the P3 rule available.

---

## 8. Running it

```
zig build                                  # builds weizigo-claimlint into zig-out/bin/
./zig-out/bin/weizigo-claimlint            # from the repo root
./zig-out/bin/weizigo-claimlint some/other/CLAIMS.md
```

Exit codes: `0` clean · `1` C1a/C1b/C2 found something · `2` calibration failed
(the checker is broken — fix it before trusting the run) · `3` a register row
could not be parsed. C3, C4, C5, A and B report but do not fail.

**Suggested gate, not yet imposed:** C1 and C2 already exit non-zero, so the
tool is ready to be a pre-commit check the moment the current **10 orphans + 10
dangling paths** are adjudicated — and after the `n:` audit the orphans are one
coherent question (the bracket claim, now ruled on in ADR-0015), not a scatter.
C3, C4, A and B should stay reporting-only until the debt they measure has been
worked down — turning a check red on day one, when it is red for 79 of 82 rows,
trains people to ignore it.

---

## 9. The `n:` edge kind and the `QA-nnn` import (added after review)

### 9.1 Why the register needed a third edge kind, and which 14 edges moved

§1 defined `d:` as "the claim is a *logical consequence* of the parent." The
register had nowhere to record the opposite relation, and this project is driven
mostly by **falsifications** — whole positions have been adopted *because* a
claim fell. Recording that as `d:` produced a systematic false positive:

> `GLOBAL.REFRAME` — the current deliverable — is not a consequence of C2, C3
> and C4 being **true**. The honest deliverable became "fresh-start table +
> explicit non-promise" precisely **because** fresh-start ≠ real-game. If
> C2/C3/C4 were rehabilitated, the reframe would be unnecessarily conservative,
> **not wrong**.

So `n:` **derives-from-negation** was added (§1): *the claim is justified by the
parent being FALSE*, with **inverted** propagation — a FALSE parent is healthy,
and a parent that is no longer false is an **ALARM** (C1b). `n:` edges are not
traversed by the orphan sweep: a claim justified by a refutation does not
inherit the refuted parent's ancestry.

All 231 original edges were re-read. **Fourteen `d:` edges on nine rows moved to
`n:`**; the reasoning for each:

| row | edge(s) moved | why it is justified by the parent's falsity |
|---|---|---|
| `GLOBAL.REFRAME` | `C2`, `C3`, `C4` | the reframe *is* the retreat those three falsifications forced |
| `GLOBAL.H1` | `C2`, `C3`, `C4` | the simple-ko pivot is motivated by the mismatch those falsifications expose; its `d:GLOBAL.CHAIN-KO` and `d:GLOBAL.LONGCYCLE` edges are genuine `d:` and stay |
| `GLOBAL.CHAIN-KIND` | `C2` | "violations are definitional; a nonzero rate is expected" holds *because* history-dependence is real |
| `GLOBAL.H5d` | `C2` | "bounded-history state is the representational route to a real-game claim" is a response to C2 falling |
| `GLOBAL.LEAK` | `C4` | if fresh-start == real-game there is no leak. The row asserts the leak exists |
| `GLOBAL.ADR0008-HOLE` | `ADR0005-CACHE` | the row *is* the retraction of ADR-0005's proof claim; if that claim were a theorem, the retraction would be wrong |
| `4x4.F1` | `GLOBAL.F1` | the row asserts the finisher is **UN**sound at 4×4 — §4.1-O10 already described these two as "claims that something is unsound, derived from a falsified parent" |
| `4x3.F1` | `GLOBAL.F1` | same |
| `GLOBAL.H3` | `GLOBAL.F1` | the register's own annotation was "(no memo available)" — the search must be memo-free *because* the sound memo does not exist |

**Effect.** Orphans 23 → **9**. `GLOBAL.UD-1/2/3`, `4x4.M6-FLOOR`,
`4x4.M6-EXCESS`, `GLOBAL.ONEMISMATCH` and `GLOBAL.H5b` cleared automatically as
consequences, without any of their own edges being touched — which is the test
that the re-labelling was structural rather than cosmetic.

### 9.2 What was left `d:` on purpose

The instruction was to be conservative: *a few false orphans are better than
silently-hidden real ones.* One edge is genuinely ambiguous and stays `d:`:

- **`GLOBAL.H5c` `d:GLOBAL.C3`.** The row says bracket-cut search is "tractable
  … but **NOT shippable as sound** — cutting on `[L,H]` under a real history
  *is* claim C3". The *identification* (cut ≡ C3) is true whatever C3's status,
  which reads `d:`. The *verdict* ("not shippable") requires C3 to be false,
  which reads `n:`. The register frames this edge as the one that orphans the
  finisher (`dependents`: "§4-O1"), so moving it would quietly weaken O1. Left
  `d:`, flagged, and it is one of the nine orphans above.

Also examined and deliberately **not** moved: `4x3.C1 d:GLOBAL.F1` (C1 needs the
finisher to be *sound*, so the orphan is real and its own row admits it);
`GLOBAL.ADR0012-GATE d:4x4.COMPLETE-2026-07-21` (the gate assumed the artifact
was correct — §4.1-O6); `GLOBAL.F2/F3/F4/B15` and `GLOBAL.ADR0010-CUT`, all of
which need `GLOBAL.C3` to be *true*; `4x4.M6-EXCESS d:4x4.F1` (derives from
`4x4.F1` being true, and `4x4.F1` is now healthy, so it clears anyway);
`GLOBAL.P1`, `GLOBAL.P3` and `GLOBAL.C4` (all FALSE themselves, so the kind does
not change any verdict, and guessing would add noise).

### 9.3 The `QA-nnn` import

C4 found a second claim-ID namespace with **zero edges**: `QA-001`…`QA-028`,
minted by `critique-2026-07-28.md` §7 and `roadmap-2026-07-28.md` §5 and cited
throughout the dispatch briefs, with no register row. `QA-023` — the
load-bearing claim of the whole roadmap, and the only claim in the project with
a claim-ID-named evidence directory (`docs/evidence/QA-023/`) — was invisible to
the graph.

All 28 are now rows in **§2.11**. Namespace coverage went **14 unmodelled → 0**,
and the register is 217 → **245 rows** (and 245 → **253** after the 2026-07-28
promotion pass — §11).

**Status mapping** (the source tables use words this register does not; nothing
was re-adjudicated):

| source word | register status | note |
|---|---|---|
| `FALSE` | `FALSE` | kept flat. §1 gained `FALSE` as a status rather than re-labelling 9 rows `FALSE-AS-SCOPED`, which would have been a status change |
| `UNKNOWN` (QA-008) | `UNTESTED` | — |
| `DISCREPANCY` (QA-009) | `UNTESTED` | it is §6-D1; the row says so |
| `PROPOSED` (QA-015) | `CLAIMED (PROPOSED — a rule change, not a fact; the user's call)` | the source word is kept in the cell |
| `ORPHANED` (QA-018) | `CLAIMED` + `d:GLOBAL.F2` | so C1a *computes* the orphan instead of the register asserting it — and it does: `QA-018` is orphan #9 |

**Eight rows are aliases** — `QA-002`, `QA-003`, `QA-007`, `QA-010`, `QA-011`,
`QA-013`, `QA-018`, `QA-025` — recorded as `d:<canonical>` rather than as copies,
so a status change to the canonical propagates instead of leaving two rows to
drift apart. `QA-018` proves the mechanism works: it inherited O1 the moment it
was imported.

**`QA-023` was given no `depends-on` edge, deliberately.** Its obligation is to
distinguish itself from `GLOBAL.R2` (score-on-cycle ≡ PSK) and
`GLOBAL.RPLY-TRAP` (the cycle terminal drags history back into the memo key).
Writing either as a dependency would prejudge which of them it stands or falls
with, and that is exactly what EXP-2 Part A is for. The row says so in its claim
text. Its evidence cites `docs/evidence/QA-023/proof.md` **and** records that
the computational half is 2×2-only, which `EXP-2-AUDIT-PREREG.md` rejects
outright as INCOMPLETE. EXP-2 was in flight in another console as this was
written; the row will need updating when it lands, and the linter will not know
that — **C4's dangling-ID check is the only thing that notices new claims, and
nothing notices a stale one.** That is the next gap.

One new C2 finding came from the import:
`docs/research/qa023-basicko-markovian-2026-07-28.md`, named by `EXP-2.md` as
its output, does not exist yet. That is "not yet written" rather than "deleted",
and it will clear when EXP-2 lands.

---

## 10. The shadowed-dependency class (C5), added after the second review

### 10.1 The shape

    3x3.C1   "Fresh-start scores correct at 3×3"          CLAIMED       d:3x3.F2
    3x3.F2   "Finisher COMPLETES all 622 orbit reps"      MEASUREMENT   e:3x3.B1, e:3x3.ANCHOR

`3x3.C1` depended on `3x3.F2`, and `3x3.F2` records only that the finisher
**terminated**. **Completion is not soundness.** What `3x3.C1` actually needs is
that the finisher was *correct* — `GLOBAL.F2` — which is orphaned via
`GLOBAL.C3`. A MEASUREMENT can never be FALSE, so the edge was a **dead end**:
the falsification had nowhere to travel, and C1a never saw the row.

Generalised: **a `d:` edge whose parent can never be FALSE cannot propagate
anything.** That covers MEASUREMENT rows and the two `— (definition)` rows, and
C5 reports both. It is a structural smell the register will keep regenerating —
citing the run you did is the natural thing to write — and a human reading the
row does not see it, because `3x3.F2` looks like a perfectly good parent.

### 10.2 The sweep — one row moved, three left ambiguous

| edge | verdict |
|---|---|
| `3x3.C1` `d:3x3.F2` | **MOVED.** Now `d:GLOBAL.F2` (the soundness behind the measurement) **plus** `e:3x3.F2` — the completion measurement is genuine supporting evidence and was kept, demoted to `e:` as instructed. `3x3.C1` is now orphan #1 |
| `4x4.M6-SCREEN` `d:4x4.M6` | **AMBIGUOUS, left.** The nearest candidate parent is `4x4.M6-EXCESS` (if the excess is not the ADR-0013 bug, the misprice rate does not discriminate) — but there is no row asserting "the misprice comparison is correct", so this is not the crisp measurement→soundness shape. Guessing would add an edge the documents do not support |
| `GLOBAL.ADR0012-5X5` `d:GLOBAL.SWEEPS` | **AMBIGUOUS, left.** The real dependency is that the 2×2→4×4 trend *extrapolates*, which is §5-I17 — an empirical cross-size extrapolation with no row of its own and, per `AGENTS.md:11-13`, no licence |
| `GLOBAL.ADR0012-5X5` `d:GLOBAL.F4-COST` | **AMBIGUOUS, left.** Arguably `GLOBAL.F4` (the KM memo is sound) — reuse rates are worthless if the memo is not. But "5×5 is feasible" is a *cost* claim, and a cost claim does not obviously require soundness. Adding it would make ADR-0012 an orphan on a judgement call |
| `4x4.COMPLETE-2026-07-21` `d:GLOBAL.C1` | **LEFT.** `GLOBAL.C1` is a definition, so the edge is a dead end — but the row is already FALSE-AS-SCOPED, so no verdict turns on it. Reported by C5 for completeness |

**One row moved. Orphans 9 → 10. Edges 266 → 267** (one `d:` retargeted, one
`e:` added). Three ambiguous cases were left exactly as found, per the same
conservatism as the `n:` round: a visible false negative that C5 keeps
reporting is better than an invented edge.

### 10.3 The calibration ate its own known-bad, and the tool caught it

C5's first known-bad was `3x3.C1 d: 3x3.F2` — the real, in-register case. It
was CAUGHT on the run before the fix and **MISSED on the run after**, because
the fix removed it, and the tool correctly reported `calibration: FAIL` and
exited 2.

That is the machinery working, and it is also a lesson worth keeping: **a
calibration case that lives in the data disappears the moment the data
improves.** C5's known-bad now lives in the same embedded synthetic register as
C1b's — a MEASUREMENT parent with a `d:` child that must be reported, beside a
real-claim parent with a `d:` child that must not. The real-data known-good
(`GLOBAL.F2`, whose every `d:` parent is a real claim) is kept alongside,
because a purely synthetic calibration would not prove the check runs over the
actual register. Seven cases now, and the same rule applies to the other six:
**known-bads that can be fixed must be synthetic.**

### 10.4 Known limitation, accepted and not being closed: staleness

**Nothing in this tool notices that a row has gone out of date.** C4 detects a
claim ID that appears in `docs/` with no register row — a *new* claim — but
there is no check for the reverse: a register row whose cited documents have
moved on. `QA-023` is the live example. It is CLAIMED, EXP-2 is running in
another console, and the moment EXP-2 reports, the row's status, evidence and
`wrong-answer-pass-rate` will all be wrong. `weizigo-claimlint` will exit 0 on
that row and say nothing.

Recorded as an accepted limitation, not a gap being closed now. **Suggested
future check (C6), if it is ever wanted:** store, per row, the git blob hash or
mtime of each document its evidence resolves to; flag any row whose evidence
document changed more recently than the row itself. That is cheap and it maps
to a real failure — `corrections-2026-07-27.md` §D17 records two errata that
were fixed in the code and left open in the ledger, which is the same shape.
It needs a per-row timestamp column the register does not have, so it is a
schema change and belongs in a deliberate decision, not in this task.

---

## 11. Reconciliation — this document contradicted itself, and what the tool actually says

Added 2026-07-28, third revision. **A lint tool whose own report disagrees with
itself cannot be the source of truth for anything**, and this report did:

| counter | written here as | live |
|---|---|---|
| C2 dangling evidence paths | **11** (headline, §3 heading) and **12** (§3 SUMMARY block, and `STATE.md`) | **10** (9 missing + 1 git-ignored) |
| C4 unreferenced rows | **61** (§3 SUMMARY), **65** (§3 heading), **77** (§3 prose), **51** (§3 prose, post-publication re-run) | **57** |
| C3 PROVEN without committed evidence | **79 of 79**, Tier A **0** | **79 of 82**, Tier A **3** |
| B PROVEN rows with `?` rate | **75** | **78** |
| rows / edges | **245** / **267** | **253** / **290** |

**None of those numbers was fabricated, and that is the point.** Each was a true
reading at a different moment, and three separate mechanisms move them:

1. **The register changes.** The `n:` audit, the §2.11 import, the C5 shadow fix
   and the 2026-07-28 promotion pass each added or retargeted rows and edges.
   245 → 253 rows and 267 → 290 edges are that.
2. **Documents the register cites change, in other consoles.** The C2 count fell
   from 12 to 9 missing paths mostly because **`AGENTS.md` was rewritten** as an
   89-line router while this work was in flight: its citations of
   `docs/engine/RISKS.md`, `untracked/discussion.md` and `untracked/idea-heap.md`
   went away, so fourteen register rows stopped reaching three absent files. The
   files are still absent. Two runs eleven minutes apart on 2026-07-28 differed by
   one path (`dispatch/EXP-N.md`, cited by the router at 13:0x and gone by 13:11).
3. **The C4 unreferenced count reads prose.** A row counts as referenced if any
   document in `docs/` mentions its ID — so *writing about* the unreferenced rows
   makes them referenced. Publishing this document alone moved the figure by 26.

### The rule this establishes

**Quote the tool, never the prose.** `bin/weizigo-claimlint` prints every counter
on every run in about a second. Any number in any document is a snapshot with a
timestamp attached, and a document that repeats a counter in four places will
drift in at least three of them. Concretely:

- `CLAIMS.md` §8 now says "do not copy these numbers into another document" and
  names the volatility.
- The §3 block above is dated and labelled *live*, with the first run kept
  beside it for the delta rather than merged into it.
- **C4's unreferenced count should be read as a smell with a moving baseline, not
  as a metric.** If it is ever wanted as a metric, the fix is to count only
  *incoming register edges* and drop the prose limb — a tool change, not a
  documentation change, and not made here.

### What did not move, and why that matters

**C1a orphans: 10, before and after. C1b alarms: 0. Calibration: PASS. Exit: 1.**
The two checks that actually fail the run were untouched by eight new rows, two
new `n:` edges and a ruling on the family behind eight of the ten orphans. That is
the correct behaviour: **ADR-0015 rules that the ADR-0010 bracket justification is
refuted, which is a reason the orphans are *real*, not a reason to clear them.**
Adjudicating an orphan does not delete it; only a proof or a status change does,
and no status was changed to move a counter.

---

Tagged claims: `GLOBAL.CALIB-LESSON` (the calibration requirement this tool
honours), `GLOBAL.C2`, `GLOBAL.C3`, `GLOBAL.C4`, `GLOBAL.F1`, `GLOBAL.F2`,
`GLOBAL.REFRAME`, `GLOBAL.H1`, `GLOBAL.H5c`, `3x2.T13`,
`4x4.COMPLETE-2026-07-21` (the roots, orphans and re-labelled edges it reports),
`QA-018` (the imported alias that inherited O1), `QA-022` (the evidence-deletion
incident C2 and C3 exist to prevent recurring), `QA-023` (imported so the
roadmap's load-bearing claim is finally in the graph), `3x3.C1` and `3x3.F2`
(the shadowed dependency C5 exists to catch), and — added in the third revision —
`GLOBAL.H1-CENSUS`, `3x3.H1-CENSUS`, `4x3.H1-CENSUS` (Tier A, and the two
dangling IDs C4 caught), `GLOBAL.ADR0015-BURDEN` (the ruling on the orphan
family), `GLOBAL.ADR0016-INHERIT`, `QA-009` (the discrepancy that was not one),
`3x3.E2-RUN1` / `3x3.E2-RUN2`.
