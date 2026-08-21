# T553 — Ruling on the grading design (pass-1 spec tournament)

**Author:** claude-fable-5/T553 · **Date:** 2026-08-20 · **Status:** RULING — first and
final word (`docs/infra/delegation/ROLES.md`, Adjudication authority, operator ruling
2026-08-20). Inputs weighed separately: `00-operator-proposal.md` (the operator's design,
verbatim) and `01-seat-feedback.md` (the seat's six concerns, S1–S6).

## The ruling in one paragraph

**Run the operator's design, one round, now.** Each grader proposes its own metrics
(3–7), states each metric's importance 0–10 once (all nine documents are the same
artifact type, so importance is a property of the metric, not of a cell), scores every
anonymized document 0–10 per metric, and — the primary output — gives each document a
coarse verdict *great / good / average / bad / terrible* plus one sentence of nuance,
and one overall best-to-worst ranking line. Output is one markdown file per grader with
fixed table columns; that is the entire concession to structure. The grand-race §5
controls (null pair, seeded weak artifact, G3 family exclusion, G4 blinding) stay: they
are ratified protocol, and they are "never trust a green test" applied to the grading
instrument itself — this is the instrument's first reading, so it is exactly the reading
that does not count without a null and a seeded control. No second round. Metrics
accumulate into a vocabulary file and are offered — never imposed — to later rounds.

## 1. The instrument

**Setup owed by the seat before dispatch** (graders never see this): anonymize the seven
specs per G4 (strip self-identifying text; a lane that self-identifies is noted as a
data point) into `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/grading/anon/` as `spec-A.md` … . Insert
one near-duplicate of a randomly chosen spec (cosmetic edits only — the null control)
and one deliberately weakened spec authored by the seat and sealed pre-round (the
seeded control). Shuffle labels. Nine documents. The label→author key and the two
control identities are sealed (committed hash) until consolidation.

**The grader brief, verbatim** — dispatched identically to each of the seven lane
models; document phase, so all seven run in parallel, each writing only its own file:

---

You are grading anonymized spec documents from the pass-1 tournament. One of them may
be yours; grade it like the others. Do not name yourself; do not try to identify
authors — an authorship guess is noise, not insight.

INPUTS: the nine documents `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/grading/anon/spec-A.md` …
`spec-I.md`, and `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/00-spec-tournament-brief.md` (what
the spec authors were asked to produce and how they were told they would be judged).

WRITE exactly one file: `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/grading/grades/<your-lane-label>.md`.
Read nothing else in `grades/`. Four sections, exactly this shape:

## 1 Metrics
Propose 3–7 metrics — what YOU think separates a good spec from a bad one on this
task. Your choice; no schema is imposed. You may adopt, split, or ignore the
tournament brief's stated criteria. One row per metric:
| metric (kebab-case) | definition (one line) | importance 0–10 |
Importance = how much this metric matters for this kind of artifact (10 = decisive,
0 = irrelevant). Rate honestly; importance is scored separately from quality.

## 2 Scores
One row per document per metric, 10 always best:
| doc | metric | score 0–10 | justification (one line) |

## 3 Verdicts
One line per document:
`spec-X: <great|good|average|bad|terrible> — <one sentence of nuance, plain words>`
The sentence is the payload — "thorough but lacks nuance", "wordy without content",
"precise and concise but overlooked the residual check" — not a restatement of the
grade.

## 4 Ranking
One line, best → worst, ties with `=`: e.g. `C > A = F > B > D > I > E > G > H`.

Rules: judge only what is on the page against what the tournament brief asked for.
When a justification makes a factual claim about a document, cite its section. Byte
count is not quality: the documents span a 2.3× size range on a brief that said
"length is not a virtue" — decide per document whether the length is substance or
padding, and say "padding" when you see it.

---

**Cost check:** nine documents × ≤7 metrics ≤ 63 score rows + 9 verdict lines + 1
ranking line per grader, seven graders in parallel with unique output files and no
worktrees. Minutes, as required.

## 2. One round, not two

The optional second round is **not dispatched**. What round 1 buys is discovery — the
metric vocabulary and the verdicts. What round 2 would buy is aggregability across a
curated union of metrics; but the consolidation this feeds (ladder phase 2, a fresh
Fable instance) does not need cross-grader metric algebra — the shared axes are the
mandatory verdicts and rankings, which every grader emits in the same shape. If
consolidation actually blocks on incomparability, a targeted re-scoring round on a
curated union can be dispatched then, justified by an observed failure instead of an
anticipated one. That is the operator's "learn from experience" caution applied to the
operator's own optional round.

## 3. Seat concerns — dispositions

| # | concern | disposition |
|---|---|---|
| S1 | metric incomparability | **Real risk, wrong remedy.** The two-round mitigation is rejected — it is the anticipatory complexity the operator warned against. The shared axis already exists: the mandatory verdict + ranking. Revisit only if consolidation observably blocks. |
| S2 | self-serving importance weights | **Accepted as written** — no instrument change; the seat itself proposed only a statistic. Consolidation computes whether each grader's importance weights track its own artifact's strengths. Free, and it is skill-matrix gold. |
| S3 | 0–10 compression | **Half-adopted.** One overall ranking line per grader (near-free insurance that survives scale compression). Per-metric rankings rejected — that is N extra cells for a problem not yet observed in this instrument. |
| S4 | report disagreement, not means | **Adopted as a consolidation instruction** (§5 below). Costs graders nothing. |
| S5 | make it parseable | **Adopted.** The fixed four-section shape above. This is not an anticipated problem — 7 graders × 9 documents × N metrics in free prose is unconsolidatable by construction. |
| S6 | cost | Noted; no action. The isolation ruling already makes this minutes. |

**On the invited question "does the seat over-design":** mostly no. Four of six
concerns are free (analysis notes or necessary plumbing), one is half-price insurance.
Exactly one — S1's second scoring round — is over-design, and the seat's own
argument-against-itself already said so. Rejected on the seat's own reasoning.

## 4. Accumulation

Create `docs/infra/races/metric-vocabulary.md`. After each grading round the
consolidator appends every newly proposed metric: name, one-line definition, proposer
(canonical label), round, and — on later rounds — how many graders independently
re-proposed it. Future grader briefs attach the vocabulary as **suggestions a grader
may use, extend, or ignore — never as a required schema**. Convergence is the signal:
a metric independently re-proposed across rounds is a discovered dimension; only then
may it graduate toward T524's dimension types. This honors both "metrics accumulate"
and "do not impose a fixed dimension schema up front".

## 5. Consolidation instructions (ladder phase 2, fresh instance)

1. **Validity first** (grand-race §5): a grader's round is invalid if the null pair's
   verdicts differ by more than one step, or if the seeded weak artifact lands in the
   top half of its ranking. Invalid rounds are retained and analyzed, never counted.
2. **Count only non-family grades** (G3). Self and family grades are retained;
   compute `self_preference_bias = self_grade − mean(non-family grades received)` and
   the S2 importance-weight statistic per grader.
3. **Report spread, not just centers** (S4): any document where counted verdicts span
   ≥2 steps is itself a finding — name the cell and the divergent justifications.
4. **Claude-vs-Claude orderings on panel data alone are low-confidence** (three
   countable graders) — label them as such; never present one as a finding.
5. **Recording rule per `LADDER.md`:** one coarse grade + one sentence of nuance per
   model into the ledger; grade records appended mechanically to
   `docs/infra/races/grand-race-ledger.jsonl` per grand-race §6, never by hand.
6. Append new metrics to the vocabulary file (§4 above).

## What this ruling deliberately does not do

No new tooling, no daemon, no JSON output demanded from graders (markdown tables
convert mechanically at consolidation), no dimension schema, no second round, no
change to ratified §5/G3/G4 protocol. The qualitative register the operator asked for
is Section 3 of every grader's file, and it is the primary output, not a garnish.
