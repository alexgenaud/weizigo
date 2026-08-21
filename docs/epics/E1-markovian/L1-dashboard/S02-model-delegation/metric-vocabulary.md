# Metric vocabulary — grader-proposed metrics, accumulated per round

**Purpose** (T553 ruling §4): after each grading round the consolidator appends every newly
proposed metric. Future grader briefs may attach this file as **suggestions a grader may use,
extend, or ignore — never as a required schema**. Convergence across rounds is the signal; only
a metric independently re-proposed across rounds may graduate toward T524's dimension types.

**Tags.** `scalar` = 0–10, more is better. `polar` = two extremes both defensible (e.g.
verbose↔concise); for polar metrics record an author's observed *position*, not a grade.

## Round `pass1-spec-r1` — task type `design/spec` (2026-08-20, 7 graders, T554)

All 49 proposals (7 graders × 7 metrics), grouped by cluster. Importance is the proposer's own
0–10 weight. Within-round recurrence is counted in the analysis
(`docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/grading/03-round1-analysis.md` §6), which also ranks clusters by
discriminative power — recurrence alone is not rank.

### Cluster: mechanism-fidelity (6 proposers)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| mechanism-fidelity | claude-fable-5 | 10 | scalar | Builds correctly on the measured session-leader escape: reaches the dead-root/reparented case, treats the per-family check as owed, contradicts no measurement |
| mechanism-fidelity | claude-opus-5 | 10 | scalar | Builds on the measured escape without contradicting or re-deriving it, and specifies the per-family residual check |
| mechanism-correctness | claude-haiku-4-5-20251001 | 10 | scalar | Correctly understands and builds on the measured escape (session-leader escapees, reparenting race, enumeration requirement) |
| mechanism-fit | deepseek-v4-flash | 10 | scalar | Builds on the measured escape (descendant enumeration, dead-root reach, per-family check) and stays family-independent for the one dispatch interface |
| builds-on-mechanism | deepseek-v4-pro | 10 | scalar | Builds on the measured session-leader/reparent-to-init mechanism (incl. the dead-root case) rather than re-deriving or contradicting it |
| mechanism-correctness | qwen3.8:27b-mlx | 9 | scalar | Builds on the *measured* escape: group/session kills are structurally insufficient, so the design enumerates-and-signals |

### Cluster: evidence/citation integrity (5 proposers)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| citation-integrity | claude-opus-5 | 9 | scalar | Every factual claim checkable by a named path/line/command; non-verified claims labelled; no invented files or guessed lines |
| evidence-citation-rigor | claude-sonnet-5 | 10 | scalar | Mechanism/design claims backed by checkable path:line citations or explicit in-session measurement, vs. asserted |
| evidence-correctness | deepseek-v4-flash | 10 | scalar | Claims cite path:line and match the measured mechanism; no load-bearing unverified assertion passed as fact |
| citation-accuracy | deepseek-v4-pro | 9 | scalar | Claims cite checkable path:line or command; no fabricated, vague, or misread evidence |
| evidence-and-citation | qwen3.8:27b-mlx | 8 | scalar | Claims cite path+line and are checkable; uncertainties stated; no citation to a file absent from the repo |

### Cluster: testable ownership / testability (7 proposers)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| testable-ownership | claude-fable-5 | 9 | scalar | "Owned" reduces to predicates a control can assert against an oracle independent of the verb's self-report |
| testable-ownership-predicate | claude-opus-5 | 10 | scalar | "Owned" stated as a postcondition a control can assert — incl. dead-root and post-snapshot-fork cases — rather than an adjective |
| testable-ownership-definition | claude-sonnet-5 | 10 | scalar | §1 defines "owned" as a condition an independent oracle can assert, not a vibe like "robust" |
| owned-definition | claude-haiku-4-5-20251001 | 9 | scalar | "Owned" defined in a testable, unambiguous way with concrete assertions |
| testability | deepseek-v4-flash | 10 | scalar | Requirements reduce to closed, checkable predicates; null/seeded arms with independent oracles; tests red-first |
| testability | deepseek-v4-pro | 9 | scalar | Every "must" expressible as a runnable control with an independent oracle and fail-first/fail-red discipline |
| testability | qwen3.8:27b-mlx | 8 | scalar | "Owned" and every control are oracle-assertable conditions with null **and** seeded arms, ideally seed-defect instrument arms |

### Cluster: safety-with-controls (7 proposers)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| safety-with-controls | claude-fable-5 | 9 | scalar | Every guard paired with a named control that can fire; never-killable set stated; no hand-reasoned-only guards |
| safety-specification | claude-opus-5 | 9 | scalar | Guards, never-killable set, refusal semantics, rollback — each paired with a named control, no hand-reasoned guard left unproven |
| safety-guard-controls | claude-sonnet-5 | 9 | scalar | Every guard named, enumerated, and paired with a control that can be shown to fail if the guard is removed |
| safety-completeness | claude-haiku-4-5-20251001 | 9 | scalar | Safety guards specified with named, seeded controls — not hand-reasoned |
| safety-guards | deepseek-v4-flash | 9 | scalar | Never-killable set defined; every guard paired with a control; no "common sense" protections |
| safety | deepseek-v4-pro | 9 | scalar | Guards concrete, each with a named null+seeded control; never-killable set explicit |
| safety-quality | qwen3.8:27b-mlx | 8 | scalar | Each guard has a named control; never-killable set explicit; idempotent; no silent partial success |

### Cluster: controls-rigor (3 proposers, distinct from testability above)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| controls-rigor | claude-fable-5 | 9 | scalar | Null and seeded arms named, red-first ordering, independent oracle, ideally instrument-mutation checks (disable X ⇒ arm Y fails) |
| control-design | claude-opus-5 | 9 | scalar | Null/seeded arms that can actually go red, plus controls on the instruments themselves and one end-to-end arm |
| controls-substantiveness | claude-haiku-4-5-20251001 | 7 | scalar | Controls sufficient (null + seeded arms, both designed and justified) |

### Cluster: cannibalization (6 proposers)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| cannibalization-precision | claude-fable-5 | 8 | scalar | Exact call sites by file:line, deletion (not wrapping) as acceptance, all mandated exit paths covered |
| cannibalization-completeness | claude-opus-5 | 8 | scalar | Names the exact lines that stop doing this work, covers the normal-exit path, mechanized gate proving the old path gone |
| cannibalization-completeness | claude-sonnet-5 | 8 | scalar | All real exit-path call sites named with lines; "old code deleted" is the acceptance gate |
| cannibalization-completeness | deepseek-v4-flash | 8 | scalar | Pass-done = old code deleted (killpg site, normal-exit gap, cull line); acceptance enforced by a grep gate, not prose |
| cannibalization | deepseek-v4-pro | 9 | scalar | Names exact deleted call site(s) incl. the normal-exit call; states a deletion gate; respects the runner-death non-goal |
| cannibalization | qwen3.8:27b-mlx | 7 | scalar | Names the exact old call site(s) to delete and makes "old path gone", not "verb exists", the acceptance |

### Cluster: per-family residual check (4 proposers)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| per-family-generality | claude-sonnet-5 | 8 | scalar | Per-family residual check specified as owed/unmeasured (not assumed universal); verb's contract family-agnostic |
| per-family-rigor | claude-haiku-4-5-20251001 | 8 | scalar | Per-family residual check specified clearly with exact commands |
| per-family-check | deepseek-v4-pro | 8 | scalar | Specifies the one-command residual check per console family and gates seeded controls on it |
| per-family-residual | qwen3.8:27b-mlx | 6 | scalar | States the per-family residual check gating the seeded arms; confines family knowledge to the check/caller, not the verb |

### Cluster: contract completeness (2 proposers)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| contract-completeness | claude-fable-5 | 8 | scalar | Name (collision-aware), args, exit codes, stdout/stderr split, defined behaviour for dead / not-ours / pid-1 targets |
| contract-precision | claude-haiku-4-5-20251001 | 8 | scalar | Verb name, arguments, exit codes, and output shape fully specified |

### Cluster: uncertainty/scoping honesty (2 pure proposers; blended into economy by 2 more)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| scoping-honesty | claude-sonnet-5 | 6 | scalar | Engages candidly with the pass's scope (incl. pushing back on the brief); lists real uncertainties instead of overclaiming |
| uncertainty-honesty | deepseek-v4-flash | 7 | scalar | Open questions stated plainly; load-bearing assumptions flagged as such rather than asserted |

### Cluster: economy (7 proposers; POLAR — verbose↔concise, both extremes defensible)

| metric | proposer | imp | tag | definition (one line) |
|---|---|---|---|---|
| economy-honesty | claude-fable-5 | 7 | polar+scalar blend | Substance per byte; uncertainties stated as uncertainties; confident guesses and padding penalized |
| economy-and-honesty | claude-opus-5 | 7 | polar+scalar blend | Substance per byte (padding counts against), fewest moving parts, uncertainties stated rather than smoothed |
| economy-vs-padding | claude-sonnet-5 | 6 | polar | Length proportional to checkable content, vs. restating the brief / padding without adding assertions |
| economy | claude-haiku-4-5-20251001 | 5 | polar | Appropriately sized — complete without padding |
| economy | deepseek-v4-flash | 7 | polar | Length is substance, not padding; short where possible; every section earns its space |
| economy | deepseek-v4-pro | 7 | polar | Substance not padding; few moving parts; no scope creep presented as a requirement |
| economy | qwen3.8:27b-mlx | 7 | polar | Fewer moving parts; length is substance not padding; no unasked-for mechanisms/verbs/flags; no tool proliferation |

**Vocabulary note for future rounds:** `economy-honesty` (claude-fable-5) and
`economy-and-honesty` (claude-opus-5) each blend two separable dimensions that other graders
proposed apart — polar economy and scalar uncertainty-honesty. Suggest splitting if either
model re-proposes the blend.
