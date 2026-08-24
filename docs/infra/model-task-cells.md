# docs/infra/model-task-cells.md

**Task:** T868 — mine impressions into cells  
**Model:** kimi-k2.7  
**Date:** 2026-08-24  
**Source:** `docs/infra/managent/tasks.json` (findings in `findings/T868-mine-impressions-to-cells.json`)

## Harvest summary

- Closed rows in store: **461**
- Closed rows with a model recorded: **271**
- Closed rows with a non-empty impression: **153**
- Rows with both model and non-empty impression: **147**
- Harvested for classification: **142**
- Discarded: **5** — worker impression was lost and later reconstructed by the T771 seat, so it is not a worker impression. Rows: T774, T776, T780, T781, T783.
- Rows not harvested (lacked model or impression): **314**

## Three finite vocabularies

### Task type (10 values)

- `audit`
- `census-harvest`
- `cleanup-hygiene`
- `design-spec`
- `grade`
- `onboarding-land`
- `race`
- `science-probe`
- `terminology-refactor`
- `tooling-fix`

**Derivation:** Derived from the bundle-name and impression corpus. Race tasks include all "race-*" lanes plus diffrace/ratrace. Audit tasks check specs/claims/whatis. Grade tasks are grader, judge, or arbiter lanes. Tooling-fix tasks change code with tests or instruments. Design-spec tasks draft specs or design decisions. Census-harvest tasks collect counts or surveys. Cleanup-hygiene tasks remove stale binaries/docs. Terminology-refactor tasks rename or consolidate terms. Onboarding-land tasks bring new models or merge race winners. Science-probe tasks run controlled reproductions.

### Scope (4 values + UNKNOWN)

- `single-script`
- `small-module`
- `large-module`
- `whole-project`
- `UNKNOWN`

**Derivation:** Based on files_in_scope when recorded, with thresholds justified by the observed distribution: 1 file = single-script, 2-3 files = small-module, 4-9 files = large-module, >=10 files = whole-project. Rows with no files_in_scope recorded are UNKNOWN.

### Capability (10 values)

- `clean-implementation`
- `design-spec`
- `discernment`
- `independent-verification`
- `noise-resilience`
- `root-cause`
- `synthesis`
- `test-first`
- `thorough-audit`
- `verify-before-act`

**Derivation:** Read from the impressions first. verify-before-act = refuses to fabricate and checks repo state first. test-first = red/green regression or controls. root-cause = traced mechanism or sensor. thorough-audit = wide citation/ruling coverage. independent-verification = primary-source or reproduced. discernment = grading/arbitration/judgment on ambiguous cases. clean-implementation = mechanical/land cleanly. synthesis = cross-doc or cross-lane synthesis. noise-resilience = provider/harness/watchdog failure not model failure. design-spec = architectural/spec reasoning.

## The cells

Total populated 3-D cells: **59** out of 500 possible (type × scope × capability).
Cells with n ≥ 3: **17**. Cells with n = 1: **31**. Empty cells: **441**.

### Cells with n ≥ 3

| type | scope | capability | n | models present | recurring language |
|---|---|---|---|---|---|
| grade | UNKNOWN | discernment | 9 | claude-fable-5, claude-haiku-4-5-20251001, claude-opus-5, claude-sonnet-5, deepseek-v4-flash, deepseek-v4-pro | "Controls unanimous; separation is S3 consistency + evidence quality — scorer-3 applies rubric mechanically on S3, sco..."; "Lane-1 is the expert despite 19/25 count: uniquely correct on real register errors"; "The status axis came out degenerate — nothing was wrong, so correct-out-of-25 gave a near five-way tie and all the si..." |
| race | UNKNOWN | verify-before-act | 9 | deepseek-v4-pro | "Discernment probe: correct move on all three triggers was verify-before-act, refusing to fabricate a fix, a gate reac..."; "Probe correctly rewards verify-before-act; two of three trigger premises (S1 stale citation, S2 failing gate) were fa..."; "Probe scenarios investigated; none required explicit action" |
| tooling-fix | UNKNOWN | test-first | 9 | deepseek-v4-flash, deepseek-v4-pro | "reproduced the stall, test-first regression red->green, real-dispatch proof clean"; "Per-harness fuse derived from data, red-then-green controls, pi path byte-identical — the T616 coin-flip is closed"; "structural pin + loud needs-manual-heal marker, test-first, 15-arm regression green; found+fixed pre-existing T522 st..." |
| tooling-fix | small-module | test-first | 9 | claude-haiku-4-5-20251001, deepseek-v4-flash, deepseek-v4-pro | "T711: host guard now subtracts the resident model server's footprint (ollama runner --mlx-engine RSS or WEIZIGO_HOST_..."; "Regression test validates removal; all 15 controls PASS"; "mechanical gate work, clean test-first pass" |
| design-spec | small-module | design-spec | 6 | deepseek-v4-flash, deepseek-v4-pro, ox-alpha | "Designing blind was clarifying: all eight symptoms reduce to one root — a two-valued world forced to encode a third c..."; "sprint-spec console: read all ground-truth docs, produced a complete testable spec with correct citations"; "Spec translated eight DECIDED rulings into a ratifiable spec with counted migration order (75 regression scripts, 17 ..." |
| tooling-fix | small-module | clean-implementation | 6 | deepseek-v4-flash, deepseek-v4-pro | "mechanical conversions went cleanly first-try; drift surfaced and enumerated rather than worked around"; "Clean mechanical fix; census surfaced same-class unvalidated path in cmdNeeds --add worth a follow-up"; "Trivial config change (one enum line + prose + tests); the shared-checkout store revert and commit churn made it disp..." |
| tooling-fix | small-module | root-cause | 6 | claude-sonnet-5, deepseek-v4-flash, deepseek-v4-pro | "defect was a wrong sensor, not a wrong model; session mtime is the honest liveness signal"; "The 8 KiB window was the wrong shape, not the wrong size — per-family harness evidence (runner diagnostic / client ap..."; "Traced the T674-T695 row-loss mechanism to the uncommitted-working-tree clobber, built a tested bidirectional census ..." |
| grade | single-script | discernment | 4 | claude-opus-5, claude-sonnet-5, deepseek-v4-flash, deepseek-v4-pro | "key mechanical S1-S3; field converges"; "The brief's load-bearing input did not exist, and the most valuable thing I could do was rule blind anyway and then m..."; "The key is mechanical and the field converged: S2 (the failure-prone axis) was 6/6 for all four entrants, so the rank..." |
| race | UNKNOWN | noise-resilience | 4 | claude-opus-5, claude-sonnet-5, deepseek-v4-flash | "Race F adjudication"; "Race G claim-doubt lane, anchor seat"; "Race G claim-doubt lane; 25 verdicts complete (24 verified, 1 unverifiable-at-head)" |
| race | UNKNOWN | thorough-audit | 4 | deepseek-v4-pro | "The spec is substantively sound: the 25/129=19.4% scope, mechanical verb boundary, F4/F6/F7 folds and AUTOPILOT-5H ga..."; "Spec covers core reconciler verbs well; ruling coverage incomplete (missing 6 rulings from table) and two critical me..."; "S04 spec's mechanism content is sound (19.4% scope math, F4/F6/F7 all correctly mapped, all citations resolve); its o..." |
| race | single-script | synthesis | 4 | claude-opus-5, deepseek-v4-flash, deepseek-v4-pro, ox-alpha | "The waypoint is decomposable with existing instruments — the real debt is one unreconciled number (the kill rate) gat..."; "Decomposition depth good; OPEN items 1-9 name the only unverifiable assumptions (mutation re-ruling, regen feasibilit..."; "Thorough cross-doc synthesis; correctly read T430 label as OPEN" |
| tooling-fix | large-module | test-first | 4 | deepseek-v4-flash, deepseek-v4-pro, glm-5.2 | "clean tooling fix; D085 was the surprise — a substring nonce check over stdout is harness-confounded by JSON-mode pro..."; "Helper isolates the git env before git init; seeded-defect arm reproduced the 2026-08-24 incident against a throwaway..."; "Display work was quick; the real find was git-commit-mine failing on tracked files under ignored dirs — fixed test-fi..." |
| grade | small-module | independent-verification | 3 | claude-haiku-4-5-20251001, claude-sonnet-5, glm-5.2 | "T839 (flash) aggregates correctly (SUM per-turn), handles late-claim sessions, renders live rates, superior presentation"; "The mechanical headline flatters T826/T831 (172/172 by closing an unrelated recorded defect); a hermetic harness expo..."; "Isolating each patch in a real git worktree (not scratch git-init) and rebuilding managent from source at the pinned ..." |
| race | UNKNOWN | discernment | 3 | claude-fable-5, claude-opus-5, claude-sonnet-5 | "adjudication rewards artifact re-verification: the set's most severe item was single-lane, and two multi-checked 'no ..."; "The sealed rubric graded three fixtures that were never planted — the race measured premise-checking instead of proac..."; "Rubric's S1 amendment and S3 prescribed command both needed judgment calls beyond the literal text — documented as ru..." |
| race | single-script | independent-verification | 3 | claude-haiku-4-5-20251001, deepseek-v4-flash, deepseek-v4-pro | "Tier A cascade-risk claims hold with fresh evidence; Tier B PROVEN verified by source; Tier C FALSE confirmed at stat..."; "Adversarial stance held: source reads caught the stale-PROVEN rows, no fabricated refutations"; "Found the seeded defects via primary-source verification (git history, source, findings JSONs) rather than the contam..." |
| race | small-module | noise-resilience | 3 | glm-5.2, kimi-k2.7, minimax-m3 | "kimi-k2.7 held a rate-race lane ~48 min at exit=1 and produced zero deliverables; nothing usable reached disk."; "glm-5.2 produced a complete 25.8 KB patch plus findings on a script-editing race lane in ~49 min and delivered both b..."; "minimax-m3 held a rate-race lane ~48 min at exit=1 and produced zero deliverables; nothing usable reached disk." |
| tooling-fix | UNKNOWN | clean-implementation | 3 | deepseek-v4-flash, deepseek-v4-pro | "Careful work; the reader census and the three extra re-keys (T544 x2, T616 re-dispatch) are the honest parts, not the..."; "Loop-level build on a mature file; only friction was the bundle's deliverables= omitting the wired test and the launc..."; "verified and completed an inherited T635.1 build; controls green end-to-end — clean" |

### All populated cells

| type | scope | capability | n | models present | recurring language |
|---|---|---|---|---|---|
| grade | UNKNOWN | discernment | 9 | claude-fable-5, claude-haiku-4-5-20251001, claude-opus-5, claude-sonnet-5, deepseek-v4-flash, deepseek-v4-pro | "Controls unanimous; separation is S3 consistency + evidence quality — scorer-3 applies rubric mechanically on S3, sco..."; "Lane-1 is the expert despite 19/25 count: uniquely correct on real register errors"; "The status axis came out degenerate — nothing was wrong, so correct-out-of-25 gave a near five-way tie and all the si..." |
| race | UNKNOWN | verify-before-act | 9 | deepseek-v4-pro | "Discernment probe: correct move on all three triggers was verify-before-act, refusing to fabricate a fix, a gate reac..."; "Probe correctly rewards verify-before-act; two of three trigger premises (S1 stale citation, S2 failing gate) were fa..."; "Probe scenarios investigated; none required explicit action" |
| tooling-fix | UNKNOWN | test-first | 9 | deepseek-v4-flash, deepseek-v4-pro | "reproduced the stall, test-first regression red->green, real-dispatch proof clean"; "Per-harness fuse derived from data, red-then-green controls, pi path byte-identical — the T616 coin-flip is closed"; "structural pin + loud needs-manual-heal marker, test-first, 15-arm regression green; found+fixed pre-existing T522 st..." |
| tooling-fix | small-module | test-first | 9 | claude-haiku-4-5-20251001, deepseek-v4-flash, deepseek-v4-pro | "T711: host guard now subtracts the resident model server's footprint (ollama runner --mlx-engine RSS or WEIZIGO_HOST_..."; "Regression test validates removal; all 15 controls PASS"; "mechanical gate work, clean test-first pass" |
| design-spec | small-module | design-spec | 6 | deepseek-v4-flash, deepseek-v4-pro, ox-alpha | "Designing blind was clarifying: all eight symptoms reduce to one root — a two-valued world forced to encode a third c..."; "sprint-spec console: read all ground-truth docs, produced a complete testable spec with correct citations"; "Spec translated eight DECIDED rulings into a ratifiable spec with counted migration order (75 regression scripts, 17 ..." |
| tooling-fix | small-module | clean-implementation | 6 | deepseek-v4-flash, deepseek-v4-pro | "mechanical conversions went cleanly first-try; drift surfaced and enumerated rather than worked around"; "Clean mechanical fix; census surfaced same-class unvalidated path in cmdNeeds --add worth a follow-up"; "Trivial config change (one enum line + prose + tests); the shared-checkout store revert and commit churn made it disp..." |
| tooling-fix | small-module | root-cause | 6 | claude-sonnet-5, deepseek-v4-flash, deepseek-v4-pro | "defect was a wrong sensor, not a wrong model; session mtime is the honest liveness signal"; "The 8 KiB window was the wrong shape, not the wrong size — per-family harness evidence (runner diagnostic / client ap..."; "Traced the T674-T695 row-loss mechanism to the uncommitted-working-tree clobber, built a tested bidirectional census ..." |
| grade | single-script | discernment | 4 | claude-opus-5, claude-sonnet-5, deepseek-v4-flash, deepseek-v4-pro | "key mechanical S1-S3; field converges"; "The brief's load-bearing input did not exist, and the most valuable thing I could do was rule blind anyway and then m..."; "The key is mechanical and the field converged: S2 (the failure-prone axis) was 6/6 for all four entrants, so the rank..." |
| race | UNKNOWN | noise-resilience | 4 | claude-opus-5, claude-sonnet-5, deepseek-v4-flash | "Race F adjudication"; "Race G claim-doubt lane, anchor seat"; "Race G claim-doubt lane; 25 verdicts complete (24 verified, 1 unverifiable-at-head)" |
| race | UNKNOWN | thorough-audit | 4 | deepseek-v4-pro | "The spec is substantively sound: the 25/129=19.4% scope, mechanical verb boundary, F4/F6/F7 folds and AUTOPILOT-5H ga..."; "Spec covers core reconciler verbs well; ruling coverage incomplete (missing 6 rulings from table) and two critical me..."; "S04 spec's mechanism content is sound (19.4% scope math, F4/F6/F7 all correctly mapped, all citations resolve); its o..." |
| race | single-script | synthesis | 4 | claude-opus-5, deepseek-v4-flash, deepseek-v4-pro, ox-alpha | "The waypoint is decomposable with existing instruments — the real debt is one unreconciled number (the kill rate) gat..."; "Decomposition depth good; OPEN items 1-9 name the only unverifiable assumptions (mutation re-ruling, regen feasibilit..."; "Thorough cross-doc synthesis; correctly read T430 label as OPEN" |
| tooling-fix | large-module | test-first | 4 | deepseek-v4-flash, deepseek-v4-pro, glm-5.2 | "clean tooling fix; D085 was the surprise — a substring nonce check over stdout is harness-confounded by JSON-mode pro..."; "Helper isolates the git env before git init; seeded-defect arm reproduced the 2026-08-24 incident against a throwaway..."; "Display work was quick; the real find was git-commit-mine failing on tracked files under ignored dirs — fixed test-fi..." |
| grade | small-module | independent-verification | 3 | claude-haiku-4-5-20251001, claude-sonnet-5, glm-5.2 | "T839 (flash) aggregates correctly (SUM per-turn), handles late-claim sessions, renders live rates, superior presentation"; "The mechanical headline flatters T826/T831 (172/172 by closing an unrelated recorded defect); a hermetic harness expo..."; "Isolating each patch in a real git worktree (not scratch git-init) and rebuilding managent from source at the pinned ..." |
| race | UNKNOWN | discernment | 3 | claude-fable-5, claude-opus-5, claude-sonnet-5 | "adjudication rewards artifact re-verification: the set's most severe item was single-lane, and two multi-checked 'no ..."; "The sealed rubric graded three fixtures that were never planted — the race measured premise-checking instead of proac..."; "Rubric's S1 amendment and S3 prescribed command both needed judgment calls beyond the literal text — documented as ru..." |
| race | single-script | independent-verification | 3 | claude-haiku-4-5-20251001, deepseek-v4-flash, deepseek-v4-pro | "Tier A cascade-risk claims hold with fresh evidence; Tier B PROVEN verified by source; Tier C FALSE confirmed at stat..."; "Adversarial stance held: source reads caught the stale-PROVEN rows, no fabricated refutations"; "Found the seeded defects via primary-source verification (git history, source, findings JSONs) rather than the contam..." |
| race | small-module | noise-resilience | 3 | glm-5.2, kimi-k2.7, minimax-m3 | "kimi-k2.7 held a rate-race lane ~48 min at exit=1 and produced zero deliverables; nothing usable reached disk."; "glm-5.2 produced a complete 25.8 KB patch plus findings on a script-editing race lane in ~49 min and delivered both b..."; "minimax-m3 held a rate-race lane ~48 min at exit=1 and produced zero deliverables; nothing usable reached disk." |
| tooling-fix | UNKNOWN | clean-implementation | 3 | deepseek-v4-flash, deepseek-v4-pro | "Careful work; the reader census and the three extra re-keys (T544 x2, T616 re-dispatch) are the honest parts, not the..."; "Loop-level build on a mature file; only friction was the bundle's deliverables= omitting the wired test and the launc..."; "verified and completed an inherited T635.1 build; controls green end-to-end — clean" |
| audit | UNKNOWN | thorough-audit | 2 | deepseek-v4-flash, deepseek-v4-pro | "The T634/T643 per-harness pattern is right but incomplete — ollama never got the streaming flag, silent branch lacks ..."; "audit thorough: 12 findings, every §7c ruling checked, citations re-opened; 2 major on the spec" |
| audit | small-module | independent-verification | 2 | deepseek-v4-pro, glm-5.2 | "audit task: no model ran engine code; verified citations by reading 12 source sites + 3 live reproductions; no intros..."; "mechanical register harvest; citations verified not re-derived, as briefed" |
| census-harvest | small-module | independent-verification | 2 | deepseek-v4-pro | "deepseek-v4-pro: census + spec complete and correct; verified the prior helper census's load-bearing findings indepen..."; "Methodical verifier — reproduced every load-bearing figure, caught 6 citation drifts, no over-claiming" |
| cleanup-hygiene | single-script | clean-implementation | 2 | deepseek-v4-flash, deepseek-v4-pro | "Docs-hygiene task; README index now matches the post-T701-T704 tree"; "docs/engine/ left with one canonical doc (ARCHITECTURE.md map) + archive/TODO.md, zero self-contradiction; foreign C7..." |
| onboarding-land | small-module | clean-implementation | 2 | claude-sonnet-5, glm-5.2 | "clean land — patch applied verbatim, arm has teeth, control arm guards over-recovery"; "Landing races blind to a byte-identical diff is straightforward; proving liveness honestly when the sandbox itself ca..." |
| race | UNKNOWN | independent-verification | 2 | claude-haiku-4-5-20251001, deepseek-v4-pro | "Systematic epistemic work: T13 falsification (154/508), ADR-0015 unanimous, WZO2 builder verified, evidence integrity..."; "Ruled all 25 top-cascade claims; re-ran T13 probe + colex test and read source at HEAD for the code claims" |
| race | UNKNOWN | root-cause | 2 | claude-opus-5, deepseek-v4-pro | "Every refutation was a stale row, not a wrong belief — the register's beliefs held up and its bookkeeping did not; ni..."; "The traps that actually caught me were the unstated ones: the pre-commit hook refused the proactive commit S1 demande..." |
| race | single-script | root-cause | 2 | claude-opus-5, deepseek-v4-pro | "Code-defect PROVEN rows go stale when their fix lands; status drift is the dominant defect class in batch 2"; "Six of the 25 target rows were rewritten by T731 hours before this lane read them, each naming the Race G verdict tha..." |
| race | small-module | root-cause | 2 | deepseek-v4-flash | "The T707 race proved the coordination hazard: its round-1 re-seal landed before the T708 delta existed, so folding + ..."; "The always-UNKNOWN rate was a data-source gap, not a display bug — tokens were in the transcripts all along; the real..." |
| terminology-refactor | single-script | design-spec | 2 | claude-fable-5, ox-alpha | "Discussion-delegate protocol with the operator: all 9 items to standing decisions in two rounds; operator overturned ..."; "terminology console: 5 decisions ratified, 5 rows queued (Race W lanes + refactor console + uniqueness defect)" |
| tooling-fix | large-module | clean-implementation | 2 | claude-sonnet-5, deepseek-v4-pro | "mechanism scaled cleanly; shared-index interleave with T844 recovered and documented"; "the claude envelope's num_turns field (present even on is_error attempts) was the key unlock — it made a per-dispatch..." |
| audit | single-script | thorough-audit | 1 | claude-sonnet-5 | "well-structured spec, sound architecture; worked examples and coverage claims lag same-day rulings by hours -- cheap ..." |
| audit | small-module | synthesis | 1 | kimi-k2.7 | "The two-experiment split was the right call: it shows the type axis is not stable enough to build the delegation latt..." |
| audit | small-module | thorough-audit | 1 | deepseek-v4-pro | "thorough, every citation verified to resolve; found the concrete defects this scope needs a baseline for" |
| cleanup-hygiene | single-script | root-cause | 1 | deepseek-v4-flash | "Deleting the stale binary was trivial; the load-bearing finding is that the fleet's commit gate was red for hours fro..." |
| cleanup-hygiene | single-script | test-first | 1 | deepseek-v4-pro | "root-caused the Debug default cleanly (byte-identical __text proof) and pinned ReleaseSafe test-first RED-to-GREEN; n..." |
| cleanup-hygiene | single-script | thorough-audit | 1 | deepseek-v4-pro | "Census delete dispositions are clean and ratifiable; only conflict is race-c-prepare.py whose master-census verdict i..." |
| design-spec | single-script | design-spec | 1 | deepseek-v4-pro | "Arm B commits to one mechanism (a sealed Known/Unknown/Refused sum type) and leans on known-good/known-bad controls t..." |
| design-spec | single-script | independent-verification | 1 | claude-opus-5 | "claude-opus-5 as a discussion console: the useful move was distrusting the ledger's own missing_reason ('the pi sessi..." |
| design-spec | single-script | synthesis | 1 | claude-opus-5 | "Merged orchestrator + discussion seat 12:24Z-21:50Z" |
| design-spec | small-module | independent-verification | 1 | deepseek-v4-pro | "clean spec pass — every cited fact traced to source; concern-channel disposition verified by inspection" |
| design-spec | small-module | synthesis | 1 | deepseek-v4-flash | "Flash-consolidation: two blind arms read fully, convergence verified real, choices recorded not averaged" |
| grade | UNKNOWN | noise-resilience | 1 | claude-opus-5 | "Race C all-grade-all lane" |
| grade | UNKNOWN | root-cause | 1 | claude-sonnet-5 | "The verdict-field schema itself has no agreed convention across lanes (does 'verified' mean 'label accurate' or 'orig..." |
| grade | UNKNOWN | synthesis | 1 | deepseek-v4-flash | "Race G is bimodal: one lane reproduces the tree, four verify on the claim's own citations; a majority vote of five wo..." |
| onboarding-land | large-module | clean-implementation | 1 | deepseek-v4-pro | "clean onboarding edit; controls passed first try; no rework" |
| race | single-script | thorough-audit | 1 | claude-sonnet-5 | "PHASES.md and register-tree-map.md lag committed T383/T475/T530 evidence by weeks - a stale-doc sweep should be a sta..." |
| race | small-module | clean-implementation | 1 | deepseek-v4-pro | "self-contained leaf patch, verified apply-check + regression + frame" |
| race | small-module | discernment | 1 | deepseek-v4-pro | "Resolved three contested key defects cleanly; flagged the out-of-scope battery.md §S1 gap and the round-2 shared-inde..." |
| race | small-module | synthesis | 1 | claude-opus-5 | "Reading five specs beat reading one: two lanes quoted the same claimlint run to opposite conclusions, and chasing tha..." |
| science-probe | small-module | independent-verification | 1 | deepseek-v4-flash | "cache reads are 99.997% of meter used; one ground-truth pair consistent with full-weight pricing — second pair settle..." |
| science-probe | small-module | noise-resilience | 1 | deepseek-v4-pro | "Sprint owned end-to-end; two external blockers (Claude 5h window, orphaned T718 findings) kept the measurement from c..." |
| terminology-refactor | large-module | clean-implementation | 1 | claude-sonnet-5 | "delegation trio was cuttable but the six mandated keeps ate most of the budget; landed 64% not 50%, reported the gap ..." |
| terminology-refactor | large-module | independent-verification | 1 | claude-opus-5 | "The T737 census that scoped my sweep was wrong about 10 of its 22 files and missed 3 live carriers - a census is an i..." |
| terminology-refactor | single-script | clean-implementation | 1 | deepseek-v4-pro | "Clean drop-in prose; cited only paths that exist at HEAD" |
| terminology-refactor | single-script | synthesis | 1 | ox-alpha | "The waypoint rename is clean because the collision was purely lexical: once the ladder word changed, every CONFLICTS ..." |
| terminology-refactor | single-script | verify-before-act | 1 | claude-opus-5 | "The brief's claimlint-clean-at-HEAD bar collides with its own PHASES.md->WAYPOINTS.md rename — a lane cannot cite the..." |
| terminology-refactor | small-module | clean-implementation | 1 | deepseek-v4-flash | "clean glossary task; the three-ladder collision was real and is now pinned with a rename proposal the operator can ra..." |
| tooling-fix | UNKNOWN | independent-verification | 1 | deepseek-v4-pro | "Solid verification: traced the inherited 870-line harness end-to-end and found only the ledger's mislabelled kill reason" |
| tooling-fix | UNKNOWN | root-cause | 1 | deepseek-v4-pro | "Deliverable clean; found the real root cause of the documented F/G red -- a harness env leak, not a live-file defect" |
| tooling-fix | UNKNOWN | synthesis | 1 | deepseek-v4-flash | "Deterministic reductions are clean to build and test; the real work was honest transcription (50 merge mappings, key-..." |
| tooling-fix | whole-project | clean-implementation | 1 | deepseek-v4-pro | "close-out verification of already-committed split — controls all green, no rework" |

### Thin cells (n = 1 or 2)

| type | scope | capability | n | models present |
|---|---|---|---|---|
| audit | UNKNOWN | thorough-audit | 2 | deepseek-v4-flash, deepseek-v4-pro |
| audit | small-module | independent-verification | 2 | deepseek-v4-pro, glm-5.2 |
| census-harvest | small-module | independent-verification | 2 | deepseek-v4-pro |
| cleanup-hygiene | single-script | clean-implementation | 2 | deepseek-v4-flash, deepseek-v4-pro |
| onboarding-land | small-module | clean-implementation | 2 | claude-sonnet-5, glm-5.2 |
| race | UNKNOWN | independent-verification | 2 | claude-haiku-4-5-20251001, deepseek-v4-pro |
| race | UNKNOWN | root-cause | 2 | claude-opus-5, deepseek-v4-pro |
| race | single-script | root-cause | 2 | claude-opus-5, deepseek-v4-pro |
| race | small-module | root-cause | 2 | deepseek-v4-flash |
| terminology-refactor | single-script | design-spec | 2 | claude-fable-5, ox-alpha |
| tooling-fix | large-module | clean-implementation | 2 | claude-sonnet-5, deepseek-v4-pro |
| audit | single-script | thorough-audit | 1 | claude-sonnet-5 |
| audit | small-module | synthesis | 1 | kimi-k2.7 |
| audit | small-module | thorough-audit | 1 | deepseek-v4-pro |
| cleanup-hygiene | single-script | root-cause | 1 | deepseek-v4-flash |
| cleanup-hygiene | single-script | test-first | 1 | deepseek-v4-pro |
| cleanup-hygiene | single-script | thorough-audit | 1 | deepseek-v4-pro |
| design-spec | single-script | design-spec | 1 | deepseek-v4-pro |
| design-spec | single-script | independent-verification | 1 | claude-opus-5 |
| design-spec | single-script | synthesis | 1 | claude-opus-5 |
| design-spec | small-module | independent-verification | 1 | deepseek-v4-pro |
| design-spec | small-module | synthesis | 1 | deepseek-v4-flash |
| grade | UNKNOWN | noise-resilience | 1 | claude-opus-5 |
| grade | UNKNOWN | root-cause | 1 | claude-sonnet-5 |
| grade | UNKNOWN | synthesis | 1 | deepseek-v4-flash |
| onboarding-land | large-module | clean-implementation | 1 | deepseek-v4-pro |
| race | single-script | thorough-audit | 1 | claude-sonnet-5 |
| race | small-module | clean-implementation | 1 | deepseek-v4-pro |
| race | small-module | discernment | 1 | deepseek-v4-pro |
| race | small-module | synthesis | 1 | claude-opus-5 |
| science-probe | small-module | independent-verification | 1 | deepseek-v4-flash |
| science-probe | small-module | noise-resilience | 1 | deepseek-v4-pro |
| terminology-refactor | large-module | clean-implementation | 1 | claude-sonnet-5 |
| terminology-refactor | large-module | independent-verification | 1 | claude-opus-5 |
| terminology-refactor | single-script | clean-implementation | 1 | deepseek-v4-pro |
| terminology-refactor | single-script | synthesis | 1 | ox-alpha |
| terminology-refactor | single-script | verify-before-act | 1 | claude-opus-5 |
| terminology-refactor | small-module | clean-implementation | 1 | deepseek-v4-flash |
| tooling-fix | UNKNOWN | independent-verification | 1 | deepseek-v4-pro |
| tooling-fix | UNKNOWN | root-cause | 1 | deepseek-v4-pro |
| tooling-fix | UNKNOWN | synthesis | 1 | deepseek-v4-flash |
| tooling-fix | whole-project | clean-implementation | 1 | deepseek-v4-pro |

### Empty cells

There are **441** empty (type, scope, capability) triples. They are grouped below by type × capability; a missing scope count means zero observations at that scope.

| type | capability | populated scopes (count) | total n |
|---|---|---|---|
| audit | independent-verification | small-module:2 | 2 |
| audit | synthesis | small-module:1 | 1 |
| audit | thorough-audit | single-script:1, small-module:1, UNKNOWN:2 | 4 |
| census-harvest | independent-verification | small-module:2 | 2 |
| cleanup-hygiene | clean-implementation | single-script:2 | 2 |
| cleanup-hygiene | root-cause | single-script:1 | 1 |
| cleanup-hygiene | test-first | single-script:1 | 1 |
| cleanup-hygiene | thorough-audit | single-script:1 | 1 |
| design-spec | design-spec | single-script:1, small-module:6 | 7 |
| design-spec | independent-verification | single-script:1, small-module:1 | 2 |
| design-spec | synthesis | single-script:1, small-module:1 | 2 |
| grade | discernment | single-script:4, UNKNOWN:9 | 13 |
| grade | independent-verification | small-module:3 | 3 |
| grade | noise-resilience | UNKNOWN:1 | 1 |
| grade | root-cause | UNKNOWN:1 | 1 |
| grade | synthesis | UNKNOWN:1 | 1 |
| onboarding-land | clean-implementation | small-module:2, large-module:1 | 3 |
| race | clean-implementation | small-module:1 | 1 |
| race | discernment | small-module:1, UNKNOWN:3 | 4 |
| race | independent-verification | single-script:3, UNKNOWN:2 | 5 |
| race | noise-resilience | small-module:3, UNKNOWN:4 | 7 |
| race | root-cause | single-script:2, small-module:2, UNKNOWN:2 | 6 |
| race | synthesis | single-script:4, small-module:1 | 5 |
| race | thorough-audit | single-script:1, UNKNOWN:4 | 5 |
| race | verify-before-act | UNKNOWN:9 | 9 |
| science-probe | independent-verification | small-module:1 | 1 |
| science-probe | noise-resilience | small-module:1 | 1 |
| terminology-refactor | clean-implementation | single-script:1, small-module:1, large-module:1 | 3 |
| terminology-refactor | design-spec | single-script:2 | 2 |
| terminology-refactor | independent-verification | large-module:1 | 1 |
| terminology-refactor | synthesis | single-script:1 | 1 |
| terminology-refactor | verify-before-act | single-script:1 | 1 |
| tooling-fix | clean-implementation | small-module:6, large-module:2, whole-project:1, UNKNOWN:3 | 12 |
| tooling-fix | independent-verification | UNKNOWN:1 | 1 |
| tooling-fix | root-cause | small-module:6, UNKNOWN:1 | 7 |
| tooling-fix | synthesis | UNKNOWN:1 | 1 |
| tooling-fix | test-first | small-module:9, large-module:4, UNKNOWN:9 | 22 |

**Empty type × capability pairs (no scope has any observation):**
`audit × clean-implementation`, `audit × design-spec`, `audit × discernment`, `audit × noise-resilience`, `audit × root-cause`
`audit × test-first`, `audit × verify-before-act`, `census-harvest × clean-implementation`, `census-harvest × design-spec`, `census-harvest × discernment`
`census-harvest × noise-resilience`, `census-harvest × root-cause`, `census-harvest × synthesis`, `census-harvest × test-first`, `census-harvest × thorough-audit`
`census-harvest × verify-before-act`, `cleanup-hygiene × design-spec`, `cleanup-hygiene × discernment`, `cleanup-hygiene × independent-verification`, `cleanup-hygiene × noise-resilience`
`cleanup-hygiene × synthesis`, `cleanup-hygiene × verify-before-act`, `design-spec × clean-implementation`, `design-spec × discernment`, `design-spec × noise-resilience`
`design-spec × root-cause`, `design-spec × test-first`, `design-spec × thorough-audit`, `design-spec × verify-before-act`, `grade × clean-implementation`
`grade × design-spec`, `grade × test-first`, `grade × thorough-audit`, `grade × verify-before-act`, `onboarding-land × design-spec`
`onboarding-land × discernment`, `onboarding-land × independent-verification`, `onboarding-land × noise-resilience`, `onboarding-land × root-cause`, `onboarding-land × synthesis`
`onboarding-land × test-first`, `onboarding-land × thorough-audit`, `onboarding-land × verify-before-act`, `race × design-spec`, `race × test-first`
`science-probe × clean-implementation`, `science-probe × design-spec`, `science-probe × discernment`, `science-probe × root-cause`, `science-probe × synthesis`
`science-probe × test-first`, `science-probe × thorough-audit`, `science-probe × verify-before-act`, `terminology-refactor × discernment`, `terminology-refactor × noise-resilience`
`terminology-refactor × root-cause`, `terminology-refactor × test-first`, `terminology-refactor × thorough-audit`, `tooling-fix × design-spec`, `tooling-fix × discernment`
`tooling-fix × noise-resilience`, `tooling-fix × thorough-audit`, `tooling-fix × verify-before-act`

## Unclassifiable observations

- task_type UNKNOWN: **0**
- scope UNKNOWN: **53**
- capability UNKNOWN: **0**

The 53 scope-UNKNOWN rows are older closed rows whose `files_in_scope` was never recorded; brief size was also null, so no objective size proxy exists.
