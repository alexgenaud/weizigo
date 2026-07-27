# Model-performance observations (untracked scratch — impressions, not science)

TODO: record the general facts about each model. Then keep notes of each model in different contexts or with different tasks.

## Model versions (record here as they change)

- GLM-5.2 (worker, boss/orchestrator) — glm-5.2:cloud, context 950 k
- **Minimax-m3** (worker) — minimax-m3:cloud
- **Kimi-k2.7** (worker / auditor) — kimi-k2.7-code:cloud, context ~556 k

Small-n, single-session anecdotes per model. Strengths/weaknesses only — speed
and cost are not differentiators here. Add a dated entry each session.

## GLM-5.2 (Boss, orchestrator)

- Strong on subtle foundational/logical reasoning: caught the E2 V1-equation
  bug (`oppV0[child]` not `oppV1[child]`) by reading the sweep; flagged the
  least-fixpoint crux (from-+N reaches greatest, not refuting least) in the
  audit brief — the same crux Kimi then convicted.
- Holds the orchestrator role well (delegation files, relay log, rollback
  discipline, epistemic bookkeeping). Tends to long messages — needs the
  "short volley" reminder.
- Context window 950 k; measured ~300 k used at one point (no compaction).

## Minimax-m3 (worker)

- Strong at careful, thorough *spec-first* execution once corrected: wrote a
  270-line B1 spec, self-flagged ambiguity, asked before interpreting — good
  discipline after being corrected for implement-first eagerness.
- Honest and careful with caveats. Reverts/flags its own uncertainty.
- Weaker on deeper monotone-fixpoint theory: proposed the unsound (a′)
  ("canonical isn't the least") from the +N re-converge result — a
  monotone-map misread (greatest > least is expected). Corrected by the
  Kimi audit. So: excellent implementer/spec-writer; needs a theory auditor
  on foundational claims.

## Kimi-K2.7 (auditor, one data point so far)

- Strong *ruthless auditor*: convicted the (a′) Blocker precisely via
  Knaster–Tarski (monotone map: bottom→least, top→greatest; greatest > least
  is normal, doesn't refute least). Graded findings cleanly
  (Blocker/Critical/Should/Nice), gave a crisp Boss verdict, implemented
  nothing, wrote the full audit to the response file + console summary +
  the one-liner exactly as instructed.
- Also caught the wrong §3 acceptance test and the misleading
  ko_sensitive_b=0 print. Followed instructions to the letter.
- First impression: excellent at critique/verification; worth using as the
  standing auditor for foundational claims.

## Cross-model takeaway (early)

- GLM-5.2 + Kimi-K2.7 converge on the subtle theory; Minimax-m3 is the
  workhorse but benefits from a theory audit. Pattern: Minimax implements →
  Kimi audits → GLM-Boss adjudicates & integrates. Worth measuring more.

## Kimi-k2.7-code (new Boss, 2026-07-25)

Taking over as Boss from GLM-5.2. First task was to ingest the full epistemic
state before managing parallel workers. Read order that worked:
`PROGRESS.md` → `status/leak-crisis.md` → `status/CURRENT.md` →
`boards/4x4/EPISTEMIC.md` + `boards/CONCEPTS.md` + `names.md` →
`agent-workflow.md` → the completed worker outputs (`T04-minimax.md`,
`T05-audit-proven.md`, `T06-audit-falsified.md`, `T08-killx-reexamine.md`).

### Quality report on the parallel batch just completed

- **Minimax-m3 — T04 doc pruning:** excellent. Followed the negative
  constraints exactly (`src/`, `AGENTS.md`, `PROGRESS.md`, `boards/`,
  `CURRENT.md`, artifacts untouched). All seven subtasks done in ~25 min.
  Produced concise, well-structured output. The only minor improvement:
  could have noted approximate line counts in each condensed research file
  inline rather than just the total. Strong executor once given a bounded,
  mechanical task.

- **GLM-5.2 — T05 audit of ✅ PROVEN claims:** very strong. Did not just
  accept labels; separated theorem from measurement, identified S4 and FP3
  as misfiled under PROVEN, and gave the honest 4×4 boundary answer
  (C2 untestable at 4×4; boundary is 3×3→4×4). The audit is almost a small
  decision document in itself. Grade distribution was fair and actionable.

- **Kimi-k2.7 (worker) — T06 audit of ❌ falsified claims:** excellent
  plain-English rigor. For each falsification it answered (a) where tested,
  (b) what exactly is falsified vs what survives, (c) why it is false in
  human terms. The summary table is a clean decision artifact. No code
  touched, as instructed.

- **GLM-5.2 — T08 kill-X% re-examine:** good code-level verification
  (proved 4×4, instant-end, not tested capture-all). Honest about the open
  gaps: the direction mechanism is claimed not proven, and the ko-sensitive region
  structure (small-capture tangles vs big swings) is not directly measured.
  Recommended a cheap capture-all probe; this is a useful next step if the
  user wants it closed.

### Cross-model takeaway (updated)

The GLM-Boss + Kimi-auditor + Minimax-worker pattern from `model-perf.md`
held up in this batch. Kimi (as auditor) and GLM (as Boss/auditor) converge
on subtle theory; Minimax is a reliable implementer/doc-pruner for bounded
tasks. The new Boss (this instance, Kimi-k2.7-code) needs to stay disciplined
about not drifting into implementation while orchestrating.

### First impression as Boss

The documentation tree is genuinely usable for a fresh handover —
`PROGRESS.md` + `status/CURRENT.md` gave the live state, and the per-board
`EPISTEMIC.md` gave the precise claim map. The biggest friction was the
sheer number of untracked scratch files; a consolidated index or a
"last N completed tasks" section in `CURRENT.md` would speed up resumption.
The quality of the parallel outputs is high enough that the Boss's main job
is now integration, prioritization, and deciding the next experiment (likely
C2-probe at 2×2/3×2 or capture-all kill probe at 4×4).

## Minimax-m3 — T07 audit of open hypotheses (second data point, 2026-07-25)

**Role:** hypothesis/experiment auditor. **Task:** read-only review of the ⬜
claims in `docs/boards/4x4/EPISTEMIC.md` and the experiment plan; grade design,
vacuous-pass risk, null hypothesis, falsifiability, cheaper alternatives, and
parallelization. **Output:** `untracked/T07-audit-hypotheses.md` (~42 KB).

**Strengths shown:**
- Excellent systems-level thinking about what each experiment actually tests
  vs. what it claims to test.
- Produced a genuine parallelization map (Wave 0/1/2/3) with dependency edges
  and serial gates.
- Caught the "tests the wrong artifact" problem for F2/F3 (committed artifact
  uses the unsound `ko_ref >= d` guard; validating writes-off requires a regen).
- Caught the underspecified C2-probe (no sample size, no ban-set distribution,
  no long-history coverage) and the missing 2×2/3×2 pilot.
- Correctly identified that FP1 least-ness is Knaster–Tarski from `-N` seed,
  and that the re-converge-from-`+N` test is a multi-fixpoint observation, not
  a least-ness witness.

**Weaknesses / caveats:**
- A few time estimates feel optimistic ("~hour" for S2-4×4 exhaustive Benson;
  "~minutes" for C2-pilot-2×2/3×2). Should be treated as orders-of-magnitude
  until measured.
- The C2-bounded vs. C2-general distinction is framed as a doc fix, but the
  underlying mathematical question (can L==H ever fail for arbitrarily long
  histories?) remains open and possibly unprovable by finite methods.

**Updated cross-model takeaway:**
Minimax is not only a strong implementer; with the right framing it can
also audit experiment design. The pattern is becoming: **Minimax specs/
implements, Kimi theory-audits, GLM integrates/adjudicates, and any of the
three can do read-only audits when the scope is tightly bounded.** The
bottleneck is not model capability but task clarity and parallelization
hygiene.

## User direction — Boss protocol update (2026-07-26)

User clarified expectations for the Boss role and project workflow:
- C2 scope: attack bounded-history first; unbounded-history is a separate
  research question.
- Build budget: no long-term ceiling, but tasks must be ≲1h chunks, fail-fast,
  recoverable; night runs allowed but still chunked.
- Capture-all: wait for T15 design before deciding.
- Doc-first vs. run-first: Wave 0 runs in parallel with T16.
- Boss must make decisions, document them, and provide delegation prompts.
- User is worried about dead ends and unreliable proofs, not about too much work.
- These directives were recorded in `docs/agent-boss.md` and `docs/status/CURRENT.md`.

## Boss workflow refinement (2026-07-26, user feedback)

User corrected the Boss delegation style:
- Prompts must be **one line, ~50 characters** (e.g. `fresh Kimi: follow untracked/T99-tripleko.md`).
- The human may add a prose paragraph for understanding, but the agent prompt is the one-liner.
- `fresh` = human starts new session; `warm` = continue a specific named session; omit both if indifferent.
- Task files are **living docs** with subtask statuses (`open`/`progress`/`success`/`failure`), preconditions, and an output section.
- Only one agent writes a given file; audit variants use `-audit` suffix.
- Findings move to git-checked `docs/` once stable; scratch files are cleaned up after use.
- Boss updated `docs/agent-boss.md` with these conventions and declared it open to refinement/pruning.

This feedback was applied to `docs/status/CURRENT.md`, all task files, and the prompt file.

## Task completions (2026-07-26)

- **GLM-5.2 — T10 FP1 verification:** completed. Reported PARTIAL verdict:
  zero V0+V1 violations on the SOUND subset (10,995,122 positions, all whose
  children are core-or-settled), but 211,495 informational violations on the
  ALL set attributed to finisher/fixpoint mixing. WZO1 schema drops V1 quads,
  limiting full artifact-based check. Recommended follow-up: `RETRO_B1_LOFIX`
  on 4×4 (full in-RAM re-converge). Quality: strong read-only engineering;
  self-aware about limitations.
- **Kimi-k2.7 — T15 capture-all design:** completed. Produced a concise design
  with rule variant, ~12-line code footprint across `src/retro.zig`, and a
  4×4 census plan. Did not implement. Quality: clear, bounded, actionable.

## Task completion — T11 D3-4×3 pilot (2026-07-26)

- **Minimax-m3 — T11 D3-4×3 writes-off tractability pilot:** completed.
  Verdict: **GO (with caveats)**. Measured 4×3 writes-off finisher at 33.3 s
  vs reuse at 2.7 s (12.23× wall, 16.62× nodes, 28.25× max/root). 4×4 build
  8.5 min, 819 MiB peak. Estimated 4×4 writes-off finisher 45–75 min at
  100–200M/root, peak 3–5 GiB. Provided clear chunked plan and risk list.
  Quality: excellent measurement + honest uncertainty quantification.

## User correction — small-board C2 is not evidence for 4×4 (2026-07-26)

User rejected the framing that a C2-pilot on 2×2/3×2 constitutes evidence for
4×4. It is strictly a **falsification test / method calibration**:
- If C2 fails at 2×2/3×2 → C2 collapses everywhere.
- If C2 passes at 2×2/3×2 → it is not obviously false, but proves nothing about
  4×4 without a monotonicity theorem (which does not exist yet).

Boss updated `docs/agent-boss.md` (no pre-provided future prompts; `fresh` is
the normal dispatch mode), `docs/status/CURRENT.md`, `untracked/T12-minimax.md`,
`untracked/T13-minimax.md`, `untracked/T16-glm.md`, and the prompt file to
reflect this correction. Also noted that a 5-hour Ollama token limit hit;
sessions terminated; T16 resumed without data loss.

## Task completion — T16 EPISTEMIC/CONCEPTS rewrite (2026-07-26)

- **GLM-5.2 — T16 doc rewrite:** completed. All output-section checkboxes
  ticked; result reported as DONE. Will review the actual content once the
  file is read. Quality pending review.

## Task completion — T10-fp1-audit (2026-07-26)

- **Kimi-k2.7 — T10-fp1-audit:** completed. Read-only audit of GLM's T10
  verdict. Confirmed the SOUND-subset definition is correct, the 211,495 ALL-set
  violations are expected finisher/fixpoint mixing, and PARTIAL is the honest
  verdict. Recommended `RETRO_B1_LOFIX` on 4×4 to close to full PASS. Quality:
  rigorous, well-structured, actionable.

## Workflow refinement — agent lifecycle and prompt timing (2026-07-26)

User clarified:
- The user manages agent lifecycle: can kill idle sessions, spawn up to 4–5
  agents. The Boss does not track free/idle sessions.
- When the user says "we wait on X," the Boss updates `CURRENT.md` to say
  "WAITING on X" and lists the next dispatch order; no new prompts offered.
- Prompts are provided only for dispatchable-now tasks; future prompts are
  stated in prose in `CURRENT.md`, not as copy-paste one-liners.

These rules were added to `docs/agent-boss.md` and applied to
`docs/status/CURRENT.md` and `untracked/delegation-prompts-2026-07-26.md`.

## Task completions — T09 and T17 (2026-07-26)

- **Minimax-m3 — T09 S2-4×4 Benson regression:** completed. Added
  `naive_pass_alive`, `pass_alive_regression_check`, and 4×4 exhaustive test in
  `src/rules.zig` plus standalone drivers. Checked all 24,318,165 legal 4×4
  positions: 0 mismatches, 0 immediate-capture violations. Also validated via
  deliberate bug injection. Quality: strong engineering + sensitivity proof.
- **GLM-5.2 — T17 F4-4×4 KM deps design:** completed. Produced detailed design
  with commands, byte-compare procedure, auditor plan, wall/RAM estimates,
  risk list, halt conditions, and epistemic framing. Quality: thorough,
  actionable, honest about scope.

## Task completion — T14.1 bracket-only converge (2026-07-26)

- **Minimax-m3 — T14.1:** completed PASS. 4×4 writes-off bracket-only artifact
  produced at `untracked/oracle-4x4-writesoff-bracket.wzo` (258 MB, sha256
  recorded). 24,318,165 legal positions; 38,268,408 certified slots (78.68%);
  10,367,922 ko-sensitive (21.32%). Small `src/retro.zig` fix needed to skip
  finisher cleanly in bracket-only mode. Wall ~10.5 min. User redirected: skip
  T14.2 now, dispatch T12 (C2-pilot-2×2) next; T14.2 contingent on C2 results.

## Boss reflection — Minimax bottleneck (2026-07-26)

User observed that the Boss was routing most implementation tasks to Minimax.
Reasons: (1) accidental path dependency (Minimax picked up the first engine
chunks), (2) one-writer-per-engine-file rule meant Minimax held `src/retro.zig`
for T11/T14, and (3) Minimax had a strong track record (T02, T09, T11, T14.1).
However, this created an unnecessary bottleneck. Boss added a principle to
`docs/agent-boss.md` to avoid single-worker bottlenecks and reassigned T13 to
Kimi and T14.3 to GLM. T12 remains Minimax because it owns the harness creation.

## Kimi-k2.7 — T15 capture-all design review (2026-07-26)

**Task:** read-only review of the capture-all kill-probe design in
`untracked/T15-kimi.md`. Recommend implement / defer / skip / modify.

**Strengths shown:**
- Carefully separated "well-defined / distinct" (high confidence) from
  "predicted outcome" (reasoned speculation), matching the project's
  epistemic discipline.
- Gave a concrete example showing why capture-all differs from kill-X%:
  wiping 3/16 stones triggers capture-all but not kill-30%.
- Honest about the helper-style caveat in `Retro.sweep` and the need to
  resolve it before coding.
- Clear recommendation with two independent reasons: core-gate priority
  + engine-file concurrency (`src/retro.zig` held by T14).
- Produced an actionable pre-impl checklist (helper style, census sentinel,
  auditor gate, artifact path).

**Weaknesses / caveats:**
- The "no collapse" prediction is explicitly flagged as speculation; not a
  weakness, but a limit on what the review can claim.

**Quality:** strong read-only judgment. The review is essentially a decision
brief, not just an opinion. Worth using Kimi for similar design-to-go/no-go
reviews.

## Boss handover — Kimi-k2.7-code resumed after compact (2026-07-26)

**Context verification:** read `HANDOVER.md`, `CURRENT.md`, `PROGRESS.md`,
`status/leak-crisis.md`, `agent-boss.md`, delegation prompts, and the active
`untracked/T*.md` files. State was self-contained; no data loss detected.

**Actions on resume:**
- Updated `docs/status/CURRENT.md` to say **WAITING on T12** and to fold in
  the just-completed T15-review result.
- Updated `docs/status/HANDOVER.md` with the same resumed state.
- Updated `untracked/delegation-prompts-2026-07-26.md` to remove
  not-yet-dispatchable prompts, per `docs/agent-boss.md` prompt-timing rule.
- Added backlog / blocked task list (T13, T14.2/14.3, T15-impl, T17-impl,
  T16-content-review, cleanup).
- Updated this file with T15-review and resumed-Boss notes.

**Takeaway:** the handover tree works. A fresh Boss instance resumed from
`HANDOVER.md` without needing to ask the user for state. The main friction
was the delegation-prompts file still carrying future prompts; fixed.

## Minimax-m3 — T12 C2-pilot-2×2 (2026-07-26)

**Task:** implement and run the C2-probe on 2×2 as a falsification test.

**Strengths shown:**
- Built a clean standalone probe (`untracked/c2pilot_2x2.zig`) with no engine
  edits, avoiding `src/retro.zig` contention.
- Honest verdict: **PARTIAL (tautological)** — recognized that 2×2 cannot
  host a non-trivial ban set and said so explicitly rather than dressing it up
  as a strong result.
- Provided concrete recommendations for T13 (generalize harness, find non-root
  cycles, construct ban sets from cycles).
- Fast: 1.2 s wall time.

**Weaknesses / caveats:**
- None significant; the task was calibrated exactly as designed.

**Quality:** strong execution + honest epistemic framing. Good model for
bounded probe tasks.

## Boss workflow refinement — bundled serial subtasks (2026-07-26)

User preference: instead of one-line prompts per subtask, give one agent a
bundle of ordered subtasks in a single file, with checkboxes and halt/continue
rules. The agent works serially without intermittent prompting. The Boss still
gives only the initial one-line dispatch prompt.

Applied: created `untracked/B01-kimi.md` containing T13 → T14.3 →
T16-content-review. Updated `docs/agent-boss.md` with the bundled-subtask
convention. Updated `CURRENT.md`, `HANDOVER.md`, delegation prompts, and this
file.

## Boss workflow refinement — parallel bundles (2026-07-26)

User asked whether a sequence of subtasks can run in parallel with another
agent/session while Kimi is already on T13. Decision: yes, for independent
read-only/standalone work.

Created two bundles:
- `untracked/B01-kimi.md` — Kimi: T13 (already in progress) → T16-content-review.
- `untracked/B02-glm.md` — GLM: T14.3 (read-only artifact audit) →
  C2-lattice-scope (research scoping).

Both are read-only/standalone and can run in parallel. T14.3 was moved out of
Kimi's original B01 to avoid bottlenecking. Updated `CURRENT.md`, `HANDOVER.md`,
`delegation-prompts`, and `agent-boss.md`.

## Boss correction — agent lifecycle (2026-07-26)

User clarified that models/sessions are disposable and unlimited in number;
the Boss should treat a prompt as spawning a new session, not scheduling a
fixed worker. The Boss must write the task file **before** giving a prompt,
because the user dispatches immediately.

Applied: created `untracked/B03-glm.md` and `untracked/B04-minimax.md` before
suggesting prompts. Updated `docs/agent-boss.md` with the correction.

## Kimi-k2.7 — T13 C2-pilot-3×2 (2026-07-26)

**Task:** falsification test of C2 (single-value region is history-independent)
on 3×2.

**Result:** **FAIL — C2 falsified at 3×2.** 12 verified mismatches between
stored L==H values and history-aware exact values under reachable PSK lines.
All mismatches on positions whose fresh-start value is ±6.

**Strengths shown:**
- Built a clean standalone probe (`untracked/c2pilot_3x2.zig`) with no engine
  edits.
- Used `memo=false, brackets=false` to get a genuine history-aware exact
  value, then sanity-checked with fresh-start values to confirm the solver
  setup.
- Recorded exact histories and expected/got values for every contradiction,
  making the result reproducible.
- Gave honest consequences: C2 is false as scoped; the core-only deliverable
  collapses unless the semantics are redefined.
- Wall time negligible (~200 ms for 153k lines, 508 histories).

**Weaknesses / caveats:**
- None significant; the result is decisive.

**Quality:** excellent — this is exactly the kind of ruthless falsification
that prevents the project from building on an unproven claim. Kimi's value as
an auditor/falsifier is now strongly established.

## Boss pivot — C2 falsified (2026-07-26)

T13 result changed the project's strategic state. The Boss immediately:
1. Stopped treating T14.2/T15-impl/T17-impl as dispatchable.
2. Created three new parallel bundles (B05 reframe, B06 C3 audit, B07 code
   audit) to gather the information needed for an honest next step.
3. Updated `CURRENT.md`, `HANDOVER.md`, delegation prompts, and this file with
   the critical state change.
4. Left B02/B03/B04 running; they remain useful (artifact audit, doc-audit,
   scratch triage).

The Boss did **not** silently edit `PROGRESS.md` or `leak-crisis.md`; the
reframe will be applied after B05/B06 report, so the edits are evidence-based.

## GLM-5.2 — B03 doc-audit (2026-07-26)

**Task:** read-only audit of six core epistemic docs for contradictions,
stale claims, and name drift.

**Result:** DONE — **ACCEPT with edits.** Grade distribution: Blocker 2,
Critical 4, Should 5, Nice 3. The two post-T13 files (PROGRESS.md,
leak-crisis.md) were internally honest; the rot was in the four 02:17 files
(EPISTEMIC, CONCEPTS, names, GLOSSARY).

**Strengths shown:**
- Recognized the root cause: four files predated T13 and had not been updated.
- Produced a prioritized edit plan with exact file/section references and
  minimal fixes.
- Correctly identified name drift and the wrong experiment mapping in
  `names.md` (C2 mapped to E2, but E2 tests C3).
- Noted what was *not* a finding (no broken links, no numerical contradictions,
  PROGRESS/leak-crisis honest).

**Weaknesses / caveats:**
- None significant.

**Quality:** strong — the audit is essentially a ready-to-execute editorial
plan. The Boss applied Blocker + Critical edits immediately.

## Boss editorial action — B03 edits applied (2026-07-26)

Applied edits #1–#5 from B03:
- `docs/GLOSSARY.md`: certified core, L/H, rule-independent, bracket wording.
- `docs/boards/4x4/EPISTEMIC.md`: T13 update preamble, Wave-0 pilots,
  Wave-2 rename.
- `docs/boards/CONCEPTS.md`: C2 falsification note, dependency structure.
- `docs/names.md`: table rows 2a/2b/3 and NOTES.
- `docs/PROGRESS.md`: header + link fix.

Remaining edits #6–#10 (name-drift sweep, hyphenation, anchor ruleset, polish)
queued. No doc edits performed by subagents; Boss integration only.

## New bundles created (2026-07-26)

In response to user request for more delegation:
- B08 — GLM: fresh-agent onboarding test.
- B09 — Kimi: synthetic-bug injection / auditor sensitivity.
- B10 — Minimax: random empirical probe on 3×2 divergence patterns.

## GLM-5.2 — B05 reframe sprint (2026-07-26)

**Task:** after T13 falsified C2, scope the honest next deliverable and produce
an 8-edit doc plan.

**Result:** DONE. Strong output:
- Clear consequence note: C1 survives; C2 false at 3×2; C3 already false at 3×3;
  C4 false for both regions.
- New honest deliverable in one sentence: fresh-start exact value oracle +
  CLAIMED [L,H] bracket, explicit non-promise re real-game PSK.
- 6 reframe recommendations with 3 user-decision flags (UD-1/2/3).
- 8-edit plan with exact file/section/ replacement language, priority order,
  and coordination note with B03.
- No engine or artifact writes.

**Strengths shown:**
- Excellent strategic reasoning: immediately identified that C3 was already
  dead, so C2 false removes the last surviving real-game claim, not the
  second-to-last.
- Produced actionable user-decision flags with clear recommendations and
  rationales.
- Gave a precise edit plan rather than vague suggestions; the Boss could apply
  it directly.
- Honest about scope: did not attempt to prove C2 could be restored.

**Weaknesses / caveats:**
- None significant.

**Quality:** very strong — this is essentially a decision brief and an
editorial work order in one. GLM is proving excellent at integration/reframe
tasks.

## Boss integration — B11 doc edits applied (2026-07-26)

Applied the B05 8-edit plan to:
- `AGENTS.md` (repo root)
- `docs/status/leak-crisis.md`
- `docs/PROGRESS.md`
- `docs/boards/4x4/EPISTEMIC.md`
- `docs/boards/CONCEPTS.md`
- `docs/names.md`
- `docs/GLOSSARY.md`
- `docs/status/HANDOVER.md`
- `docs/status/CURRENT.md`

All edits were surgical status-string/name replacements; no numerical claims
or structural arguments changed. Verified with targeted greps. Remaining
edits (name-drift sweep, hyphenation, anchor ruleset, polish) are queued as
lower-priority cleanup.

## Kimi-k2.7 — B06 E2-C3 audit (2026-07-26)

**Task:** re-run E2 range-aware player on 2×2/3×2/3×3 to test C3 after C2 false.

**Result:** DONE. C3 supported on explored 2×2/3×2 samples (0 leaks each); C3
**falsified at 3×3** (50/8000 leaks, max 12 pts). General C3 claim false-as-
scoped.

**Strengths shown:**
- Added minimal `RETRO_E2_SEEDS` env-var knob cleanly, no core logic change.
- Correctly identified C2 and C3 as orthogonal: C2 false at 3×2 does not
  imply C3 false at 3×2, and indeed C3 held on the sampled 3×2 lines.
- Gave the honest status of [L,H]: history-free fixpoint bracket, claimed not
  proven as a real-game bound.

**Weaknesses / caveats:**
- None significant.

**Quality:** strong — decisive, orthogonal, and properly scoped.

## GLM-5.2 — B08 fresh-agent onboarding test (2026-07-26)

**Task:** simulate a fresh agent reading only HANDOVER/PROGRESS/names/CURRENT;
report understandability.

**Result:** DONE. Verdict **PARTIAL PASS**.

**Strengths shown:**
- Identified a real doc bug: `CURRENT.md` had B06/B07 listed as both
  "dispatchable" and "completed/starting" in different sections.
- Caught read-order disagreement between HANDOVER and the B08 probe list.
- Noted propagation-status disagreement between `names.md` and `PROGRESS.md`.
- Gave actionable fixes.

**Weaknesses / caveats:**
- Some findings are minor (hyphenation, B08 listing itself as dispatchable),
  but still useful friction signals.

**Quality:** good — this is exactly the kind of meta-audit that prevents a
fresh agent from getting lost. The Boss fixed the CURRENT.md inconsistency
immediately.

## Boss workflow refinement — SUBAGENTS.md (2026-07-26)

User requested a single concise registry of delegated bundles: prompts,
status, parallel/serial sets. Created `untracked/SUBAGENTS.md` as the canonical
registry. Updated `docs/status/CURRENT.md` to reference it. The human keeps
`HUMAN.md` separately; SUBAGENTS.md is the Boss-managed counterpart.

## Boss correction — per-board epistemic independence (2026-07-26)

User emphasized that each board size is its own epistemic universe: 2×2/3×2
results are not evidence for 3×3/4×4. Added explicit sections to:
- `AGENTS.md` (root)
- `docs/PROGRESS.md`
- `docs/boards/CONCEPTS.md`

This is now a documented foreclosure / convention.

## User conceptual QA — fresh-start vs real game (2026-07-26)

User probed the implications of T13:
- If L==H is history-dependent, is it ko-sensitive? (Loose sense: yes.)
- Terminology: score vs range of scores.
- Basic-ko handling vs PSK.
- Multiple tables per ruleset? (No.)
- Value of fresh-start table if real games have history.
- Narrowing ranges with history/future search.
- Tractability of 3×3/4×4.

Boss response: wrote `docs/research/fresh-start-vs-real-game.md` and created
B13 (terminology + real-game scope) and B14 (engine-vs-engine + KataGo) as
optional bundles. Updated `DELEGATION.md` to mark B12 waiting for human and
to add B13/B14 as optional. User prefers to wait for B04/B07/B10 to finish,
then commit, then run B12 in DeepSeek-Pro/Pi.

## DeepSeek-Pro (Pi harness) — B12, B13, B14 (2026-07-26)

**Context:** New Boss running in Pi harness with 1.0M context window.
Dispatched three bundles in separate sessions by the human:
- **B12** — post-B02 integration verdict + cleanup (read B02 results;
  verdict already written by GLM-5.2; removed 2 temp files).
- **B13** — terminology sweep + doc fixes (Option A: 5 files, replaced
  "certified core" → "fresh-start single-value region", applied 5 corrections
  to `fresh-start-vs-real-game.md`).
- **B14** — engine-vs-engine + KataGo probe design (3 experiments scoped,
  prioritized, with implementation plans).

### Strengths shown
- **High-context ingestion:** ingested HANDOVER.md, CURRENT.md, B02, B12,
  B13, B14, PROGRESS.md, leak-crisis.md, and all referenced docs in a single
  read phase with no confusion. The 1.0M window makes this natural.
- **Efficient batch executor:** applied multi-edit operations across files
  cleanly. B13's terminology sweep hit 5 files with precise replacements;
  no unintended changes. B14 produced a structured design doc with concrete
  wall-time estimates and safety constraints.
- **Follows conventions:** read AGENTS.md read-order, respected per-board
  epistemic independence, cited sources, produced properly structured output
  files. No convention violations.
- **Honest epistemic framing:** the B14 design explicitly notes that
  KataGo experiment is a curiosity/smoke test, not a verification gate,
  and that experiments are deferred until user decisions. No claim inflation.

### Weaknesses / caveats
- **DELEGATION.md format:** first pass put comments after prompts instead of
  on the line above, and created a redundant section. Corrected after human
  feedback. The format rule is: comments above, clean one-liner below.
- **No proactive pruning:** did not question whether the B13 subtask 3
  (real-game-play approach decision) needed the human's input before being
  left open. The recommendation was documented but the open loop wasn't
  flagged prominently.

### Cross-model takeaway (updated)

DeepSeek-Pro in Pi is a strong **Boss/integrator**: ingests large context,
executes multi-file edits precisely, produces structured designs, and
maintains epistemic discipline. Weaker at initiative (proactive pruning,
questioning stale structure). Best used for: doc integration, terminology
sweeps, design scoping, high-context decision briefs. The existing pattern
(Minimax implements, Kimi audits, GLM integrates) remains for engine work;
DeepSeek is the natural Boss/resumer for the Pi harness.

## Multi-model audit: B33 terminology sweep (2026-07-27)

Five models audited the same task (audit only, do NOT edit).

| Model | Found new | Followed rules | Notes |
|---|---|---|---|
| GLM | 4 (baseline) | Yes | Solid first pass, clear table |
| Kimi | 0 new | No (edited) | Correct fixes but ignored constraints |
| DS Pro | 0 | Yes | Accurate, nothing new |
| DS Flash | 5 (retro.zig comments) | Mixed | Best value: found and fixed stragglers |
| MiniMax | 13 (src comments, ADRs) | Yes | Most thorough, best audit discipline |

Takeaway: MiniMax for thoroughness, DS Flash for speed+fixes, GLM for baseline. Give Kimi explicit edit permission.

## Multi-model comparison — B35 (proof design) to B38 (epistemic discipline)

| Skill | Winner | Runner-up | Notes |
|---|---|---|---|
| B35 — Proof design (I1) | DS Flash | GLM | DS Flash attempted 5-lemma proof; GLM identified the critical gap (Lemma B) |
| B36 — Judgment/triage | GLM, DS Flash | — | All 5 converged on #1 = complete 4x4 finisher |
| B37 — Delegation design | DS Flash, MiniMax | GLM | DS Pro + Kimi wrote to console not file (need explicit write instruction in bundle) |
| B38 — Epistemic discipline | DS Pro | GLM, Kimi | DS Pro alone strictly applied per-board independence (#5 = UNKNOWN). MiniMax erred on #7 |

### Composite Boss evaluation (B34-B38)

| Model | B34 | B35 | B36 | B37 | B38 | Composite |
|---|---|---|---|---|---|---|
| GLM | 2nd | 2nd | 1st | 3rd | 2nd | **Most consistent** |
| MiniMax | 1st | 3rd | 4th | 2nd | 4th | Best auditor, weaker on reasoning |
| DS Flash | 4th | 1st | 1st | 1st | 5th | Best speed, weakest on rigor |
| DS Pro | 3rd | 4th | 3rd | 4th | 1st | Best epistemic discipline |
| Kimi | 5th | 5th | 2nd | 5th | 3rd | Inconsistent — strong B36, weak B35/B37 |

**Recommendation:** GLM for Boss (consistent across all skills). MiniMax for audits
(thoroughness). DS Pro for epistemic verification. DS Flash for speed tasks.
Kimi for follow-through on existing findings.
