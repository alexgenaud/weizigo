# Seed — landmark waypoints and standing rulings, 2026-08-23

**Author:** claude-fable-5/T771 (orchestration oversight seat), distilling the operator's
words from the T759→T771 discussion session. **Status:** RATIFIED intent — sprints spec
from this; specs are audited and ratified before build (the human bookend pattern, §5).

## 1. The L1 waypoint — the delegation-evidence lattice

Operator's intent, distilled: a **three-dimensional graph** whose dimensions are
**model capability × task type × task scope**. Each cell holds a ladder-or-similar and
describes, explicitly: **certainty**, **data richness/sparseness**, and
**relevance/distinctiveness**. From it: an enumeration of the most common task types and
scopes, the suggested model for each, and where the evidence is sparse.

Sampling policy is the operator's moving-average rule: **test more where evidence is
sparse, slow down where it is rich.** The lattice is a reporting-and-suggestion surface;
selection stays qualification-first (methodology §5), cost excluded from choice until the
T774 instrument-noise control readmits it. Feedstock: D027's task-type map, model-perf.md,
the T746-recovered token ledger (trust grades carried), race results (audited only, §4).

## 2. The L2 waypoint — the complexity boundary, named

Operator's intent, distilled: **push the complexity limits and resource requirements for
4×4 (or larger) gobans.** Walk the epistemic claims tree; challenge each claim with
alternative hypotheses; drive each to proven / falsified / verified /
unknown-untested-untestable-difficult (the last class is the most interesting and gets
tackled further, not shelved). Expected end state: smaller gobans proven/verified, and an
**identified complexity boundary** at 4×4 or larger — say exactly WHAT the threshold is
(unknown today; finding it is the goal) **and give it a name.**

## 3. Epic epistemology (operator ruling)

- **E1 (epic 1):** a self-contained epistemic tree from axioms and premises through
  conclusions — a provably perfect/optimal game of Go. Within E1, axioms and premises
  change ONLY if they lead to incoherence or impossible conclusions.
- **E2 (epic 2, future):** a NEW axiom set — relaxed heuristics, different premises or
  methods — expected to lead to DIFFERENT meaningful conclusions (perfect play at larger
  gobans via well-understood compromises). The configurable-rules pivot material seeds E2.
- Global decisions/axioms MAY stay separate from epic-specific working-hypotheses for now
  (no early refactor); theoretically an epic is self-contained.

## 4. Race protocol v2 (seat decision, first principles — operator invited to argue)

1. **Pre-registered rubric:** criteria and weights are fixed in the race brief BEFORE any
   lane runs; the judge may note unregistered dimensions but not score them (they become
   the next race's criteria).
2. **Hermetic lanes:** byte-identical briefs; each lane writes only its own
   `untracked/race-*/lane-<id>/` dir; lanes never commit and never cross-read.
   Attribution lives in a sidecar manifest, never inside the artifact.
3. **Mechanical blinding:** a collection script (not a model) gathers outputs under
   content-hash names. Blinding is a mechanism, not judge discipline.
4. **Judging:** one fresh blind judge scoring per-criterion with evidence quotes; rubric
   anchored in checkable facts (citations resolve, tests pass, claims verified) over taste
   — this also blunts style-fingerprinting, which hashing cannot remove.
5. **Family rule:** prefer a judge with no lane in the race. When every family competes,
   judge anyway and write the result with `audit: unaudited`; a different-family
   confirming judge upgrades it to `audited`. **model-perf scores audited results only.**
   (Race W is retro-marked unaudited: its committed text stands; its win is not evidence.)
6. **Two-field ledger write:** verdict + audit status, extending the ratified two-field
   verdict ruling.

Known gaps, stated: style fingerprinting is mitigated, not eliminated; the confirming
judge doubles cost exactly when all families compete (rare); pre-registration can miss
emergent dimensions (handled by note-don't-score).

### 4b. Race protocol v2.1 amendments (operator rulings, 2026-08-24, via the T871 seat)

7. **Panels are odd** (3 or 5), so a bare tie cannot stall a race.
8. **A split is first read as merge guidance, not as a deadlock.** Judges score
   per-criterion (rule 4); when a split falls along *dimensions* (one lane wins content,
   another craft), the default resolution is a merge of the best of both, recorded as
   such — a manufactured single winner would destroy exactly the information the split
   carries. Race W Section B is the worked example: the committed hybrid dominates both
   pure lanes.
9. **The seat adjudicates stalls from primary sources.** Racing is not a democracy: a
   tied or stalled race escalates to the reserve seat (Fable when available), which
   judges the lanes directly and writes its reasons; the operator's panel is the appeal,
   not the default.
10. **Two verdicts per race, never one:** the *document* decision (what text/patch is
    adopted) and the *model-performance* entry (which strengths each lane demonstrated)
    are separate write-ups. A near-tie with complementary strengths is a legitimate
    performance verdict even when the document decision names a single base.
11. **No self-judging, ever** — a lane's author never scores its own race (Race W's
    original grade was the violation; the blind panel declined to confirm it). And a
    second independent reading receives **the field only** — never the first reading's
    hinge or conclusions (the D083 lesson: a supplied hinge turns independence into
    corroboration).

## 5. Process rulings (operator, verbatim intent)

- **The long-living Orchestrator role is retired.** The discussion-dispatch protocol
  replaces it: discussion consoles drive to decisions, queue rows, dispatch, close. A
  reconciliation seat exists only while multiple refactorizations conflict, then closes.
- **Human bookends:** the human states "what I want and what I will get" before a sprint,
  and judges "did I get what I wanted" after. Between the bookends, sprint managers own
  spec → audit loops → design → research → scope → acceptance tests → build →
  verification → acceptance, with development best practices and evidence-based science.
  Without the bookends, agents spin. The human does not need the details; the human
  always demands simple robust elegance.
- **No bandwidth split is specified** between science and tooling: do both; dispatch
  whatever is spec'd and ready.
- **ox-alpha:** free while the blind test runs; test and compare it at every reasonable
  opportunity; never penalize it on speed (throttling from popularity was observed).
  Identity reveals later; on reveal, update data and adjust — no pre-built ceremony.
- **Science-starvation visibility:** one dashboard datum (queue head shows a science-row
  count of zero loudly), never a gate. Valuable as a datum; ceremony as a refusal.
