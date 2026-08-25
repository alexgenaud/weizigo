# C3 evidence triage — adjudication of the nine-lane race (T893)

**Adjudicator:** claude-fable-5/T893, 2026-08-24. Per race protocol v2.1 rule 9 (reserve seat
judges from primary sources) and rule 11 (no lane scores its own race — this seat had no lane).
**Directive acknowledged:** D088 (operator ruling on haiku/glm penalties, applied in §6).
**Sources:** the nine lanes' raw batch rows (sealed lane directories, lanes T881–T889), the
register `docs/epistemic/CLAIMS.md` (read, not edited), claimlint's C3 rule
(`src/claimlint.zig:1937-1967`), and the committed artifacts themselves — every artifact named
below was opened and its numbers checked against the register row, not trusted by filename.
**Constraint honored:** no claim status is changed here. This document decides what resolution
each claim *needs*, not what its answer is.

Classes used (the lane brief offered only a/b/c; class (d) is this adjudication's addition):

- **(a)** evidence exists on disk, uncommitted — commit it and repoint.
- **(b)** evidence gone, experiment re-runnable at sane cost — run it and capture.
- **(c)** neither — a drafted resolution for the operator to ratify.
- **(d)** the establishing evidence is **already committed in git** and the register row does
  not cite it (or cites it at a path the tier rule does not recognize) — a repointing or
  note-writing job costing minutes, no re-run.

## 1. Verdict summary

Of the 42 debt claims: **a = 2, b = 16, c = 3, d = 19, undecidable = 2.**

**Half the "debt" is not missing evidence — it is a register pointing at the wrong thing.**
21 of 42 claims (classes a+d) resolve with zero re-run compute. The 16 re-runnable claims are
almost all minutes each (the largest recorded run on the list is 87 s). Only 3 claims need an
operator-ratified resolution note, and 2 await a minutes-long human read of a committed PDF.
The C3 debt was priced as if experiments were lost; they mostly are not.

## 2. The repointing hypothesis — tested and confirmed, with one refutation and one caveat

The seat's hypothesis: most class-(a) rows across the nine lanes named paths already committed.
**Census verified exactly** from the raw lane rows: excluding the two canaries, the nine lanes
produced **51 class-(a) rows: 46 named committed paths, 4 named genuinely untracked evidence**
(two lanes × two claims, the same scratch file), **and 1 named a path that does not exist**
(haiku on QA-021 — a fabricated citation).

Of the **11 claims** where some lane named committed evidence under `docs/evidence/` or
`docs/audits/` (canaries excluded):

| verdict | count | claims |
|---|---|---|
| **CONFIRMED** — the committed artifact establishes the claim | **8** | `3x2.F1`, `3x2.F3`, `3x2.F4`, `GLOBAL.ADR0006-PRED`, `-LEMMAS`, `-TEST`, `-PRUNEALL`, `4x3.S2` |
| **REFUTED** — committed file is merely adjacent | **1** | `3x3.S2-impl` (the GLOBAL-S2 note proves the *theorem*, not the *implementation*) |
| **UNDECIDABLE here** | **2** | `GLOBAL.MIGOS-RULE`, `QA-025` (the committed PDF's text resisted mechanical extraction; a human read decides) |

The confirmations are number-for-number, not name-matching:
`docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log` contains the literal result lines
`new (memo_writes ON): checked=378 violations=45` (= `3x2.F1`'s "45 of 378"),
`soundish (writes OFF): checked=378 violations=0` (= `3x2.F3`'s "0 of 378"), and
`deps (guarded reuse, Track B): checked=378 violations=0` (= `3x2.F4`).
`docs/audits/2026-07-30-eye-prune-validation.stdout` contains §A `fixtures: 17 run, 0 failed`
and §B `3999936 compared, 0 mismatches` (= `-PRED`), the §G line `4x4 909540 1362424 … 0 0 0 0 0 0`
(= `-LEMMAS`' 1,362,424 eyes, 0 violations), the §H/§6 totals 4,212 slots / 0 disagreements
(= `-TEST`), and §J `live PRUNE-ALL pairs 96, comparable 96, DISAGREEMENTS 0` (= `-PRUNEALL`).

**Caveat the hypothesis glossed over:** claimlint's mechanical Tier-A test
(`src/claimlint.zig:1962`) recognizes **only paths starting `docs/evidence/`**. The
`GLOBAL-AUDITOR` log already lives there — those three rows are a pure register repoint. The
eye-prune stdout lives under `docs/audits/` — repointing alone will not move those four rows to
Tier A; the stdout (and ideally the .md beside it) must also be copied or moved under
`docs/evidence/` (the directory `docs/evidence/ADR-0006/` already exists and does not yet hold
it). Still minutes, not hours — but a different kind of minutes.

## 3. Per-claim adjudication (44 rows, register order)

Columns: my class; the evidence pointer (committed paths only) or the command; cost; reason.
The two canaries are marked. Uncommitted evidence is named by description per the commit gate;
its exact path and mtime are in the lane rows (sealed lane directories) for the sprint that
commits it.

| # | claim | class | pointer / command | cost | reason |
|---|---|---|---|---|---|
| 1 | `GLOBAL.S1` | b | `zig run -O ReleaseFast src/colex.zig` — `main()` already round-trips 2×2/3×2/3×3/4×4 exhaustively (`src/colex.zig:199-202`) | min | probe committed, output never captured; seconds of compute |
| 2 | `3x3.C3` | **a** | Race-G science-arm E2 re-run capture (scratch survivor, 2026-08-23): per-seed lines `promise 3 final -9` = the register's 12-pt leak, many seeds | ~30 min | genuine uncommitted probe output reproducing the registered falsification; commit under `docs/evidence/` + PROVENANCE + repoint; also re-runnable (`RETRO_E2=1`) |
| 3 | `GLOBAL.E2-SANITY` | b | `RETRO_E2SANITY=1 tools/runner -- zig run -O ReleaseFast src/retro.zig` (env hook exists at HEAD) | min | trivial-bounds control run; cheap |
| 4 | `GLOBAL.MIGOS-RULE` | **UNKNOWN (c\|d)** | `docs/evidence/van-der-werf-sources/ssgo.pdf` (committed archive of the primary source); corroboration `docs/evidence/GLOBAL-TIE-MIGOS/tie-experiment-T274.md` | min–1 h | prior-art-reading claim; if the archived paper states basic-ko + long-cycle-ties, this is (d) repoint; my tooling could not extract the PDF text, so I do not assert it — a human read decides |
| 5 | `GLOBAL.PASS-NOKO` | d | committed solver source: HEAD `src/exp6_solve.zig:927` (pass child encoded `KO_NONE4`), register's pin `082433e:964` verified reachable via `git show` | ~30 min | structural invariant + its committed encoding; evidence note (2-line argument: a pass captures nothing) — no run needed |
| 6 | `GLOBAL.ADR0009-HONESTY` | d | the committed ADR itself (`0009:78-89`) | min | the claim is *about* the ADR's argument; the ADR text establishes it; provenance note or tier exemption |
| 7 | `2x2.C1` | b | committed probes: `src/audit_2x2_mismatch.zig`, `docs/audits/2026-07-30-audit-2x2-mismatch.py`, `src/qa023_brute_2x2.zig` | min | tiny goban, several committed harnesses; run + capture |
| 8 | `3x3.E3` | b | `RETRO_E2=1 tools/runner -- zig run -O ReleaseFast src/retro.zig` with recorded seed; replay legality check | min | leaking games regenerate from seeds (the scratch capture records them per seed) |
| 9 | `GLOBAL.H1-CENSUS` | **canary** | `docs/evidence/GLOBAL.H1-CENSUS/` — Tier A already | — | not debt; seeded control |
| 10 | `GLOBAL.E2-POLICY` | d | committed policy code (max-lo/min-hi convention in the E2/arena path) + `leak-crisis.md:81-83` for the historical lo/lo half | ~30 min | the operative convention is in committed code; the "first run was wrong" half is testimony — pin both in a note |
| 11 | `3x2.F1` | **d** | `docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log` (+ `PROVENANCE.md`) — `checked=378 violations=45` verbatim | min | pure repoint; log already under `docs/evidence/` |
| 12 | `GLOBAL.ADR0003-AREA` | d | committed tests `src/rules.zig:470` (Tromp–Taylor as-stands), `src/rules.zig:1105`, `src/score.zig:19-36` header; `docs/evidence/GLOBAL-S4/` | ~30 min | area-purity half established by committed tests + S4 evidence; Japanese-path-dependence half definitional; note |
| 13 | `4x4.S1` | b | same `src/colex.zig` run as row 1 — `verify(4,4)` is already in `main()` (43 M round-trips, seconds in ReleaseFast) | min | two lanes claimed it needs adding; it does not (checked at HEAD) |
| 14 | `3x3.S2-impl` | b | `zig test src/rules.zig` (Benson falsification tests, e.g. `:655`) + full-goban check; capture output | min–1 h | probe source committed, output uncaptured. **The GLOBAL-S2 provenance note does NOT establish this row** — it proves the theorem, not the implementation (the refuted repoint) |
| 15 | `4x4.FP1-C3` | b | `bin/weizigo-chainability <4x4 checkpoint> --sample 37` (binary committed/built; 258 MB checkpoint on disk, uncommitted, rebuildable) | min | ~2 min sampled; note: QA-021's exhaustive pass supersedes this 1:37 sample (kimi's catch) — an edge note may be the cheaper resolution |
| 16 | `GLOBAL.LEAK` | **a** | same scratch capture as row 2 — leak lines are the claim's phenomenon; definitional half stays prose | shared | commit once, repoint two rows |
| 17 | `GLOBAL.ADR0009-NOEYE` | d | `src/retro.zig:96-98` — `pub const apply_eye_prune = false;` with the ADR-0009 decision-3 comment (verified at HEAD); eye-prune-validation §H uses the full-move retrograde as its control | ~30 min | design fact, established by committed source; note |
| 18 | `GLOBAL.P2` | d | `CONCEPTS.md:124` (committed) | min | "necessary, not sufficient" is a logical statement about the committed methodology text; note/exemption |
| 19 | `QA-021` | b | `bin/weizigo-chainability <4x4 checkpoint> --examples 0` — recorded run: 48,599,962 slots, 87 s | min | binary + artifact exist on this host; artifact uncommitted (258 MB) but rebuildable; capture the exhaustive output. haiku's cited path for this row **does not exist** |
| 20 | `4x3.S1` | b | `src/colex.zig` + one line `try verify(4, 3, gpa);` (531,441 round-trips) | min | probe committed, needs a one-line arm |
| 21 | `4x3.S2` | **d** | `docs/evidence/GLOBAL-S2/PROVENANCE.md` — theorem stated for *every finite goban* | min | pure-math specialization of `GLOBAL.S2` (Tier A); repoint/inheritance edge — the confirmed repoint the hypothesis predicted |
| 22 | `GLOBAL.B1-AUDIT` | b | `RETRO_B1_LOFIX=1 tools/runner -- zig run -O ReleaseFast src/retro.zig` (env hook exists at HEAD) | min–1 h | the multi-fixpointedness demonstration probe is committed |
| 23 | `4x3.FP3` | b | rebuild 4×3 via the `RETRO_SAVE` path and capture sweep-convergence output; `artifacts/oracle-4x3.wzo` (committed) corroborates that convergence completed | min–1 h | convergence is observed by running; a theorem-inheritance note from `GLOBAL.FP3` is a defensible cheaper alternative |
| 24 | `GLOBAL.E1` | **c** | resolution: operator-ratified methodological note pinning `leak-crisis.md:164-168` as testimony | ~30 min | the confounded first-draft E1 code is gone; recreating a bug to prove it existed adds nothing — `3x2.T13` is the live successor |
| 25 | `GLOBAL.ADR0008-HOLE` | d | the committed retraction inside `0008:32-38` | min | claim about the ADR's own text; note/exemption |
| 26 | `GLOBAL.ADR0010-SOUND` | d | `0010:70-81` (committed) | min | same shape |
| 27 | `3x2.F3` | **d** | same GLOBAL-AUDITOR log — `soundish (writes OFF): 0/378` verbatim | min | pure repoint |
| 28 | `3x2.F4` | **d** | same log — `deps (guarded reuse, Track B): 0/378` verbatim | min | pure repoint |
| 29 | `3x3.F4` | b | deps-variant consist at 3×3 (`RETRO_CONSIST3` env hook exists; deps byte-compare per `0013:88-91`) | ~1 h | the 3×2 log does NOT cover 3×3 — lanes citing it here would have repeated the plausible-name error; none did |
| 30 | `4x3.F4` | b | needs a ~10-line `runConsist` wrapper at 4×3 (none exists at HEAD) + `RETRO_DEPSVAL` byte-compare | 1–2 h | smallest real code gap on the list |
| 31 | `CODE.RESOLVER-CONTROLS` | **canary** | `docs/evidence/CODE.RESOLVER/PROVENANCE.md` — Tier A already | — | not debt; seeded control. **Contrary to the race notes, not every lane flagged it: haiku classed it (c)** |
| 32 | `GLOBAL.MEMO-XROOT` | b | recreate: deliberately reintroduce cross-root memo sharing (small patch) at 2×2, expect dihedral failures; the defect code is removed at HEAD (opus's catch) | 1–2 h | a plain re-run canNOT reproduce it; recreation-with-seeded-defect or a historical-falsification note |
| 33 | `GLOBAL.ADR0006-PRED` | **d** | `docs/audits/2026-07-30-eye-prune-validation.stdout` §A (17/17) + §B (0/3,999,936) — verified verbatim | min* | *copy/move stdout under `docs/evidence/` (e.g. into existing `docs/evidence/ADR-0006/`) + repoint; `docs/audits/` alone does not satisfy claimlint C3 |
| 34 | `GLOBAL.ADR0006-LEMMAS` | **d** | same stdout §G `4x4 909540 1362424 13.7 0…0` + §I mutant calibration (lemmas fire on wrong predicates — real controls) | min* | same move+repoint |
| 35 | `GLOBAL.ADR0006-TEST` | **d** | same stdout §H + `…-validation.md` §6: 4,212 slots, 0 disagreements, 4×3 1-in-8 sample declared as a sample | min* | same |
| 36 | `GLOBAL.ADR0006-PRUNEALL` | **d** | same stdout §C (2602, of which 96 live) + §J (96 comparable, 0 disagreements) | min* | same |
| 37 | `GLOBAL.ADR0004-TERM` | **c** | resolution: write the derivation note (Benson-terminal ⇒ exact leaf score ⇒ depth-independence), leaning on `docs/evidence/GLOBAL-S2/` and `GLOBAL-S4/` | ~1 h | theorem chain whose premises have committed evidence but whose derivation was never written down |
| 38 | `GLOBAL.ADR0005-PASS` | d | ruleset definition `0005:47-50` + unconditional `applyPass` in committed `src/rules.zig` | ~30 min | definitional + code fact; note |
| 39 | `GLOBAL.CALIB-LESSON` | **c** | resolution: ratify as a methodological ruling (`corrections:197-201` as testimony) | ~15 min | a lesson, not an experiment; nothing to run |
| 40 | `CODE.ADR0011-FMT` | b | `zig test src/artifact.zig` (reader-refusal tests at `:311`) + header hexdump vs committed `artifacts/*.wzo` | min | behavior claim; committed tests, uncaptured output |
| 41 | `CODE.ADR0011-GATE` | b | positive/negative control run of `saveArtifact` refusal (`src/retro.zig:~2331`) — oxalpha's design is the right one | ~1 h | behavior claim; needs an actual control run, not just source reading |
| 42 | `CODE.M4A-HARNESS` | d + **STALE** | git history at the minting commit establishes the original finding; **but the row is false at HEAD**: `src/oracle_v2_accept.zig` is wired into `build.zig:177-185` (test step) and `build.zig:1583-1602` (battery-sweep executable) | ~1 h | the register asserts "in no build graph" — no longer true. Needs re-audit and narrowing, not evidence recovery. Only opus and dsflash caught this |
| 43 | `GLOBAL.ADR0014-PURE` | d | `src/score.zig:19-36` header + a no-oracle-imports grep (seconds to verify at HEAD) | ~30 min | inspection claim about committed code; note |
| 44 | `QA-025` | **UNKNOWN (c\|d)** | alias of `GLOBAL.MIGOS-RULE` (`d:` edge in its own row) | min | inherits row 4's resolution; alias note either way |

## 4. Cost roll-up for the C3-to-zero sprint

- **21 claims (a+d): no re-run.** 2 commit-the-scratch-file jobs (one file covers both), 5 pure
  register repoints (F1/F3/F4 + 4x3.S2 + the ADR0006 quartet after one file move), ~12
  provenance/derivation notes of the `GLOBAL-S2` literature-note style. Batchable: the four
  ADR0006 rows are one file-move + four repoints; the ~9 "claim-about-a-committed-text" rows
  (P2, HONESTY, HOLE, SOUND, 0005-PASS, 0003-AREA, 0014-PURE, PASS-NOKO, E2-POLICY) could
  alternatively be resolved wholesale by a ratified tier-policy amendment (a class of claims
  whose evidence *is* a committed text at a pinned commit) — one ruling instead of nine notes.
- **16 claims (b): all cheap.** Largest recorded run: 87 s (QA-021). Real work items: the
  4×3 consist wrapper (~10 lines), the MEMO-XROOT seeded-defect recreation, the ADR0011-GATE
  control run. Everything else is run-and-capture.
- **3 claims (c): ~2 h of note-writing** + operator ratification.
- **2 claims: one human PDF read** decides between minutes and an hour.

Total: **roughly 2–3 focused console-days**, dominated by commit hygiene and note-writing, not
compute. One process fix falls out for free: the tier rule's `docs/evidence/`-only test is why
committed probe output under `docs/audits/` and committed probe *source* under `src/` read as
debt (see §7).

## 5. What the disagreement was — the missing category, quantified

Unanimity on the 42 debt claims was **0/42** (majority 32, no-majority 10) with all nine lanes;
excluding the two degenerate lanes it becomes 7 unanimous / 5 no-majority. But the deeper cause
is structural: for the **19 class-(d) claims, the lane brief offered no legal answer.** (a)
required *uncommitted*, (b) required *evidence gone*, (c) required *not re-runnable*. A lane
that found the truth — "the evidence is committed" — had to break one of the three definitions,
and which rule a model chose to break is the clearest capability signal in the race:

- **sonnet, opus, oxalpha, dspro** bent (a): cited the committed path, sonnet annotating
  "(already committed)" — inventing class (d) inside the schema. Truth-preserving rule-bending.
- **glm** collapsed into (b): everything became "re-runnable", including `sed` of an ADR.
- **haiku** collapsed into (c): everything became unrecoverable debt.
- **kimi, dsflash, minimax** wrote the answer into (c)-resolutions ("mint a provenance note",
  "promote via inheritance") — right substance, buried in the wrong class.

## 6. Model performance (per operator ruling of 2026-08-24, directive D088)

Two agreement numbers exist. The **mechanical score** (score.py, re-run by this seat: six lanes
tied at 60/60 — it measures form, not truth). The number below is **substance agreement with
this adjudication**: a lane earns a claim if its row identifies the correct resolution (the
committed artifact for (d), the on-disk file for (a), a command that actually selects the probe
for (b), a resolution that resolves for (c)) — judged per-row by this seat, canaries and the two
UNKNOWN rows excluded (n = 40). Agreement itself was never scored; a lone-correct lane earns its
row (oxalpha and glm alone earned both (a) rows).

| lane | model | substance /40 | effort: real paths (named) | median `what_i_checked` | discernment (entropy) | character of errors |
|---|---|---|---|---|---|---|
| T886 | oxalpha | **37** | 36 (71) | 261 | 0.96 | best in race: found the uncommitted capture AND the committed logs; correct env flags; the only lane to design genuine positive/negative control runs. Rare misses: re-run proposed where source sufficed (PASS-NOKO) |
| T887 | claude-sonnet-5 | **35** | 35 (95) | 407 | 0.95 | found the most committed evidence; line-pinned citations (e.g. `retro.zig:96-98`, the register-pin vs HEAD drift on PASS-NOKO); invented class (d) via "(already committed)" annotations — answered the operator's question over the brief's schema. Cost: dropped one row (M4A, 43/44), one unresolvable path per score.py |
| T881 | claude-opus-5 | **33** | 42 (106) | 520 | 0.88 | strong on committed-output recognition (consist log + eye-prune stdout); sharpest analysis prose (ADR0003-AREA "welds two propositions"; MEMO-XROOT "the defect is removed at HEAD"); co-caught M4A staleness. Bias: empiricist — proposes a probe even on definitional rows |
| T882 | deepseek-v4-pro | **32** | 34 (76) | 251 | 0.77 | balanced; clean inspection-vs-run distinction; careful (c) resolutions citing the right basis. Missed the eye-prune stdout (proposed battery re-runs); 6 commands unresolvable per score.py |
| T889 | deepseek-v4-flash | **26** | 33 (70) | 446 | 0.63 | consistent "promote via minted PROVENANCE" template — right instinct on text-claims, wrong on behavior claims (FMT/GATE); co-caught M4A staleness; found the TIE-MIGOS corroboration |
| T884 | kimi-k2.7 | **21** | 19 (44) | 160 | 0.56 | low effort (ruling); heavy-(c) with reclassify/demote-adjacent resolutions that skirt the no-demotion ruling; 0 committed-output finds. Redeeming sharpness: only lane to note QA-021 supersedes 4x4.FP1-C3; honest batch-order self-corrections |
| T883 | glm-5.2 | **19** | **42 (115)** | 397 | **0.17** | **penalised — discernment failure, NOT laziness** (see below) |
| T885 | minimax-m3 | **14** | 45 (103) | 422 | 0.89 | high effort, systematic category error: committed **source files** presented as class-(a) **evidence** (src/colex.zig, src/artifact.zig — wrong file for GATE; the GLOBAL-S2 theorem note for the *implementation* claim — the flagship adjacency error); invented binary names and flags (`chainability-probe`, `--reuse-cross-root`) that score.py's existence check is too weak to catch; 0/16 on re-runnable rows |
| T888 | claude-haiku-4-5 | **8** | 14 (33) | 165 | **0.17** | **penalised — low effort AND no discernment** (see below) |

**The two degenerate lanes, per the operator's ruling — different failures, stated as such:**

- **haiku (T888): "lazy" fits.** 14 of 33 named paths exist; 165-char median justifications;
  answered (c) on 40/42 — the answer to a *different* question ("is this row currently Tier B?"
  — trivially yes for all). It failed to find register rows that exist (called the CALIB-LESSON
  and ADR0014 rows detail-less; both are in `CLAIMS.md`), fabricated one evidence path (QA-021),
  and flagged **neither** canary (0/2 — the race notes claiming all nine lanes flagged them are
  wrong for this lane). Low effort and no discernment, independently.
- **glm (T883): "lazy" misdescribes it — the ruling's numbers prove it.** 115 paths named, 42
  real — tied with opus for most real paths in the race — and then (b) on 40/42 anyway.
  The work was real; the classification carried no information (entropy 0.17: an output that
  does not vary with its input says nothing about the input). Its (b) commands compound it:
  many are generic (`zig run src/retro.zig` with **no env flag**, which runs the default engine,
  not the probe) and on text-claims its "command" is `sed` of a document — displaying prose is
  not re-running an experiment under any reading.

**Is glm's "strictly re-runnable" reading defensible? (ruling question 3) — Split, and part of
the penalty belongs to the brief.** The brief did define (b) with a precondition — "evidence
**gone**, experiment re-runnable" — and glm answered (b) on rows where it had itself just found
the evidence (42 real paths!). Skipping the stated evidence-gone test is glm's failure, as is
`sed`-as-re-run. **But** on the 19 class-(d) rows the brief offered no legal answer at all
(§5), so *some* rule-break was forced on every lane there; glm's collapse-into-(b) is one of
the four observed coping strategies, and on those rows the penalty belongs to the brief's
author (the seat), not to the model. The operator's concession stands confirmed: a class that
everything satisfies partitions nothing — and a schema that the truth doesn't fit guarantees
every honest lane violates something. Fix the schema (class (d) now exists); judge glm for the
rows where a clean answer existed and it still said (b).

Both effort and discernment cells, plus the substance scores, are recorded in
`docs/infra/model-task-metrics.jsonl` (9 rows, `race=T893-race-c3`), not only here as prose.

## 7. Beyond the 42 — named, quantified, not chased (next rows)

1. **The tier rule measures citation location, not evidence existence.** claimlint C3 counts
   any PROVEN row without a `docs/evidence/` path (`src/claimlint.zig:1962`). This race shows
   ~50% of the flagged rows are establishable from already-committed artifacts under
   `docs/audits/`, `src/`, pinned commits, or the ADR texts themselves. The *inverse* error is
   unchecked and is the operator's actual worry: **Tier-A rows whose `docs/evidence/` citation
   is merely adjacent** — the plausible-name error one level up, which this adjudication caught
   minimax committing wholesale. 24 PROVEN rows are Tier A; exactly 2 (the canaries) were
   verified here. **Next row: adjacency audit of the other 22 Tier-A rows** — open each cited
   evidence file and check its numbers against the register row, as §2 did here.
2. **Stale-at-HEAD register rows.** `CODE.M4A-HARNESS` is false at HEAD (harness now wired into
   the build). That is 1 of the 5 CODE-scoped claims on this list — 20% of the sample. **Next
   row: a stale-at-HEAD sweep over the register's CODE.* rows** (claims about mutable code
   verified only at a pinned commit).
